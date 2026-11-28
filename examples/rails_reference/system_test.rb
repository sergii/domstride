ENV["RAILS_ENV"] = "test"
require_relative "application"
require "rails/test_help"
require "action_dispatch/system_test_case"
require_relative "../../lib/domstride/rails"
require_relative "capybara_scenario"

class DomstrideSystemTest < ActionDispatch::SystemTestCase
  include Domstride::RailsSystemTestSupport
  driven_by :domstride

  test "runs the stateful fixture as a Rails system test" do
    assert_not page.driver.needs_server?
    assert_difference -> { ExpenseReference::Expense.count }, 1 do
      CapybaraExpenseScenario.run(page)
    end
    assert_selector "#persisted", exact_text: "Lunch: 25"
  end

  test "uses Rails assertions and normal field locators" do
    visit "/"
    assert_selector "#identity", text: "Anonymous"
    fill_in "Email", with: "tester@example.test"
    fill_in "Password", with: "fixture-password"
    click_button "Sign in"
    assert_selector "#identity", text: "Signed in"
  end

  test "starts with a clean session" do
    visit "/"
    assert_selector "#identity", exact_text: "Anonymous"
  end

  test "rejects deterministic profile for Capybara virtual retries" do
    assert_raises(ArgumentError) do
      Domstride::CapybaraAdapter::Driver.new(Rails.application, performance_profile: :deterministic, clock: "virtual")
    end
  end
end
