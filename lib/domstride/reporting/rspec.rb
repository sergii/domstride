require "rspec/core"
require_relative "lifecycle"

module Domstride
  module Reporting
    module RSpec
      # Reporter notifications include skipped examples and failures in hooks,
      # and arrive after RSpec has calculated the final result.
      class Listener
        def initialize(directory:, html:)
          @directory, @html = directory, html
          @cases = {}
          @lock = Mutex.new
        end

        def example_started(notification)
          example = notification.example
          item = Lifecycle.start(directory: @directory, name: example.full_description,
            html: @html, framework: "rspec")
          @lock.synchronize { @cases[example.id] = item } if item
        end

        def example_finished(notification)
          example = notification.example
          item = @lock.synchronize { @cases.delete(example.id) }
          result = example.execution_result
          status = case result.status
          when :passed then "passed"
          when :failed then "failed"
          when :pending then result.example_skipped? ? "skipped" : "pending"
          else "unknown"
          end
          Lifecycle.finish(item, status: status)
        end
      end

      def self.install!(config = ::RSpec.configuration, directory:, html: false)
        raise ArgumentError, "RSpec report already installed" if config.instance_variable_defined?(:@domstride_reporting_installed)
        listener = Listener.new(directory: File.expand_path(directory), html: html)
        config.before(:suite) do
          config.reporter.register_listener(listener, :example_started, :example_finished)
        end
        config.instance_variable_set(:@domstride_reporting_installed, true)
        listener
      end
    end
  end
end
