require "json"
require "open3"
require "uri"
require "timeout"
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

    def initialize(runtime: ENV.fetch("DOMSTRIDE_RUNTIME", "node"), engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"), app: nil)
      @input, @output, @wait = Open3.popen2(runtime, WORKER, engine)
      @mutex = Mutex.new
      @sequence = 0
      @app = app
      if app
        require "rack/test"
        @rack_session = Rack::Test::Session.new(Rack::MockSession.new(app, "example.test"))
      end
    end

    def mount_html(html, url: "https://example.test/", bridge: false)
      call("mount", html: html, url: url, bridge: bridge)
    end

    def visit(path)
      raise Error, "Rack application required" unless @app
      url = URI.join("http://example.test/", path).to_s
      result = request_app("url" => url, "method" => "GET", "headers" => {})
      raise Error, "Visit failed: HTTP #{result[:status]}" unless result[:status] == 200
      mount_html(result[:body], url: url, bridge: true)
    end

    def wait_for_text(selector, expected, timeout: 2)
      call("wait_for_text", selector: selector, expected: expected, timeout: timeout)
    end

    def fill(selector, value)
      call("fill", selector: selector, value: value)
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

    # Driver-only protocol. Handles are scoped to the mounted document.
    def dom_command(command, **arguments)
      call(command, **arguments)
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

    def request_app(message)
      uri = URI.parse(message.fetch("url"))
      method = message.fetch("method").upcase
      raise Error, "Only same-origin GET and POST requests are supported" unless uri.scheme == "http" && uri.host == "example.test" && uri.port == 80 && %w[GET POST].include?(method)
      headers = message.fetch("headers", {}).reject { |key, _| %w[cookie host content-length].include?(key.downcase) }.to_h do |key, value|
        [key.downcase == "content-type" ? "CONTENT_TYPE" : "HTTP_#{key.upcase.tr("-", "_")}", value]
      end
      headers["HTTP_ORIGIN"] ||= "http://example.test" if method == "POST"
      if method == "POST"
        raise Error, "Only URL-encoded POST bodies are supported" unless headers["CONTENT_TYPE"].to_s.start_with?("application/x-www-form-urlencoded")
        @rack_session.post(uri.to_s, message.fetch("body", ""), headers)
      else
        @rack_session.get(uri.to_s, {}, headers)
      end
      response = @rack_session.last_response
      response_headers = response.headers.reject { |key, _| key.downcase == "set-cookie" }
      { status: response.status, headers: response_headers.transform_values { |v| Array(v).join(", ") }, body: response.body, url: uri.to_s }
    end

    def call(command, **arguments)
      @mutex.synchronize do
        @sequence += 1
        @input.puts(JSON.generate(id: @sequence, command: command, **arguments))
        response = Timeout.timeout(15) do
          loop do
            line = @output.gets
            raise Error, "JavaScript worker terminated" unless line
            reply = JSON.parse(line)
            break reply unless reply["kind"] == "request"
            begin
              result = request_app(reply)
              @input.puts(JSON.generate(kind: "response", request_id: reply["request_id"], ok: true, **result))
            rescue StandardError => e
              @input.puts(JSON.generate(kind: "response", request_id: reply["request_id"], ok: false, error: e.message))
            end
          end
        end
        raise Error, "Protocol ID mismatch" unless response["id"] == @sequence
        raise Error, response["error"] unless response["ok"]
        response["value"]
      end
    rescue IOError, SystemCallError, JSON::ParserError => e
      raise Error, "Worker communication failed: #{e.message}"
    end
  end
end
