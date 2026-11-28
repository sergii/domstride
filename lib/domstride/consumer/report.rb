require_relative "../errors"
require_relative "../protocol"
require_relative "replay"
require_relative "video"
require "base64"

module Domstride
  module Consumer
    module Report
    MAX_CASES = 100
    MAX_RECORDINGS = 200
    MAX_PAYLOAD_BYTES = 32 * 1024 * 1024

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
        unless item.is_a?(Hash) && item["schema_version"] == Protocol::VERSION && (!item.key?("format") || item["format"] == Protocol::FORMAT) && item["name"].is_a?(String) &&
            item["name"].bytesize.between?(1,1024) && Protocol::CASE_STATUSES.include?(item["status"]) &&
            item["duration_ms"].is_a?(Numeric) && item["duration_ms"].finite? && item["duration_ms"] >= 0
          raise Error, "Invalid case metadata"
        end
        metadata = Protocol.metadata(item)
        steps = item.fetch("steps", [])
        unless steps.is_a?(Array) && steps.size <= Protocol::MAX_STEPS && steps.each_with_index.all? { |step, index|
          step.is_a?(Hash) && step["sequence"] == index + 1 && step["keyword"].is_a?(String) && step["keyword"].bytesize <= 64 &&
            (step["text"].nil? || (step["text"].is_a?(String) && step["text"].bytesize <= 1030)) &&
            Protocol::STEP_STATUSES.include?(step["status"]) && step["duration_ms"].is_a?(Numeric) && step["duration_ms"].finite? && step["duration_ms"] >= 0
        }
          raise Error, "Invalid case steps"
        end
        assertions = item.fetch("assertion_events", [])
        unless assertions.is_a?(Array) && assertions.size <= Protocol::MAX_ASSERTIONS && assertions.each_with_index.all? { |assertion, index|
          assertion.is_a?(Hash) && assertion["sequence"] == index + 1 && assertion["kind"].is_a?(String) && assertion["kind"].bytesize <= 100 &&
            Protocol::ASSERTION_STATUSES.include?(assertion["status"]) && assertion["duration_ms"].is_a?(Numeric) && assertion["duration_ms"].finite? && assertion["duration_ms"] >= 0 &&
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
          cues = attachment.fetch("cues", [])
          unless cues.is_a?(Array) && cues.size <= Protocol::MAX_STEPS + Protocol::MAX_ASSERTIONS &&
              cues.all? { |cue| cue.is_a?(Hash) && %w[step assertion].include?(cue["kind"]) &&
                cue["sequence"].is_a?(Integer) && cue["time_ms"].is_a?(Numeric) && cue["time_ms"].finite? &&
                cue["time_ms"].between?(0, 86_400_000) &&
                (cue["kind"] == "step" ? steps : assertions).any? { |row| row["sequence"] == cue["sequence"] } } &&
              cues.map { |cue| cue.values_at("kind","sequence") }.uniq.size == cues.size
            raise Error, "Invalid video cues"
          end
          focus = attachment.fetch("focus", [])
          unless focus.is_a?(Array) && focus.size <= 300 && focus.each_with_index.all? { |segment, i|
            segment.is_a?(Hash) && %w[fill click select assert].include?(segment["kind"]) &&
              %w[start_ms end_ms].all? { |key| segment[key].is_a?(Numeric) && segment[key].finite? && segment[key].between?(0, 86_400_000) } &&
              segment["start_ms"] < segment["end_ms"] &&
              (i.zero? || focus[i-1]["end_ms"] <= segment["start_ms"]) &&
              %w[x y width height].all? { |key| segment[key].is_a?(Numeric) && segment[key].finite? && segment[key].between?(0,1) } &&
              segment["width"].positive? && segment["height"].positive? &&
              segment["x"] + segment["width"] <= 1.000000001 && segment["y"] + segment["height"] <= 1.000000001 &&
              %w[passed failed unknown].include?(segment["status"])
          }
            raise Error, "Invalid video focus segments"
          end
          quality = attachment["timing_quality"]
          if attachment.key?("timing_quality")
            unless quality == "visual_candidates_unvalidated" && cues.empty? && focus.all? { |segment|
              segment["step_sequence"].is_a?(Integer) && steps.any? { |step| step["sequence"] == segment["step_sequence"] } &&
                segment["label"].is_a?(String) && segment["label"].bytesize.between?(1,128) &&
                (!segment.key?("transition") || (segment["transition"] == "navigation" && segment["kind"] == "click")) &&
                (!segment.key?("element") || (segment["element"].is_a?(Hash) && segment["element"].key?("tag") &&
                  segment["element"].all? { |key,value| %w[tag id name test_id type label].include?(key) && value.is_a?(String) && value.bytesize.between?(1,128) } &&
                  !%w[password hidden file].include?(segment["element"]["type"].to_s.downcase)))
            }
              raise Error, "Invalid observed video focus"
            end
          end
          step_intervals = attachment.fetch("step_intervals", [])
          step_quality = attachment["step_timing_quality"]
          if attachment.key?("step_intervals") || attachment.key?("step_timing_quality")
            unless quality == "visual_candidates_unvalidated" && step_quality == "visual_landmarks" &&
              step_intervals.is_a?(Array) && step_intervals.size.between?(1, Protocol::MAX_STEPS) &&
              step_intervals.each_with_index.all? { |interval, i|
                interval.is_a?(Hash) && interval["step_sequence"].is_a?(Integer) && steps.any? { |s| s["sequence"] == interval["step_sequence"] } &&
                %w[start_ms end_ms].all? { |key| interval[key].is_a?(Numeric) && interval[key].finite? && interval[key].between?(0,86_400_000) } &&
                interval["start_ms"] < interval["end_ms"] &&
                (i.zero? || (step_intervals[i-1]["end_ms"] <= interval["start_ms"] && step_intervals[i-1]["step_sequence"] < interval["step_sequence"]))
              } && focus.all? { |segment| step_intervals.any? { |interval| interval["step_sequence"] == segment["step_sequence"] && interval["start_ms"] <= segment["start_ms"] && interval["end_ms"] >= segment["end_ms"] } }
              raise Error, "Invalid recorded step intervals"
            end
          end
          content = Video.read_webm(File.join(path, name))
          encoded = Base64.strict_encode64(content)
          bytes += encoded.bytesize
          raise Error, "Report payload limit exceeded" if bytes > MAX_PAYLOAD_BYTES
          {label: attachment["label"], base64: encoded, cues: cues.map { |cue| cue.slice("kind","sequence","time_ms") },
            timing_quality: quality, step_timing_quality: step_quality, step_intervals: step_intervals.map { |interval| interval.slice("step_sequence","start_ms","end_ms") }, focus: focus.map { |segment| segment.slice("kind","status","start_ms","end_ms","x","y","width","height", *(quality ? %w[step_sequence label transition element] : [])) }}
        end
        {name: item["name"], status: item["status"], duration_ms: item["duration_ms"],
          **metadata,
          assertions: item["assertions"].is_a?(Integer) && item["assertions"] >= 0 ? item["assertions"] : nil,
          recordings: traces, steps: steps, assertion_events: assertions, videos: videos}
      end
      Replay.render({cases: cases}, output || File.join(root, "report.html"))
    rescue JSON::ParserError => error
      raise Error, "Invalid report JSON: #{error.class}"
    end
    end
  end
end
