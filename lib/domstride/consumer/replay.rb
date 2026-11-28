require "json"
require "securerandom"
require_relative "../errors"
require_relative "../protocol"

module Domstride
  module Consumer
    module Replay
      # Export a single local recording; never run application HTML or requests.
      def self.load_recording(directory)
        root = File.realpath(directory)
        events_path = File.join(root, "events.jsonl")
        raise Error, "Invalid recording metadata" unless File.file?(events_path) && !File.symlink?(events_path) && File.size(events_path) <= 2 * 1024 * 1024
        rows = File.readlines(events_path).map { |line| JSON.parse(line) }
        header = rows.first
        raise Error, "Unsupported recording schema" unless header.is_a?(Hash) && header["type"] == "header" && header["schema_version"] == 1
        events = rows.select { |row| row.is_a?(Hash) && row["type"] == "interaction" }
        raise Error, "Recording event limit exceeded" if events.size > Protocol::MAX_EVENTS
        total = 0
        events.each do |event|
          sequence = event["sequence"]
          raise Error, "Invalid event sequence" unless sequence.is_a?(Integer) && sequence.positive?
          %w[before after].each do |phase|
            frame = event[phase]
            next unless frame.is_a?(Hash) && frame["snapshot"]
            name = format("%06d-%s.html", sequence, phase)
            raise Error, "Invalid snapshot reference" unless frame["snapshot"] == name
            path = File.join(root, name)
            raise Error, "Invalid snapshot file" unless File.file?(path) && !File.symlink?(path) && File.size(path) <= 256 * 1024
            total += File.size(path)
            raise Error, "Recording HTML limit exceeded" if total > Protocol::MAX_HTML_BYTES
            frame["html"] = File.read(path, encoding: "UTF-8")
          end
        end
        { events: events, complete: rows.last.is_a?(Hash) && rows.last["type"] == "footer", html_bytes: total, engine: header["engine"], runtime: header["runtime"] }
      rescue JSON::ParserError => error
        raise Error, "Invalid recording JSON: #{error.class}"
      end

      def self.export(directory, output: nil)
        root = File.realpath(directory)
        render(load_recording(root), output || File.join(root, "replay.html"))
      end

      def self.render(data, output)
        payload = JSON.generate(data)
           .gsub(/[<>&]/) { |character| format('\\u%04x', character.ord) }
        nonce = SecureRandom.hex(16)
        template = File.read(File.join(__dir__, "../replay.html"))
        html = template.gsub("__NONCE__", nonce).sub("__RECORDING_JSON__") { payload }
        destination = File.expand_path(output)
        File.open(destination, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(html) }
        destination
      rescue JSON::ParserError => error
        raise Error, "Invalid recording JSON: #{error.class}"
      end
    end
  end
end
