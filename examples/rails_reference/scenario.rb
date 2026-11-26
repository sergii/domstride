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
  end
end
