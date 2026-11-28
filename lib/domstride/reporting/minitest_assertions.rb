require_relative "../namespace"
require "minitest/assertions"
require_relative "../assertion"

module Specdrive
  module Reporting
    module MinitestAssertions
      # Deliberately bounded public method list. Nested primitive asserts are
      # folded into the outer call; this is not the framework assertion count.
      METHODS = %i[assert refute assert_equal refute_equal assert_nil refute_nil
        assert_empty refute_empty assert_includes refute_includes assert_match refute_match
        assert_same refute_same assert_raises assert_respond_to assert_kind_of assert_instance_of
        assert_operator refute_operator assert_predicate refute_predicate assert_in_delta refute_in_delta
        assert_in_epsilon refute_in_epsilon flunk].freeze

      METHODS.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          Assertion.capture("minitest.#{name}", failure_classes: [::Minitest::Assertion]) do
            super(*args, **kwargs, &block)
          end
        end
      end

      def self.install!
        ::Minitest::Assertions.prepend(self) unless ::Minitest::Assertions.ancestors.include?(self)
      end
    end
  end
end
