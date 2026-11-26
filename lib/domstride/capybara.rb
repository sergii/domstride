require "capybara"
require_relative "../domstride"

module Domstride
  module CapybaraAdapter
    class StaleElement < Domstride::Error; end

    class Driver < ::Capybara::Driver::Base
      def initialize(app, runtime: ENV.fetch("DOMSTRIDE_RUNTIME", "node"), engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"))
        @app, @runtime, @engine = app, runtime, engine
      end

      def worker
        @worker ||= Domstride::Session.new(app: @app, runtime: @runtime, engine: @engine)
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

      def find_css(query, **)
        find_nodes("css", query)
      end

      def find_xpath(query, **)
        find_nodes("xpath", query)
      end

      def find_nodes(kind, query, root: nil)
        command("find_handles", kind_of_query: kind, query: query, root: root).map { |id| Node.new(self, id) }
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
        raise ::Capybara::NotSupportedByDriverError, "Click modifiers or coordinates" unless keys.empty? && options.empty?
        operation("click")
      end

      def find_css(query, **)
        driver.find_nodes("css", query, root: native)
      end

      def find_xpath(query, **)
        driver.find_nodes("xpath", query, root: native)
      end

      def ==(other)
        other.is_a?(Node) && driver.equal?(other.driver) && native == other.native
      end
    end
  end
end

Capybara.register_driver(:domstride) { |app| Domstride::CapybaraAdapter::Driver.new(app) }
