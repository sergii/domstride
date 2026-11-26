require_relative "capybara"

module Domstride
  # Include in ActionDispatch::SystemTestCase subclasses using Domstride.
  # There is no rendered screenshot; preserve the original test failure.
  module RailsSystemTestSupport
    def take_failed_screenshot
      return super unless page.driver.is_a?(Domstride::CapybaraAdapter::Driver)
    end
  end
end
