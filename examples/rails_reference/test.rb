require "minitest/autorun"
require_relative "scenario"

class RailsReferenceTest < Minitest::Test
  def test_full_interaction
    Domstride::Session.open(app: Rails.application) do |page|
      assert_difference_in_expenses { assert ExpenseScenario.run(page) }
    end
  end

  def test_remount
    Domstride::Session.open(app: Rails.application) do |page|
      2.times { assert ExpenseScenario.run(page) }
    end
  end
  def test_stimulus_action_error_is_raised
    Domstride::Session.open(app: Rails.application) do |page|
      page.visit("/")
      page.wait_for_text("#expense[data-ready=true] #total", "0")
      error = assert_raises(Domstride::JavaScriptError) { page.click("#fail") }
      assert_includes error.message, "Stimulus action failure"
    end
  end

  def test_session_isolation
    Domstride::Session.open(app: Rails.application) do |page|
      ExpenseScenario.run(page)
    end
    Domstride::Session.open(app: Rails.application) do |page|
      page.visit("/")
      assert page.wait_for_text("#identity", "Anonymous")
      page.click("#latest-link")
      assert page.wait_for_text("#persisted", "No expense")
    end
  end

  def test_csrf_rejects_missing_token
    require "rack/test"
    client = Rack::Test::Session.new(Rack::MockSession.new(Rails.application))
    client.get("/")
    client.post("/login", email: "tester@example.test", password: "fixture-password")
    assert_equal 422, client.last_response.status
    assert_includes client.last_response.body, "Invalid CSRF token"
  end

  private

  def assert_difference_in_expenses
    before = ExpenseReference::Expense.count
    yield
    assert_equal before + 1, ExpenseReference::Expense.count
  end
end
