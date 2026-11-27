require_relative "rails"

module Domstride
  module BDD
    # An explicit session per scenario; no global Capybara driver changes.
    class Scenario
      STEP_KINDS = %i[visit click fill assert custom].freeze

      attr_reader :page

      def initialize(app:, driver: RailsSupport.driver_name, on_event: nil)
        @page = Capybara::Session.new(driver, app)
        @on_event = on_event
        @sequence = 0
        @closed = false
      end

      # Metadata only: no step text, selector, field values or HTML by default.
      def step(kind: :custom)
        raise Domstride::Error, "Scenario is closed" if @closed
        raise ArgumentError, "Unknown step kind" unless STEP_KINDS.include?(kind)
        @sequence += 1
        sequence = @sequence
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        passed = false
        driver = page.driver
        driver.recording_step = sequence if driver.is_a?(CapybaraAdapter::Driver)
        emit(type: "step_started", sequence: sequence, kind: kind.to_s)
        result = yield page
        passed = true
        result
      ensure
        if started
          driver.recording_step = nil if driver.is_a?(CapybaraAdapter::Driver)
          emit(type: "step_finished", sequence: sequence, kind: kind.to_s,
               status: passed ? "passed" : "failed",
               duration_ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000)
        end
      end

      def close(failed: false)
        return if @closed
        @closed = true
        begin
          if failed && page.driver.is_a?(CapybaraAdapter::Driver) && !ENV["DOMSTRIDE_FAILURE_DIR"].to_s.empty?
            path = RailsSupport.save_failure(page.driver, directory: ENV.fetch("DOMSTRIDE_FAILURE_DIR"),
              include_html: ENV["DOMSTRIDE_FAILURE_HTML"] == "1")
            warn "Domstride failure diagnostics: #{path}"
          end
        rescue StandardError => error
          warn "Domstride failure diagnostics unavailable: #{error.class}"
        ensure
          page.driver.quit
        end
      end

      private

      def emit(event)
        @on_event&.call(event.freeze)
      rescue StandardError => error
        # A telemetry consumer must not change scenario results.
        warn "Domstride scenario observer failed: #{error.class}"
      end
    end

    module World
      def start_domstride_scenario(**options)
        raise Domstride::Error, "Scenario already started" if @domstride_scenario
        @domstride_scenario = Scenario.new(**options)
      end

      def domstride_page
        raise Domstride::Error, "No active scenario" unless @domstride_scenario
        @domstride_scenario.page
      end

      def domstride_step(kind: :custom, &block)
        raise Domstride::Error, "No active scenario" unless @domstride_scenario
        @domstride_scenario.step(kind: kind, &block)
      end

      def finish_domstride_scenario(failed: false)
        scenario, @domstride_scenario = @domstride_scenario, nil
        scenario&.close(failed: failed)
      end
    end
  end
end
