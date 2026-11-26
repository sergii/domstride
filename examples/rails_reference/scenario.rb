require_relative "../../lib/domstride"
require_relative "application"

module ExpenseScenario
  def self.run(page)
    page.visit("/")
    page.wait_for_text("h1", "Expense Lab")
    # Wait for the actual Stimulus controller connection.
    page.wait_for_text("#expense[data-ready=true] #total", "0")
    page.click("#add")
    page.wait_for_text("#total", "25")
    page.click("#details-link")
    page.wait_for_text("#receipt", "Receipt #42")
    page.click("#approve-link")
    page.wait_for_text("#status", "Approved")
    page.fill("#email", "tester@example.test")
    page.fill("#password", "fixture-password")
    page.click("#login")
    page.wait_for_text("#identity", "Signed in")
    page.fill("#description", "Lunch")
    page.fill("#amount", "0")
    page.click("#save")
    page.wait_for_text("#result", "Invalid expense")
    page.fill("#amount", "25")
    page.click("#save")
    page.wait_for_text("#result", "Saved")
    page.visit("/")
    page.wait_for_text("#identity", "Signed in")
    page.click("#latest-link")
    page.wait_for_text("#persisted", "Lunch: 25")
  end
end
