require "json"
require "tmpdir"
require "etc"
require "rbconfig"

# Linux benchmark harness: separate Ruby processes, each with one persistent Node worker.
class ParallelBenchmark
  def initialize(workers:, total:, repeats:, yjit:)
    raise "Linux /proc is required" unless File.directory?("/proc/self")
    raise "Invalid worker count" unless [1, 2, 4, 8].include?(workers)
    raise "Total scenarios must divide evenly across workers" unless total.positive? && (total % workers).zero?
    raise "Invalid repeat count" unless repeats.positive? && repeats.odd?
    raise "Invalid YJIT mode" unless %w[on off].include?(yjit)
    @workers, @total, @repeats, @yjit = workers, total, repeats, yjit
    @children = []
    @ticks = Etc.sysconf(Etc::SC_CLK_TCK)
    @page_kib = Etc.sysconf(Etc::SC_PAGESIZE) / 1024
  end

  def run
    Dir.mktmpdir("domstride-parallel") do |directory|
      @directory = directory
      begin
        startup = now
        flag = @yjit == "on" ? "--yjit" : "--disable-yjit"
        @workers.times do |i|
          log = File.join(directory, "worker-#{i}.log")
          pid = Process.spawn({ "RUBY_YJIT_ENABLE" => nil }, RbConfig.ruby, flag,
                              File.join(__dir__, "parallel_child.rb"), directory, i.to_s,
                              (@total / @workers).to_s, @repeats.to_s, @yjit,
                              out: log, err: [:child, :out], pgroup: true)
          @children << pid
        end
        ready = await_files(Array.new(@workers) { |i| "ready-#{i}" })
        raise "Database isolation failure" unless ready.map { |r| r.fetch("database") }.uniq.size == @workers
        @pids = ready.flat_map { |r| [r.fetch("ruby_pid"), r.fetch("node_pid")] }
        raise "Process isolation failure" unless @pids.uniq.size == @workers * 2
        startup_seconds = now - startup
        samples = Array.new(@repeats) { |i| measure(i) }
        File.write(File.join(directory, "finish"), "")
        @children.each do |pid|
          _, status = Process.wait2(pid)
          raise "Child #{pid} failed" unless status.success?
        end
        @children.clear
        result = {
          engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"), yjit: @yjit, workers: @workers,
          ruby: RUBY_VERSION, node: `node --version`.strip, logical_cpus: Etc.nprocessors,
          cpu_quota: File.file?("/sys/fs/cgroup/cpu.max") ? File.read("/sys/fs/cgroup/cpu.max").strip : nil,
          scenarios_per_sample: @total, repeats: @repeats, startup_and_warmup_seconds: startup_seconds,
          samples: samples, median_seconds: median(samples.map { |s| s[:seconds] }),
          median_scenarios_per_second: median(samples.map { |s| s[:scenarios_per_second] }),
          median_cpu_cores: median(samples.map { |s| s[:cpu_cores] }),
          peak_sampled_aggregate_rss_kib: samples.map { |s| s[:peak_sampled_aggregate_rss_kib] }.max
        }
        puts JSON.pretty_generate(result)
      rescue StandardError
        Dir[File.join(directory, "worker-*.log")].each { |f| warn "#{File.basename(f)}:\n#{File.read(f)}" }
        raise
      ensure
        @children.each do |pid|
          begin
            Process.kill("KILL", -pid)
          rescue Errno::ESRCH
          end
          begin
            Process.waitpid(pid)
          rescue Errno::ECHILD
          end
        end
      end
    end
  end

  private

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  def median(values) = values.sort[values.size / 2]

  def await_files(names, timeout: 120)
    deadline = now + timeout
    until names.all? { |name| File.file?(File.join(@directory, name)) }
      @children.each do |pid|
        exited = Process.waitpid2(pid, Process::WNOHANG)
        raise "Child #{pid} exited before barrier: #{exited.last}" if exited
      end
      raise "Barrier timeout: #{names.join(', ')}" if now >= deadline
      yield if block_given?
      sleep 0.01
    end
    names.map { |name| JSON.parse(File.read(File.join(@directory, name))) }
  end

  def resources
    cpu = 0.0
    rss = 0
    @pids.each do |pid|
      fields = File.read("/proc/#{pid}/stat").rpartition(") ").last.split
      cpu += (Integer(fields.fetch(11)) + Integer(fields.fetch(12))).to_f / @ticks
      rss += Integer(File.read("/proc/#{pid}/statm").split.fetch(1)) * @page_kib
    end
    { cpu: cpu, rss: rss }
  end

  def measure(index)
    initial = resources
    peak = initial[:rss]
    started = now
    File.write(File.join(@directory, "start-#{index}"), "")
    results = await_files(Array.new(@workers) { |i| "done-#{index}-#{i}" }) do
      peak = [peak, resources[:rss]].max
    end
    elapsed = now - started
    final = resources
    peak = [peak, final[:rss]].max
    completed = results.sum { |r| r.fetch("scenarios") }
    raise "Workload mismatch" unless completed == @total
    cpu_seconds = final[:cpu] - initial[:cpu]
    { seconds: elapsed, scenarios: completed, scenarios_per_second: completed / elapsed,
      cpu_seconds: cpu_seconds, cpu_cores: cpu_seconds / elapsed,
      peak_sampled_aggregate_rss_kib: peak, worker_seconds: results.map { |r| r.fetch("seconds") } }
  end
end

ParallelBenchmark.new(workers: Integer(ENV.fetch("WORKERS", "1")), total: Integer(ENV.fetch("SCENARIOS", "32")),
                      repeats: Integer(ENV.fetch("REPEATS", "5")), yjit: ENV.fetch("YJIT_MODE", "off")).run
