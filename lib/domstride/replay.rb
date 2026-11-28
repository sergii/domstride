require_relative "namespace"
require_relative "consumer/replay"

module Specdrive
  # Compatibility API. Rendering and reading live in the artifact-only consumer.
  module Replay
    def self.load_recording(directory) = Consumer::Replay.load_recording(directory)
    def self.export(directory, output: nil) = Consumer::Replay.export(directory, output: output)
    def self.render(data, output) = Consumer::Replay.render(data, output)
  end
end
