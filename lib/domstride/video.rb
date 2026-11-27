require "base64"

module Domstride
  # A bounded, explicit local evidence attachment, not a browser driver.
  module Video
    MAX_BYTES = 8 * 1024 * 1024
    MAX_VIDEOS = 4
    MAGIC = "\x1a\x45\xdf\xa3".b.freeze

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

    def self.read_webm(path)
      raise Error, "Invalid video file" unless File.file?(path) && !File.symlink?(path)
      raise Error, "Video byte limit exceeded" if File.size(path) > MAX_BYTES
      bytes = File.binread(path, MAX_BYTES + 1)
      raise Error, "Video byte limit exceeded" if bytes.bytesize > MAX_BYTES
      # Require EBML magic and a WebM DocType in the bounded header.
      # This is not a full media decoder or validation of every frame.
      raise Error, "Expected WebM video" unless bytes.start_with?(MAGIC) && bytes.byteslice(0, 256).include?("\x42\x82\x84webm".b)
      bytes
    end
  end
end
