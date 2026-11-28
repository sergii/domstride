require_relative "../specdrive"
require_relative "../domstride/capybara"

# Register an additional public name without changing the existing driver.
Capybara.register_driver(:specdrive) { |app| Specdrive::CapybaraAdapter::Driver.new(app) }
