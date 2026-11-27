require "capybara"
require "base64"
require "mini_mime"
require_relative "../domstride"

module Domstride
  module CapybaraAdapter
    class StaleElement < Domstride::Error; end

    class Driver < ::Capybara::Driver::Base
      def initialize(app, performance_profile: nil, **options)
        @app = app
        @generation = 0
        @settings = Configuration.resolve(performance_profile: performance_profile, **options)
        name = performance_profile || ENV["DOMSTRIDE_PERFORMANCE_PROFILE"]
        if name.to_s == "deterministic" && @settings[:clock] == "virtual"
          raise ArgumentError, "Deterministic profile requires the native DSL; Capybara virtual retries are not supported"
        end
        @query_prefetch = @settings[:query_prefetch]
        @reuse_worker = ENV["DOMSTRIDE_REUSE_WORKER"] == "1"
        if @reuse_worker && (@settings[:runtime] != "node" || !%w[jsdom jsdom31].include?(@settings[:engine]) ||
            @settings[:clock] != "real" || @settings[:websocket_url] || ENV["DOMSTRIDE_RECORD_DIR"].to_s != "")
          raise ArgumentError, "Persistent worker requires Node/jsdom, real clock, no websocket and no recording"
        end
        @mounted = false
        @owner_pid = Process.pid
      end

      attr_reader :generation

      def worker
        if @reuse_worker && !@exit_cleanup_registered
          @exit_cleanup_registered = true
          at_exit { quit if Process.pid == @owner_pid }
        end
        @worker ||= Domstride::Session.new(app: @app, **@settings).tap { |session| session.recording_step = @recording_step }
      end

      def recording_step=(sequence)
        @recording_step = sequence
        @worker.recording_step = sequence if @worker
      end

      def visit(path)
        worker.visit(path).tap { @mounted = true }
      end

      def current_url
        @worker && (!@reuse_worker || @mounted) ? command("current_url") : "about:blank"
      end

      def html
        @worker && (!@reuse_worker || @mounted) ? command("html") : ""
      end

      def refresh
        visit(current_url)
      end

      def find_css(query, **hints)
        find_nodes("css", query, **hints)
      end

      def find_xpath(query, **hints)
        find_nodes("xpath", query, **hints)
      end

      def find_nodes(kind, query, root: nil, **hints)
        if @query_prefetch
          rows = command("find_handles", kind_of_query: kind, query: query, root: root,
                         prefetch: true, uses_visibility: hints[:uses_visibility] == true)
          rows.map do |row|
            cache = { tag_name: row.fetch("tag_name") }
            cache[:visible] = row.fetch("visible") if row.key?("visible")
            Node.new(self, row.fetch("id"), cache)
          end
        else
          command("find_handles", kind_of_query: kind, query: query, root: root).map { |id| Node.new(self, id) }
        end
      end

      def command(name, **args)
        worker.dom_command(name, **args)
      rescue Domstride::Error => e
        raise StaleElement, e.message if e.message == "STALE_ELEMENT"
        raise ::Capybara::NotSupportedByDriverError, e.message if e.message.start_with?("UNSUPPORTED_")
        raise
      end

      def accept_modal(type, **options, &block)
        handle_confirm(type, true, **options, &block)
      end

      def dismiss_modal(type, **options, &block)
        handle_confirm(type, false, **options, &block)
      end

      # A decision is armed before the triggering action, since a DOM confirm
      # call is synchronous and cannot pause for an interactive browser dialog.
      def handle_confirm(type, accept, text: nil, wait: nil, **options)
        unless type.to_sym == :confirm && (text.nil? || text.is_a?(String)) && options.empty?
          raise ::Capybara::NotSupportedByDriverError, "Only confirm dialogs with optional string text are supported"
        end
        command("confirm_arm", accept: accept, text: text)
        begin
          yield
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (wait || ::Capybara.default_max_wait_time)
          loop do
            result = command("confirm_result")
            if result
              raise ::Capybara::ModalNotFound, "Confirmation text did not match" unless result.fetch("matched")
              return result.fetch("text")
            end
            break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            sleep 0.01
          end
          raise ::Capybara::ModalNotFound, "No confirmation appeared"
        ensure
          original_error = $!
          begin
            command("confirm_clear")
          rescue StandardError
            raise unless original_error
          end
        end
      end
      private :handle_confirm

      def execute_script(script, *args)
        command("execute_script", script: script, arguments: script_arguments(args))
        nil
      end

      def evaluate_script(script, *args)
        command("evaluate_script", script: script, arguments: script_arguments(args))
      end

      def script_arguments(args)
        args.map do |arg|
          if arg.is_a?(Node)
            raise ArgumentError, "Element belongs to another driver" unless arg.driver.equal?(self)
            arg.ensure_current_generation!
            { kind: "element", handle: arg.native }
          else
            { kind: "json", value: Domstride::Session.json_script_argument(arg) }
          end
        end
      end

      def diagnostics
        {
          version: Domstride::VERSION,
          engine: @settings[:engine],
          runtime: @settings[:runtime],
          clock: @settings[:clock],
          settling: @settings[:settling],
          assets: @settings[:assets],
          bundle_cache: @settings[:bundle_cache],
          query_prefetch: @settings[:query_prefetch],
          websocket_enabled: !@settings[:websocket_url].nil?,
          worker_started: !@worker.nil?,
          profile: @worker && @settings[:profile] ? @worker.profile : nil
        }
      end

      # One document only. No additional browser windows or tabs.
      def current_window_handle = "domstride-main"
      def window_handles = [current_window_handle]

      def switch_to_window(handle)
        raise ::Capybara::WindowError, "Unknown window" unless handle == current_window_handle
      end

      def wait? = true
      def needs_server? = false
      def invalid_element_errors = [StaleElement]

      def reset!
        return quit unless @reuse_worker
        begin
          @worker&.reset_document!
        rescue StandardError
          quit
          raise
        ensure
          @mounted = false
          @recording_step = nil
          @generation += 1
        end
      end

      def quit
        @worker&.close
      ensure
        @worker = nil
        @mounted = false
        @generation += 1
      end
    end

    class Node < ::Capybara::Driver::Node
      def initialize(driver, native, initial_cache = {})
        super
        @generation = driver.generation
      end

      attr_reader :generation

      def ensure_current_generation!
        raise StaleElement, "STALE_ELEMENT" unless generation == driver.generation
      end

      def operation(name, **args)
        ensure_current_generation!
        driver.command("node_action", handle: native, operation: name, **args)
      end

      def all_text = operation("all_text")
      def visible_text = operation("visible_text")
      def [](name) = operation("attribute", name: name)
      def value = operation("value")
      def tag_name = operation("tag_name")
      def visible? = operation("visible")
      def disabled? = operation("disabled")
      def checked? = operation("checked")
      def selected? = operation("selected")

      def obscured?
        raise ::Capybara::NotSupportedByDriverError, "No layout or hit testing"
      end

      def set(value, **options)
        raise ::Capybara::NotSupportedByDriverError, "Input options" unless options.empty?
        if tag_name == "input" && self["type"] == "file"
          return attach_files(value)
        end
        operation("set", value: value)
      end

      def select_option = operation("select_option")
      def unselect_option = operation("unselect_option")

      KEY_NAMES = {
        backspace: "Backspace", delete: "Delete", left: "ArrowLeft", right: "ArrowRight",
        home: "Home", end: "End", enter: "Enter", return: "Enter", escape: "Escape", tab: "Tab"
      }.freeze

      def send_keys(*keys)
        encoded = keys.map do |key|
          if key.is_a?(String)
            { kind: "text", value: key }
          elsif KEY_NAMES.key?(key)
            { kind: "special", value: KEY_NAMES.fetch(key) }
          else
            raise ::Capybara::NotSupportedByDriverError, "Unsupported key or chord"
          end
        end
        operation("send_keys", keys: encoded)
      end

      def attach_files(value)
        ensure_current_generation!
        raise ::Capybara::NotSupportedByDriverError, "File inputs require jsdom" if driver.worker.settings[:engine] == "happy-dom"
        paths = Array(value)
        raise ArgumentError, "Expected file paths" unless paths.all? { |path| path.is_a?(String) && File.file?(path) }
        remaining = 8 * 1024 * 1024
        files = paths.map do |path|
          data = File.binread(path, remaining + 1)
          remaining -= data.bytesize
          raise ArgumentError, "Upload byte limit exceeded" if remaining.negative?
          { name: File.basename(path), type: MiniMime.lookup_by_filename(path)&.content_type || "application/octet-stream",
            data: Base64.strict_encode64(data) }
        end
        operation("attach_files", files: files)
      end

      def click(keys = [], **options)
        # Capybara supplies the W3C default center offset even without coordinates.
        options.delete(:offset) if options[:offset] == :center
        raise ::Capybara::NotSupportedByDriverError, "Click modifiers or coordinates" unless keys.empty? && options.empty?
        operation("click")
      end

      def find_css(query, **hints)
        ensure_current_generation!
        driver.find_nodes("css", query, root: native, **hints)
      end

      def find_xpath(query, **hints)
        ensure_current_generation!
        driver.find_nodes("xpath", query, root: native, **hints)
      end

      def ==(other)
        other.is_a?(Node) && driver.equal?(other.driver) && generation == other.generation && native == other.native
      end
    end
  end
end

Capybara.register_driver(:domstride) { |app| Domstride::CapybaraAdapter::Driver.new(app) }
