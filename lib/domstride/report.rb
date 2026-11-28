require_relative "namespace"
require_relative "consumer/report"
require_relative "report_case"
require_relative "replay"
require_relative "video"

module Specdrive
  # Compatibility API for existing producers and local report callers.
  module Report
    MAX_CASES = Consumer::Report::MAX_CASES
    MAX_RECORDINGS = Consumer::Report::MAX_RECORDINGS
    MAX_PAYLOAD_BYTES = Consumer::Report::MAX_PAYLOAD_BYTES

    def self.capture(**options, &block) = ReportCase.capture(**options, &block)
    def self.export(directory, output: nil) = Consumer::Report.export(directory, output: output)
  end
end
