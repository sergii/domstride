require_relative "application"
require_relative "../../lib/domstride/capybara"

module CapybaraExpenseScenario
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
    page.find(:css, "#email").set("tester@example.test")
    page.find(:css, "#password").set("fixture-password")
    page.find(:css, "#login").click
    page.find(:css, "#identity", exact_text: "Signed in")
    page.find(:css, "#description").set("Lunch")
    page.find(:css, "#amount").set("0")
    page.find(:css, "#save").click
    page.find(:css, "#result", exact_text: "Invalid expense")
    page.find(:css, "#amount").set("25")
    page.find(:css, "#save").click
    page.find(:css, "#result", exact_text: "Saved")
    page.visit("/")
    page.find(:css, "#identity", exact_text: "Signed in")
    page.find(:css, "#latest-link").click
    page.find(:css, "#persisted", exact_text: "Lunch: 25")
  end
end
