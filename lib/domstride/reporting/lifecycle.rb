require_relative "../report"

module Domstride
  module Reporting
    # Framework instrumentation must never replace the original test outcome.
    module Lifecycle
      def self.start(directory:, name:, html:, framework:)
        return if ReportCase.current
        item = ReportCase.new(directory: directory, name: name, html: html, framework: framework)
        Thread.current[ReportCase::KEY] = item
        item
      rescue StandardError => error
        warn "Domstride report case unavailable: #{error.class}"
        nil
      end

      def self.finish(item, status:, assertions: nil)
        return unless item
        item.status = status
        item.assertions = assertions
        item.finish
      rescue StandardError => error
        warn "Domstride report case unavailable: #{error.class}"
      ensure
        Thread.current[ReportCase::KEY] = nil if item && ReportCase.current.equal?(item)
      end
    end
  end
end
