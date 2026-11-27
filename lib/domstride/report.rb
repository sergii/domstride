require_relative "replay"
require_relative "video"

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
        raise Error, "Invalid case metadata" unless File.file?(meta) && !File.symlink?(meta) && File.size(meta) <= 256 * 1024
        item = JSON.parse(File.read(meta))
        unless item.is_a?(Hash) && item["schema_version"] == 1 && item["name"].is_a?(String) &&
            item["name"].bytesize <= 1024 && ReportCase::STATUSES.include?(item["status"]) &&
            item["duration_ms"].is_a?(Numeric) && item["duration_ms"].finite? && item["duration_ms"] >= 0
          raise Error, "Invalid case metadata"
        end
        steps = item.fetch("steps", [])
        unless steps.is_a?(Array) && steps.size <= ReportCase::MAX_STEPS && steps.each_with_index.all? { |step, index|
          step.is_a?(Hash) && step["sequence"] == index + 1 && step["keyword"].is_a?(String) && step["keyword"].bytesize <= 64 &&
            (step["text"].nil? || (step["text"].is_a?(String) && step["text"].bytesize <= 1030)) &&
            ReportCase::STEP_STATUSES.include?(step["status"]) && step["duration_ms"].is_a?(Numeric) && step["duration_ms"].finite? && step["duration_ms"] >= 0
        }
          raise Error, "Invalid case steps"
        end
        assertions = item.fetch("assertion_events", [])
        unless assertions.is_a?(Array) && assertions.size <= ReportCase::MAX_ASSERTIONS && assertions.each_with_index.all? { |assertion, index|
          assertion.is_a?(Hash) && assertion["sequence"] == index + 1 && assertion["kind"].is_a?(String) && assertion["kind"].bytesize <= 100 &&
            ReportCase::ASSERTION_STATUSES.include?(assertion["status"]) && assertion["duration_ms"].is_a?(Numeric) && assertion["duration_ms"].finite? && assertion["duration_ms"] >= 0 &&
            (assertion["step_sequence"].nil? || steps.any? { |step| step["sequence"] == assertion["step_sequence"] })
        }
          raise Error, "Invalid assertion events"
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
        attachments = item.fetch("videos", [])
        raise Error, "Invalid video attachments" unless attachments.is_a?(Array) && attachments.size <= Video::MAX_VIDEOS
        videos = attachments.each_with_index.map do |attachment, index|
          name = format("video-%02d.webm", index + 1)
          unless attachment.is_a?(Hash) && attachment["file"] == name && attachment["label"].is_a?(String) && attachment["label"].bytesize.between?(1,128)
            raise Error, "Invalid video attachment"
          end
          content = Video.read_webm(File.join(path, name))
          encoded = Base64.strict_encode64(content)
          bytes += encoded.bytesize
          raise Error, "Report payload limit exceeded" if bytes > MAX_PAYLOAD_BYTES
          {label: attachment["label"], base64: encoded}
        end
        {name: item["name"], status: item["status"], duration_ms: item["duration_ms"],
          framework: %w[rspec minitest cucumber turnip].include?(item["framework"]) ? item["framework"] : nil,
          assertions: item["assertions"].is_a?(Integer) && item["assertions"] >= 0 ? item["assertions"] : nil,
          recordings: traces, steps: steps, assertion_events: assertions, videos: videos}
      end
      Replay.render({cases: cases}, output || File.join(root, "report.html"))
    rescue JSON::ParserError => error
      raise Error, "Invalid report JSON: #{error.class}"
    end
  end
end
