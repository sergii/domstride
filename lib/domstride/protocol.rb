require_relative "namespace"
module Specdrive
  # Shared artifact contract. No execution-engine dependencies.
  module Protocol
    FORMAT = "domstride.case".freeze
    VERSION = 1
    CASE_STATUSES = %w[passed failed skipped pending unknown].freeze
    MAX_STEPS = 100
    MAX_ASSERTIONS = 200
    STEP_STATUSES = %w[passed failed skipped pending unknown undefined ambiguous].freeze
    ASSERTION_STATUSES = %w[passed failed error unknown].freeze
    MAX_EVENTS = 1000
    MAX_HTML_BYTES = 16 * 1024 * 1024
    METADATA_KEYS = %w[producer framework runner platform language].freeze

    def self.metadata(item)
      METADATA_KEYS.to_h do |key|
        value = item[key]
        unless value.nil? || (value.is_a?(String) && value.valid_encoding? && value.bytesize.between?(1,128))
          raise Error, "Invalid case #{key}"
        end
        [key.to_sym, value]
      end
    end
  end
end
