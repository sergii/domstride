require_relative "replay"

module Domstride
  module Report
    MAX_CASES = 100
    MAX_RECORDINGS = 200
    MAX_PAYLOAD_BYTES = 32 * 1024 * 1024

    def self.capture(**options, &block) = ReportCase.capture(**options, &block)

    def self.export(directory, output: nil)
      root = File.realpath(directory)
      paths = Dir.children(root).sort.select { |name| name.start_with?("domstride-case-") }
      raise Error, "Report case limit exceeded" if paths.size > MAX_CASES
      recordings = 0
      bytes = 0
      cases = paths.map do |name|
        path = File.join(root, name)
        raise Error, "Invalid case directory" unless File.directory?(path) && !File.symlink?(path)
        meta = File.join(path, "case.json")
        raise Error, "Invalid case metadata" unless File.file?(meta) && !File.symlink?(meta) && File.size(meta) <= 4096
        item = JSON.parse(File.read(meta))
        unless item.is_a?(Hash) && item["schema_version"] == 1 && item["name"].is_a?(String) &&
            item["name"].bytesize <= 1024 && ReportCase::STATUSES.include?(item["status"]) &&
            item["duration_ms"].is_a?(Numeric) && item["duration_ms"].finite? && item["duration_ms"] >= 0
          raise Error, "Invalid case metadata"
        end
        traces = Dir.children(path).sort.select { |entry| entry.start_with?("domstride-recording-") }.map do |entry|
          recordings += 1
          raise Error, "Report recording limit exceeded" if recordings > MAX_RECORDINGS
          trace_path = File.join(path, entry)
          raise Error, "Invalid recording directory" unless File.directory?(trace_path) && !File.symlink?(trace_path)
          trace = Replay.load_recording(trace_path)
          bytes += JSON.generate(trace).bytesize
          raise Error, "Report payload limit exceeded" if bytes > MAX_PAYLOAD_BYTES
          trace
        end
        {name: item["name"], status: item["status"], duration_ms: item["duration_ms"], recordings: traces}
      end
      Replay.render({cases: cases}, output || File.join(root, "report.html"))
    rescue JSON::ParserError => error
      raise Error, "Invalid report JSON: #{error.class}"
    end
  end
end
