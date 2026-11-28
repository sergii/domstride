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


    # Optional recording extension. Unknown or malformed identities are omitted.
    TARGET_TAGS = %w[input textarea select option button a label form div span other].freeze
    TARGET_INPUT_TYPES = %w[text password checkbox radio file hidden submit button reset email number search tel url date datetime-local time month week color range image other].freeze
    TARGET_HINTS = %w[id name native_label aria_label aria_labelledby role test_id].freeze

    def self.target_identity(value)
      return unless value.is_a?(Hash) && value.keys.sort == %w[basis hints input_type tag version]
      return unless value["version"] == 1 && %w[resolved_handle selector_match].include?(value["basis"])
      return unless TARGET_TAGS.include?(value["tag"])
      type = value["input_type"]
      return unless value["tag"] == "input" ? TARGET_INPUT_TYPES.include?(type) : type.nil?
      hints = value["hints"]
      return unless hints.is_a?(Hash) && hints.keys.sort == TARGET_HINTS.sort
      return unless TARGET_HINTS.all? do |key|
        hints[key] == true || hints[key] == false || (key == "native_label" && hints[key].nil?)
      end
      value
    end

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
