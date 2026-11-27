require "capybara"
require_relative "../assertion"

module Domstride
  module Reporting
    module CapybaraAssertions
      METHODS = %i[assert_selector assert_no_selector assert_text assert_no_text
        assert_matches_selector assert_not_matches_selector assert_all_of_selectors
        assert_none_of_selectors assert_any_of_selectors assert_ancestor assert_no_ancestor
        assert_sibling assert_no_sibling].freeze

      METHODS.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          Assertion.capture("capybara.#{name}", failure_classes: [::Capybara::ExpectationNotMet]) do
            super(*args, **kwargs, &block)
          end
        end
      end

      def self.install!
        ::Capybara::Node::Matchers.prepend(self) unless ::Capybara::Node::Matchers.ancestors.include?(self)
      end
    end
  end
end
