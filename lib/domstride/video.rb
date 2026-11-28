require_relative "namespace"
require "base64"
require_relative "consumer/video"

module Specdrive
  # Producer attachment API; the consumer owns bounded WebM reading.
  module Video
    MAX_BYTES = Consumer::Video::MAX_BYTES
    MAX_VIDEOS = Consumer::Video::MAX_VIDEOS
    MAGIC = Consumer::Video::MAGIC

    def self.attach(path, label: "Browser recording", cues: [], focus: [])
      item = ReportCase.current || raise(Error, "No active report case")
      source = File.expand_path(path)
      raise Error, "Invalid video file" unless File.file?(source) && !File.symlink?(source)
      name = String(label).encode("UTF-8")
      raise ArgumentError, "Invalid video label" if name.empty? || name.bytesize > 128
      raise Error, "Video attachment limit exceeded" if item.videos.size >= MAX_VIDEOS
      destination = format("video-%02d.webm", item.videos.size + 1)
      bytes = read_webm(source)
      File.open(File.join(item.path, destination), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(bytes) }
      item.videos << {file: destination, label: name, cues: cues, focus: focus}
      destination
    end

    def self.read_webm(path) = Consumer::Video.read_webm(path)
  end
end
