require "tempfile"
require "fileutils"
require "tmpdir"
require "json"
require_relative "protocol"

module Domstride
  # Explicit case boundary. Fiber-local context avoids changing process-wide ENV.
  class ReportCase
    STATUSES = Protocol::CASE_STATUSES
    MAX_STEPS = Protocol::MAX_STEPS
    MAX_ASSERTIONS = Protocol::MAX_ASSERTIONS
    ASSERTION_STATUSES = Protocol::ASSERTION_STATUSES
    STEP_STATUSES = Protocol::STEP_STATUSES
    KEY = :domstride_report_case

    attr_reader :path, :status, :videos, :video_markers
    attr_accessor :assertions, :browser_video

    def self.current = Thread.current[KEY]

    def self.capture(directory:, name:, html: false)
      raise ArgumentError, "Nested report cases are not supported" if current
      item = new(directory: directory, name: name, html: html)
      Thread.current[KEY] = item
      begin
        value = yield item
        item.status ||= "passed"
        value
      rescue Exception
        # Preserve assertion failures and all other original exceptions.
        item.status ||= "failed"
        raise
      ensure
        Thread.current[KEY] = nil
        item.finish
      end
    end

    def initialize(directory:, name:, html:, framework: nil)
      @framework = framework
      @steps = []
      @videos = []
      @video_markers = []
      @assertion_events = []
      @active_assertion = nil
      @active_step = nil
      @name = String(name)
      raise ArgumentError, "Invalid case name" if @name.empty? || @name.bytesize > 1024 || !@name.valid_encoding?
      FileUtils.mkdir_p(directory, mode: 0o700)
      @path = Dir.mktmpdir("domstride-case-", File.expand_path(directory))
      @html = html == true
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @status = nil
      write("unknown")
    end

    def html? = @html
    attr_reader :active_step, :active_assertion

    def begin_assertion(kind)
      return if active_assertion || @assertion_events.size >= MAX_ASSERTIONS
      @active_assertion = {sequence: @assertion_events.size + 1, kind: bounded(kind, 96),
        step_sequence: active_step, status: "unknown", duration_ms: 0}
      @assertion_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @assertion_reads = 0
      @assertion_events << active_assertion
      active_assertion
    end

    def assertion_read_allowed?
      return false unless active_assertion && @assertion_reads < 4
      @assertion_reads += 1
      true
    end

    def end_assertion(item, status)
      return unless item && active_assertion.equal?(item)
      item[:status] = ASSERTION_STATUSES.include?(status) ? status : "unknown"
      item[:duration_ms] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @assertion_started) * 1000
      @video_markers << {kind: "assertion", sequence: item[:sequence], monotonic: Process.clock_gettime(Process::CLOCK_MONOTONIC)}
      @active_assertion = nil
    end

    def start_step(keyword:, text: nil)
      finish_step("unknown") if active_step
      return if @steps.size >= MAX_STEPS
      @active_step = @steps.size + 1
      @step_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @video_markers << {kind: "step", sequence: active_step, monotonic: @step_started}
      @steps << {sequence: active_step, keyword: bounded(keyword, 48), text: text && bounded(text, 1024), status: "unknown", duration_ms: 0}
    end

    def finish_step(status)
      return unless active_step
      row = @steps.fetch(active_step - 1)
      row[:status] = STEP_STATUSES.include?(status) ? status : "unknown"
      row[:duration_ms] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @step_started) * 1000
      @active_step = nil
    end

    def status=(value)
      raise ArgumentError, "Invalid case status" unless STATUSES.include?(value)
      @status = value
    end

    def finish
      finish_step("unknown") if active_step
      end_assertion(active_assertion, "unknown") if active_assertion
      write(status || "unknown")
    rescue StandardError => error
      warn "Domstride case report unavailable: #{error.class}"
    end

    private

    def bounded(value, limit)
      value.to_s.encode("UTF-8", invalid: :replace, undef: :replace).byteslice(0, limit).scrub
    end

    def write(value)
      row = {format: Protocol::FORMAT, schema_version: Protocol::VERSION, producer: "domstride-ruby", name: @name, status: value,
        framework: @framework, assertions: @assertions, steps: @steps, assertion_events: @assertion_events, videos: @videos,
        duration_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started) * 1000}
      Tempfile.create(["case-", ".json"], path) do |file|
        file.write(JSON.generate(row))
        file.flush
        File.rename(file.path, File.join(path, "case.json"))
      end
    end
  end
end
