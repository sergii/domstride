ENV["RAILS_ENV"] = "test"
require_relative "application"
require "rails/test_help"
require "action_dispatch/system_test_case"
require_relative "../../lib/domstride/rails"
require_relative "../../lib/generators/domstride/install_generator"
require_relative "capybara_scenario"

if ENV["DOMSTRIDE_DRIVER"] == "browser"
  require "capybara/cuprite"
  Capybara.server = :puma, { Silent: true }
  Capybara.register_driver(:domstride_reference_browser) do |app|
    Capybara::Cuprite::Driver.new(app, browser_path: ENV.fetch("CHROME_PATH"), headless: true,
      timeout: 5, process_timeout: 30, browser_options: { "no-sandbox" => nil, "disable-dev-shm-usage" => nil })
  end
end

directory = Dir.mktmpdir("domstride-generator")
at_exit { FileUtils.remove_entry(directory) if File.directory?(directory) }
Domstride::Generators::InstallGenerator.new([], {}, {destination_root: directory}).invoke_all
File.write(File.join(directory, "test/test_helper.rb"), "# Fixture application is initialized above\n")
$LOAD_PATH.unshift(File.join(directory, "test"))
require File.join(directory, "test/domstride_system_test_case.rb")

class GeneratedSystemTest < DomstrideSystemTestCase
  test "runs identical system scenario with explicit driver choice" do
    expected = ENV["DOMSTRIDE_DRIVER"] == "browser" ? :domstride_reference_browser : :domstride
    assert_equal expected, Capybara.current_driver
    assert_equal(expected != :domstride, page.driver.needs_server?)
    assert_difference -> { ExpenseReference::Expense.count }, 1 do
      CapybaraExpenseScenario.run(page)
    end
    assert_selector "#persisted", exact_text: "Lunch: 25"
  end
end
