require "tempfile"
require "fileutils"
require "tmpdir"
require "json"

module Domstride
  # Explicit case boundary. Fiber-local context avoids changing process-wide ENV.
  class ReportCase
    STATUSES = %w[passed failed skipped pending unknown].freeze
    KEY = :domstride_report_case

    attr_reader :path, :status
    attr_accessor :assertions

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

    def status=(value)
      raise ArgumentError, "Invalid case status" unless STATUSES.include?(value)
      @status = value
    end

    def finish
      write(status || "unknown")
    rescue StandardError => error
      warn "Domstride case report unavailable: #{error.class}"
    end

    private

    def write(value)
      row = {schema_version: 1, name: @name, status: value,
        framework: @framework, assertions: @assertions,
        duration_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started) * 1000}
      Tempfile.create(["case-", ".json"], path) do |file|
        file.write(JSON.generate(row))
        file.flush
        File.rename(file.path, File.join(path, "case.json"))
      end
    end
  end
end
