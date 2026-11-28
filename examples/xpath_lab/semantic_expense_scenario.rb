require_relative "../rails_reference/application"
require "specdrive/capybara"

module SemanticExpenseScenario
  def self.run(page)
    page.visit("/")
    page.find(:css, "h1", exact_text: "Expense Lab")
    page.find(:css, "#expense[data-ready=true] #total", exact_text: "0")
    page.find(:css, "#add").click
    page.find(:css, "#total", exact_text: "25")
    page.find(:css, "#details-link").click
    page.find(:css, "#receipt", exact_text: "Receipt #42")
    page.find(:css, "#approve-link").click
    page.find(:css, "#status", exact_text: "Approved")
    page.fill_in("Email", with: "tester@example.test", exact: true)
    page.fill_in("Password", with: "fixture-password", exact: true)
    page.click_button("Sign in", exact: true)
    page.find(:css, "#identity", exact_text: "Signed in")
    page.fill_in("Description", with: "Lunch", exact: true)
    page.fill_in("Amount", with: "0", exact: true)
    page.click_button("Save expense", exact: true)
    page.find(:css, "#result", exact_text: "Invalid expense")
    page.fill_in("Amount", with: "25", exact: true)
    page.click_button("Save expense", exact: true)
    page.find(:css, "#result", exact_text: "Saved")
    page.visit("/")
    page.find(:css, "#identity", exact_text: "Signed in")
    page.find(:css, "#latest-link").click
    page.find(:css, "#persisted", exact_text: "Lunch: 25")
  end
end
