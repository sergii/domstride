require_relative "../namespace"
require "cucumber/formatter/ast_lookup"
require_relative "lifecycle"
require_relative "capybara_assertions"

module Specdrive
  module Reporting
    module Cucumber
      class Listener
        def initialize(config, directory:, html:, step_text:)
          @directory, @html, @step_text = directory, html, step_text
          @lookup = ::Cucumber::Formatter::AstLookup.new(config)
          @item = nil
          config.on_event :test_case_started, &method(:case_started)
          config.on_event :test_case_finished, &method(:case_finished)
          config.on_event :test_step_started, &method(:step_started)
          config.on_event :test_step_finished, &method(:step_finished)
        end

        def case_started(event)
          @item = Lifecycle.start(directory: @directory, name: event.test_case.name,
            html: @html, framework: "cucumber")
        end

        def step_started(event)
          return unless @item && ReportCase.current.equal?(@item)
          step = event.test_step
          return if step.hook?
          keyword = @lookup.step_source(step)&.step&.keyword || "Step"
          Lifecycle.step_start(keyword: keyword, text: @step_text ? step.text : nil)
        rescue StandardError => error
          warn "Domstride Cucumber step unavailable: #{error.class}"
        end

        def step_finished(event)
          return unless @item && ReportCase.current.equal?(@item) && !event.test_step.hook?
          Lifecycle.step_finish(event.result.to_sym.to_s)
        end

        def case_finished(event)
          status = event.result.to_sym.to_s
          status = "failed" if %w[undefined ambiguous].include?(status)
          status = "unknown" unless ReportCase::STATUSES.include?(status)
          Lifecycle.finish(@item, status: status)
          @item = nil
        end
      end

      def self.install!(config, directory:, html: false, step_text: false)
        CapybaraAssertions.install!
        Listener.new(config, directory: File.expand_path(directory), html: html, step_text: step_text)
      end
    end
  end
end
