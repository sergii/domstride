require_relative "../namespace"
require_relative "../errors"

module Specdrive
  module Consumer
    module Video
      MAX_BYTES = 8 * 1024 * 1024
      MAX_VIDEOS = 4
      MAGIC = "\x1a\x45\xdf\xa3".b.freeze

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
end
