require_relative "../report"
require_relative "../browser_video"

module Domstride
  module Reporting
    # Framework instrumentation must never replace the original test outcome.
    module Lifecycle
      def self.start(directory:, name:, html:, framework:)
        return if ReportCase.current
        item = ReportCase.new(directory: directory, name: name, html: html, framework: framework)
        Thread.current[ReportCase::KEY] = item
        begin
          item.browser_video = BrowserVideo.start(item)
        rescue StandardError => error
          warn "Domstride browser video unavailable: #{error.class}"
        end
        item
      rescue StandardError => error
        warn "Domstride report case unavailable: #{error.class}"
        nil
      end

      def self.step_start(keyword:, text: nil)
        ReportCase.current&.start_step(keyword: keyword, text: text)
      rescue StandardError => error
        warn "Domstride step report unavailable: #{error.class}"
      end

      def self.step_finish(status)
        ReportCase.current&.finish_step(status)
      rescue StandardError => error
        warn "Domstride step report unavailable: #{error.class}"
      end

      def self.finish(item, status:, assertions: nil)
        return unless item
        item.status = status
        item.assertions = assertions
        begin
          item.browser_video&.finish(status: status)
        rescue StandardError => error
          warn "Domstride browser video unavailable: #{error.class}"
        end
        item.finish
      rescue StandardError => error
        warn "Domstride report case unavailable: #{error.class}"
      ensure
        Thread.current[ReportCase::KEY] = nil if item && ReportCase.current.equal?(item)
      end
    end
  end
end
