require "benchmark"
require "json"
require_relative "semantic_expense_scenario"

engine = ENV.fetch("SPECDRIVE_ENGINE")
page = Capybara::Session.new(:specdrive, Rails.application)
iterations = 5
repeats = 3
begin
  before = ExpenseReference::Expense.count
  matching_before = ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count
  SemanticExpenseScenario.run(page)
  samples = Array.new(repeats) { Benchmark.realtime { iterations.times { SemanticExpenseScenario.run(page) } } }
  expected = 1 + repeats * iterations
  raise "Persistence mismatch" unless ExpenseReference::Expense.count == before + expected &&
    ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count == matching_before + expected
  puts JSON.generate(engine: engine, ruby: RUBY_VERSION, rails: Rails.version, settings: page.driver.diagnostics,
    persistence_checked: true, iterations: iterations, repeats: repeats, samples: samples)
ensure
  page.driver.quit
end
