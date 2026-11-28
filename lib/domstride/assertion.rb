require_relative "namespace"
module Specdrive
  # One outermost assertion boundary, not a guess based on operation status.
  module Assertion
    def self.capture(kind, failure_classes: [])
      report = ReportCase.current
      return yield unless report && !report.active_assertion
      item = begin
        report.begin_assertion(kind)
      rescue StandardError => error
        warn "Domstride assertion report unavailable: #{error.class}"
        nil
      end
      return yield unless item
      status = "unknown"
      begin
        value = yield
        status = item[:status] == "failed" ? "failed" : "passed"
        value
      rescue Exception => error
        status = failure_classes.any? { |klass| error.is_a?(klass) } ? "failed" : "error"
        raise
      ensure
        begin
          report.end_assertion(item, status)
        rescue StandardError => error
          warn "Domstride assertion report unavailable: #{error.class}"
        end
      end
    end

    def self.mark_failed
      item = ReportCase.current&.active_assertion
      item[:status] = "failed" if item
    end
  end
end
