require "json"
require "open3"
require "uri"
require "timeout"
require "digest"
require_relative "domstride/version"

module Domstride
  class Error < StandardError; end
  class JavaScriptError < Error; end
  class Session
    WORKER = File.expand_path("../runtime/worker.cjs", __dir__)

    def self.open(**options)
      session = new(**options)
      yield session
    ensure
      session&.close
    end

    def initialize(runtime: ENV.fetch("DOMSTRIDE_RUNTIME", "node"), engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"), app: nil, profile: ENV["DOMSTRIDE_PROFILE"] == "1", wait_strategy: ENV.fetch("DOMSTRIDE_WAIT", "poll"), bundle_cache: ENV.fetch("DOMSTRIDE_BUNDLE_CACHE", "off"), settling: ENV.fetch("DOMSTRIDE_SETTLING", "checkpoint"), clock: ENV.fetch("DOMSTRIDE_CLOCK", "real"), clock_epoch_ms: 1_700_000_000_000)
      raise ArgumentError, "Unknown bundle cache mode" unless %w[off source compiled].include?(bundle_cache)
      if bundle_cache == "compiled" && !%w[jsdom jsdom31].include?(engine)
        raise ArgumentError, "Compiled bundles require jsdom"
      end
      raise ArgumentError, "Unknown settling mode" unless %w[checkpoint tracked].include?(settling)
      raise ArgumentError, "Unknown clock mode" unless %w[real virtual].include?(clock)
      @settling, @clock, @clock_epoch_ms = settling, clock, Integer(clock_epoch_ms)
      @bundle_cache = bundle_cache
      @bundle_digest = nil
      @input, @output, @wait = Open3.popen2(runtime, WORKER, engine)
      @mutex = Mutex.new
      @sequence = 0
      @app = app
      @wait_strategy = wait_strategy
      @profiling = profile
      reset_profile!
      if app
        require "rack/test"
        @rack_session = Rack::Test::Session.new(Rack::MockSession.new(app, "example.test"))
      end
    end

    def mount_html(html, url: "https://example.test/", bridge: false)
      # Only explicitly marked final classic scripts are eligible.
      clock_options = { clock: @clock, clock_epoch_ms: @clock_epoch_ms }
      match = @bundle_cache != "off" && /<script data-domstride-cache="bundle">([^<]*(?:<(?!\/script\b)[^<]*)*)<\/script>\s*<\/body>\s*<\/html>\s*\z/i.match(html)
      return call("mount", html: html, url: url, bridge: bridge, **clock_options) unless match

      source = match[1]
      digest = Digest::SHA256.hexdigest(source)
      cached = digest == @bundle_digest
      args = { html: html[0...match.begin(1)] + html[match.end(1)..], url: url, bridge: bridge,
               bundle: { digest: digest, mode: @bundle_cache, source: cached ? nil : source }, **clock_options }
      result = call("mount", **args)
      @bundle_digest = digest
      result
    rescue Error
      # A failed mount may have replaced the worker's cache.
      @bundle_digest = nil
      raise
    end

    def visit(path)
      raise Error, "Rack application required" unless @app
      url = URI.join("http://example.test/", path).to_s
      result = request_app("url" => url, "method" => "GET", "headers" => {})
      raise Error, "Visit failed: HTTP #{result[:status]}" unless result[:status] == 200
      mount_html(result[:body], url: url, bridge: true)
    end

    def wait_for_text(selector, expected, timeout: 2)
      call("wait_for_text", selector: selector, expected: expected, timeout: timeout, strategy: @wait_strategy)
    end

    # Drain tracked fetches, due timers and a bounded quiet event-loop window.
    def settle!
      call("settle")
    end

    # Advance document JavaScript time, not Ruby or Rails time.
    def advance_time(milliseconds)
      call("advance_time", milliseconds: milliseconds)
    end

    def clock_state
      call("clock_state")
    end

    # Check errors already delivered by the JavaScript event loop.
    def check_javascript!
      call("check_javascript")
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

    def reset_profile!
      @profile = { commands: {}, rack_requests: 0, rack_ms: 0.0, bytes_sent: 0, bytes_received: 0, bundle_hits: 0, bundle_misses: 0 }
    end

    def profile
      Marshal.load(Marshal.dump(@profile))
    end

    # Process identity for diagnostics and resource sampling.
    def worker_pid = @wait.pid

    def memory
      path = "/proc/#{worker_pid}/status"
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
      started = monotonic_ms if @profiling
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
    ensure
      if @profiling
        @profile[:rack_requests] += 1
        @profile[:rack_ms] += monotonic_ms - started
      end
    end

    def monotonic_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
    end

    def write_message(message)
      payload = JSON.generate(message)
      @profile[:bytes_sent] += payload.bytesize + 1 if @profiling
      @input.puts(payload)
    end

    def call(command, **arguments)
      @mutex.synchronize do
        started = monotonic_ms if @profiling
        label = command == "node_action" ? "node_action.#{arguments[:operation]}" : command
        @sequence += 1
        write_message(id: @sequence, command: command, profile: @profiling, settling: @settling, **arguments)
        response = Timeout.timeout(15) do
          loop do
            line = @output.gets
            raise Error, "JavaScript worker terminated" unless line
            @profile[:bytes_received] += line.bytesize if @profiling
            reply = JSON.parse(line)
            break reply unless reply["kind"] == "request"
            begin
              result = request_app(reply)
              write_message(kind: "response", request_id: reply["request_id"], ok: true, **result)
            rescue StandardError => e
              write_message(kind: "response", request_id: reply["request_id"], ok: false, error: e.message)
            end
          end
        end
        raise Error, "Protocol ID mismatch" unless response["id"] == @sequence
        unless response["ok"]
          error_class = response["error_type"] == "javascript" ? JavaScriptError : Error
          raise error_class, response["error"]
        end
        if @profiling && response["bundle_cache"]
          @profile[response["bundle_cache"] == "hit" ? :bundle_hits : :bundle_misses] += 1
        end
        response["value"]
      ensure
        if @profiling && started
          row = (@profile[:commands][label] ||= { count: 0, ruby_wall_ms: 0.0, worker_wall_ms: 0.0 })
          row[:count] += 1
          row[:ruby_wall_ms] += monotonic_ms - started
          row[:worker_wall_ms] += response&.fetch("worker_ms", 0).to_f
        end
      end
    rescue IOError, SystemCallError, JSON::ParserError => e
      raise Error, "Worker communication failed: #{e.message}"
    end
  end
end
