require "rspec/expectations"
require "rspec/expectations/handler"
require_relative "../assertion"

module Domstride
  module Reporting
    module RSpecAssertions
      KEY = :domstride_rspec_assertion_owner

      def self.observe(kind)
        previous = Thread.current[KEY]
        outer = ReportCase.current&.active_assertion
        Assertion.capture(kind, failure_classes: [::RSpec::Expectations::ExpectationNotMetError]) do
          active = ReportCase.current&.active_assertion
          # Only the handler owning the outer assertion can mark its result.
          # A nested expectation may fail intentionally inside raise_error.
          Thread.current[KEY] = active && !active.equal?(outer) ? active : nil
          yield
        ensure
          Thread.current[KEY] = previous
        end
      end

      module Positive
        def handle_matcher(actual, matcher, message = nil, &block)
          return super unless matcher
          RSpecAssertions.observe("rspec.expect") { super(actual, matcher, message, &block) }
        end
      end

      module Negative
        def handle_matcher(actual, matcher, message = nil, &block)
          return super unless matcher
          RSpecAssertions.observe("rspec.expect_not") { super(actual, matcher, message, &block) }
        end
      end

      module Failure
        def handle_failure(*args, **kwargs, &block)
          # Aggregated expectations may return a truthy sentinel instead of raising.
          owner = Thread.current[KEY]
          Assertion.mark_failed if owner && owner.equal?(ReportCase.current&.active_assertion)
          super
        end
      end

      def self.install!
        ::RSpec::Expectations::PositiveExpectationHandler.singleton_class.prepend(Positive)
        ::RSpec::Expectations::NegativeExpectationHandler.singleton_class.prepend(Negative)
        ::RSpec::Expectations::ExpectationHelper.singleton_class.prepend(Failure)
      end
    end
  end
end
