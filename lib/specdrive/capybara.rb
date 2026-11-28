require_relative "../specdrive"
require_relative "../domstride/capybara"

# Register an additional public name without changing the existing driver.
Capybara.register_driver(:specdrive) { |app| SpecDrive::CapybaraAdapter::Driver.new(app) }
