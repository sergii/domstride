require "rspec/core"
require_relative "lifecycle"
require_relative "rspec_assertions"
require_relative "capybara_assertions"

module Domstride
  module Reporting
    module RSpec
      # Reporter notifications include skipped examples and failures in hooks,
      # and arrive after RSpec has calculated the final result.
      class Listener
        def initialize(directory:, html:, step_text:)
          @directory, @html, @step_text = directory, html, step_text
          @cases = {}
          @lock = Mutex.new
        end

        def example_started(notification)
          example = notification.example
          item = Lifecycle.start(directory: @directory, name: example.full_description,
            html: @html, framework: example.metadata[:turnip] ? "turnip" : "rspec")
          @lock.synchronize { @cases[example.id] = item } if item
        end

        def step_started(notification)
          step = notification.step
          Lifecycle.step_start(keyword: step.keyword, text: @step_text ? step.text : nil)
        end

        def step_passed(_notification) = Lifecycle.step_finish("passed")
        def step_failed(_notification) = Lifecycle.step_finish("failed")
        def step_pending(_notification) = Lifecycle.step_finish("pending")

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

      def self.install!(config = ::RSpec.configuration, directory:, html: false, step_text: false)
        raise ArgumentError, "RSpec report already installed" if config.instance_variable_defined?(:@domstride_reporting_installed)
        RSpecAssertions.install!
        CapybaraAssertions.install!
        listener = Listener.new(directory: File.expand_path(directory), html: html, step_text: step_text)
        config.before(:suite) do
          config.reporter.register_listener(listener, :example_started, :example_finished, :step_started, :step_passed, :step_failed, :step_pending)
        end
        config.instance_variable_set(:@domstride_reporting_installed, true)
        listener
      end
    end
  end
end
