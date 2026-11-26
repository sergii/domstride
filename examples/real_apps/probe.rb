require "json"
require "fileutils"
require "open3"

app, revision, output = ARGV
abort "Usage: probe.rb APP SHA OUTPUT" unless app && revision && output
output = File.expand_path(output)
FileUtils.mkdir_p(output)
abort "Expected pinned upstream checkout" unless `git rev-parse HEAD`.strip == revision
abort "Only test environment is allowed" unless ENV["RAILS_ENV"] == "test"

paths = Dir["test/system/**/*_test.rb"].sort
abort "No original system tests found" if paths.empty?
# Prefer authentication tests, then a deterministic first file. No test filtering by expected compatibility.
selected = paths.find { |path| File.basename(path).match?(/session|sign_in|login|authentication/i) } || paths.first
sources = paths.map { |path| File.read(path) }
patterns = {
  execute_script: /\b(?:execute_script|evaluate_script)\b/,
  upload: /\battach_file\b/,
  hover: /\bhover\b/,
  keyboard: /\bsend_keys\b/,
  window: /\b(?:switch_to_window|within_window|window_opened_by)\b/,
  cable: /(?:turbo-cable-stream-source|wait_for_cable_connection)/,
  rich_text: /(?:fill_in_rich_text_area|fill_in_lexxy|fill_house_editor)/,
  geometry: /\b(?:drag_to|scroll_to|resize_to|obscured\?)\b/
}
result = { app: app, revision: revision, ruby: RUBY_VERSION, selected_test_file: selected,
  original_system_test_files: paths.size,
  source_inventory: patterns.transform_values { |pattern| sources.count { |source| source.match?(pattern) } },
  importmap: File.file?("config/importmap.rb"), phases: {} }
def save(output, result)
  File.write(File.join(output, "result.json"), JSON.pretty_generate(result))
end
save(output, result)

def run_phase(output, name, *command, env: {})
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  log = File.join(output, "#{name}.log")
  status = nil
  File.open(log, "w") do |io|
    pid = Process.spawn(env, "timeout", "--kill-after=10s", "240s", *command, out: io, err: [:child, :out])
    _, status = Process.wait2(pid)
  end
  code = status.exitstatus || 128 + status.termsig.to_i
  content = File.read(log)
  summary = content.scan(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/).last
  warn "#{name} failed:\n#{content.lines.last(35).join}" if code != 0
  { exit_code: code, elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
    test_summary: summary && %w[runs assertions failures errors skips].zip(summary.map(&:to_i)).to_h,
    timed_out: [124, 137].include?(code), log: File.basename(log) }
end

def valid_test_run?(phase)
  s = phase[:test_summary]
  phase[:exit_code] == 0 && s && s["runs"] > 0 && s["assertions"] > 0 && s["skips"] == 0
end

result[:phases][:database_setup] = run_phase(output, "database-setup", "bin/rails", "db:setup")
save(output, result)
if result[:phases][:database_setup][:exit_code] != 0
  result[:status] = "setup_blocked"
else
  result[:phases][:browser] = run_phase(output, "browser", "bin/rails", "test", selected, "--seed", "12345")
  save(output, result)
  if !valid_test_run?(result[:phases][:browser])
    result[:status] = "browser_baseline_blocked"
  else
    result[:phases][:database_reset] = run_phase(output, "database-reset", "bin/rails", "db:reset")
    save(output, result)
    if result[:phases][:database_reset][:exit_code] != 0
      result[:status] = "database_reset_blocked"
    else
      helper = "test/application_system_test_case.rb"
      original = File.read(helper)
      begin
        # Preserve upstream tests, fixtures and helpers. Replace only driver selection.
        File.open(helper, "a") do |file|
          file.puts <<~RUBY
            require "domstride/rails"
            class ApplicationSystemTestCase
              include Domstride::RailsSystemTestSupport
              driven_by :domstride
            end
          RUBY
        end
        result[:phases][:domstride] = run_phase(output, "domstride", "bin/rails", "test", selected, "--seed", "12345", env: { "DOMSTRIDE_ASSETS" => "bundle" })
      ensure
        File.write(helper, original)
      end
      reference = result[:phases][:browser][:test_summary]
      candidate = result[:phases][:domstride]
      if valid_test_run?(candidate) && candidate[:test_summary]["runs"] == reference["runs"] && candidate[:test_summary]["assertions"] == reference["assertions"]
        result[:status] = "selected_file_passed"
      else
        result[:status] = "candidate_blocked_or_different"
      end
    end
  end
end
save(output, result)
puts JSON.pretty_generate(result)
# A discovery run is not a compatibility pass. Preserve failure evidence as artifacts.
