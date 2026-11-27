require "json"
require "open3"
require "uri"
require "timeout"
require "digest"
require "base64"
require_relative "domstride/version"
require_relative "domstride/configuration"
require_relative "domstride/runtime"
require_relative "domstride/recording"

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

    def initialize(app: nil, performance_profile: nil, recording_directory: ENV["DOMSTRIDE_RECORD_DIR"], recording_html: ENV["DOMSTRIDE_RECORD_HTML"] == "1", **options)
      settings = Configuration.resolve(performance_profile: performance_profile, **options)
      runtime, engine, profile, wait_strategy, bundle_cache, settling, clock, clock_epoch_ms =
        settings.values_at(:runtime, :engine, :profile, :wait_strategy, :bundle_cache, :settling, :clock, :clock_epoch_ms)
      @settings = settings.freeze
      @assets = settings[:assets]
      @websocket_url = settings[:websocket_url]
      if @websocket_url
        endpoint = URI.parse(@websocket_url)
        unless endpoint.scheme == "ws" && endpoint.host == "127.0.0.1" && endpoint.port && endpoint.port.between?(1, 65535) && endpoint.path.start_with?("/") && !endpoint.userinfo && !endpoint.query && !endpoint.fragment
          raise ArgumentError, "Expected explicit ws://127.0.0.1:PORT/path endpoint"
        end
        unless runtime == "node" && %w[jsdom jsdom31].include?(engine) && clock == "real" && app
          raise ArgumentError, "WebSocket bridge requires a Rack app, Node/jsdom and real clock"
        end
      end
      raise ArgumentError, "Unknown assets mode" unless %w[off bundle].include?(@assets)
      if @assets == "bundle" && (!%w[jsdom jsdom31].include?(engine) || runtime != "node" || bundle_cache != "off")
        raise ArgumentError, "Asset bundling requires Node/jsdom and bundle_cache off"
      end
      raise ArgumentError, "Unknown DOM engine" unless %w[jsdom jsdom31 happy-dom].include?(engine)
      raise ArgumentError, "Unknown wait strategy" unless %w[poll observer].include?(wait_strategy)
      raise ArgumentError, "Unknown bundle cache mode" unless %w[off source compiled].include?(bundle_cache)
      if bundle_cache == "compiled" && !%w[jsdom jsdom31].include?(engine)
        raise ArgumentError, "Compiled bundles require jsdom"
      end
      raise ArgumentError, "Unknown settling mode" unless %w[checkpoint tracked].include?(settling)
      raise ArgumentError, "Unknown clock mode" unless %w[real virtual].include?(clock)
      @settling, @clock, @clock_epoch_ms = settling, clock, Integer(clock_epoch_ms)
      @bundle_cache = bundle_cache
      @bundle_digest = nil
      @input, @output, @wait = Open3.popen2(runtime, Runtime.worker_path, engine)
      @mutex = Mutex.new
      @sequence = 0
      @app = app
      @wait_strategy = wait_strategy
      @profiling = profile
      reset_profile!
      @recorder = Recording.new(directory: recording_directory, html: recording_html, engine: engine, runtime: runtime) if recording_directory && !recording_directory.empty?
      if app
        require "rack/test"
        @rack_session = Rack::Test::Session.new(Rack::MockSession.new(app, "example.test"))
      end
    end

    attr_reader :settings, :recorder
    attr_accessor :recording_step

    def mount_html(html, url: "https://example.test/", bridge: false)
      # Only explicitly marked final classic scripts are eligible.
      clock_options = { clock: @clock, clock_epoch_ms: @clock_epoch_ms, assets: @assets, websocket_url: @websocket_url }
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
      mount_html(result[:body], url: result.fetch(:url), bridge: true)
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
    def self.json_script_argument(value)
      case value
      when NilClass, TrueClass, FalseClass, String, Integer then value
      when Float
        raise ArgumentError, "Non-finite script argument" unless value.finite?
        value
      when Array then value.map { |item| json_script_argument(item) }
      when Hash
        raise ArgumentError, "Script argument keys must be strings" unless value.keys.all? { |key| key.is_a?(String) }
        value.transform_values { |item| json_script_argument(item) }
      else raise ArgumentError, "Unsupported JavaScript argument: #{value.class}"
      end
    end

    def execute_script(script, *args)
      call("execute_script", script: script, arguments: args.map { |value| { kind: "json", value: self.class.json_script_argument(value) } })
      nil
    end

    def evaluate_script(script, *args)
      call("evaluate_script", script: script, arguments: args.map { |value| { kind: "json", value: self.class.json_script_argument(value) } })
    end

    def websocket_state
      call("websocket_state")
    end

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
        @recorder&.close
      end
    end

    private

    REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
    MAX_REDIRECTS = 10

    def request_app(message)
      mode = message.fetch("redirect", "follow")
      raise Error, "Unsupported redirect mode" unless %w[follow error manual].include?(mode)
      current = message.dup
      visited = {}
      redirects = 0
      loop do
        uri = URI.parse(current.fetch("url"))
        uri.fragment = nil
        current["url"] = uri.to_s
        key = [current.fetch("method").upcase, uri.to_s]
        raise Error, "Redirect loop detected" if visited[key]
        visited[key] = true
        result = request_once(current)
        location = result[:headers].find { |name, _| name.downcase == "location" }&.last
        unless REDIRECT_STATUSES.include?(result[:status]) && location
          return result.merge(redirected: redirects.positive?)
        end
        raise Error, "Redirect forbidden by fetch mode" if mode == "error"
        # Opaque redirect responses are not representable by the current bridge.
        raise Error, "UNSUPPORTED_MANUAL_REDIRECT" if mode == "manual"
        raise Error, "Redirect limit exceeded" if redirects >= MAX_REDIRECTS
        target = URI.join(uri.to_s, location)
        target.fragment = nil
        validate_origin!(target)
        method = current.fetch("method").upcase
        headers = current.fetch("headers", {}).dup
        body = current["body"]
        if (result[:status] == 303 && !%w[GET HEAD].include?(method)) || ([301, 302].include?(result[:status]) && method == "POST")
          method = "GET"
          body = nil
          headers.reject! { |name, _| %w[content-type content-length content-encoding content-language content-location].include?(name.downcase) }
        end
        current = current.merge("url" => target.to_s, "method" => method, "headers" => headers, "body" => body, "body_encoding" => body.nil? ? nil : current["body_encoding"])
        redirects += 1
      end
    rescue URI::InvalidURIError => e
      raise Error, "Invalid redirect or request URL: #{e.message}"
    end

    def validate_origin!(uri)
      raise Error, "Only same-origin requests are supported" unless uri.scheme == "http" && uri.host == "example.test" && uri.port == 80 && uri.userinfo.nil?
    end

    def request_once(message)
      started = monotonic_ms if @profiling
      uri = URI.parse(message.fetch("url"))
      method = message.fetch("method").upcase
      validate_origin!(uri)
      raise Error, "Unsupported HTTP method: #{method}" unless %w[GET HEAD POST PUT PATCH DELETE].include?(method)
      headers = message.fetch("headers", {}).reject { |key, _| %w[cookie host content-length].include?(key.downcase) }.to_h do |key, value|
        [key.downcase == "content-type" ? "CONTENT_TYPE" : "HTTP_#{key.upcase.tr("-", "_")}", value]
      end
      if %w[GET HEAD].include?(method)
        @rack_session.public_send(method.downcase, uri.to_s, {}, headers)
      else
        headers["HTTP_ORIGIN"] ||= "http://example.test"
        body = message["body"].to_s
        mime = headers["CONTENT_TYPE"].to_s.split(";", 2).first
        if message["body_encoding"] == "base64"
          raise Error, "Unsupported binary request body" unless mime == "multipart/form-data"
          raise Error, "Multipart body limit exceeded" if body.bytesize > ((8 * 1024 * 1024 + 65536 + 2) / 3) * 4
          body = Base64.strict_decode64(body)
          raise Error, "Multipart body limit exceeded" if body.bytesize > 8 * 1024 * 1024 + 65536
        elsif !body.empty? && !%w[application/x-www-form-urlencoded application/json].include?(mime)
          raise Error, "Unsupported request body MIME"
        end
        @rack_session.public_send(method.downcase, uri.to_s, body, headers)
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
        recording = @recorder&.accept?(label)
        recording_started = monotonic_ms if recording
        record_options = recording ? { record_event: true, record_html: @recorder.html? } : {}
        write_message(id: @sequence, command: command, profile: @profiling, settling: @settling, **record_options, **arguments)
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
        if recording_started
          @recorder.record(sequence: @sequence, kind: label, step: @recording_step,
            duration_ms: monotonic_ms - recording_started, passed: response && response["id"] == @sequence && response["ok"] == true,
            evidence: response && response["recording"])
        end
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
