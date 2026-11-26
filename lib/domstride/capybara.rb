require "capybara"
require_relative "../domstride"

module Domstride
  module CapybaraAdapter
    class StaleElement < Domstride::Error; end

    class Driver < ::Capybara::Driver::Base
      def initialize(app, performance_profile: nil, **options)
        @app = app
        @settings = Configuration.resolve(performance_profile: performance_profile, **options)
        name = performance_profile || ENV["DOMSTRIDE_PERFORMANCE_PROFILE"]
        if name.to_s == "deterministic" && @settings[:clock] == "virtual"
          raise ArgumentError, "Deterministic profile requires the native DSL; Capybara virtual retries are not supported"
        end
        @query_prefetch = @settings[:query_prefetch]
      end

      def worker
        @worker ||= Domstride::Session.new(app: @app, **@settings)
      end

      def visit(path)
        worker.visit(path)
      end

      def current_url
        @worker ? command("current_url") : "about:blank"
      end

      def html
        @worker ? command("html") : ""
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

      def wait? = true
      def needs_server? = false
      def invalid_element_errors = [StaleElement]

      def reset!
        @worker&.close
        @worker = nil
      end
      alias quit reset!
    end

    class Node < ::Capybara::Driver::Node
      def operation(name, **args)
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
        operation("set", value: value)
      end

      def click(keys = [], **options)
        # Capybara supplies the W3C default center offset even without coordinates.
        options.delete(:offset) if options[:offset] == :center
        raise ::Capybara::NotSupportedByDriverError, "Click modifiers or coordinates" unless keys.empty? && options.empty?
        operation("click")
      end

      def find_css(query, **hints)
        driver.find_nodes("css", query, root: native, **hints)
      end

      def find_xpath(query, **hints)
        driver.find_nodes("xpath", query, root: native, **hints)
      end

      def ==(other)
        other.is_a?(Node) && driver.equal?(other.driver) && native == other.native
      end
    end
  end
end

Capybara.register_driver(:domstride) { |app| Domstride::CapybaraAdapter::Driver.new(app) }
