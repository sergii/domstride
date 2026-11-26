require "json"
require "open3"
require_relative "domstride/version"

module Domstride
  class Error < StandardError; end
  class Session
    WORKER = File.expand_path("../runtime/worker.cjs", __dir__)

    def self.open(**options)
      session = new(**options)
      yield session
    ensure
      session&.close
    end

    def initialize(runtime: ENV.fetch("DOMSTRIDE_RUNTIME", "node"), engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"))
      @input, @output, @wait = Open3.popen2(runtime, WORKER, engine)
      @mutex = Mutex.new
      @sequence = 0
    end

    def mount_html(html)
      call("mount", html: html)
    end

    def click(selector)
      call("click", selector: selector)
    end

    def text(selector)
      call("text", selector: selector)
    end

    def count(selector)
      call("count", selector: selector)
    end

    def assert_text(selector, expected)
      actual = text(selector)
      raise Error, "Expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
      true
    end

    # Commands execute in order; a failure stops the remaining commands.
    def batch
      commands = Batch.new
      yield commands
      call("batch", commands: commands.commands)
    end

    def memory
      path = "/proc/#{@wait.pid}/status"
      return {} unless File.file?(path)
      File.read(path).scan(/^(VmRSS|VmHWM):\s+(\d+) kB/).to_h.transform_values(&:to_i)
    end

    class Batch
      attr_reader :commands

      def initialize
        @commands = []
      end

      def click(selector)
        @commands << { command: "click", selector: selector }
      end

      def assert_text(selector, expected)
        @commands << { command: "assert_text", selector: selector, expected: expected }
      end
    end

    def close
      @mutex.synchronize do
        @input.close unless @input.closed?
        @output.close unless @output.closed?
        @wait.join(2) || (Process.kill("KILL", @wait.pid) rescue nil)
      end
    end

    private

    def call(command, **arguments)
      @mutex.synchronize do
        @sequence += 1
        @input.puts(JSON.generate(id: @sequence, command: command, **arguments))
        line = @output.gets
        raise Error, "JavaScript worker terminated" unless line
        response = JSON.parse(line)
        raise Error, "Protocol ID mismatch" unless response["id"] == @sequence
        raise Error, response["error"] unless response["ok"]
        response["value"]
      end
    rescue IOError, SystemCallError, JSON::ParserError => e
      raise Error, "Worker communication failed: #{e.message}"
    end
  end
end
