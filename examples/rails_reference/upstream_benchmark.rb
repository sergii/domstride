ENV["RAILS_ENV"] = "test"
ENV["UPSTREAM_REFERENCE"] = "1"
require_relative "application"
require "rails/test_help"
require "rails_jsdom"
require "benchmark"
require "json"

class UpstreamBenchmark < RailsJsdom::TestCase
  def scenario
    visit "/"
    assert_selector "h1", exact_text: "Expense Lab"
    assert_selector "#expense[data-ready=true] #total", exact_text: "0"
    find("#add").click
    assert_selector "#total", exact_text: "25"
    find("#details-link").click
    assert_selector "#receipt", exact_text: "Receipt #42"
    find("#approve-link").click
    assert_selector "#status", exact_text: "Approved"
    find("#email").set("tester@example.test")
    find("#password").set("fixture-password")
    find("#login").click
    assert_selector "#identity", exact_text: "Signed in"
    find("#description").set("Lunch")
    find("#amount").set("0")
    find("#save").click
    assert_selector "#result", exact_text: "Invalid expense"
    find("#amount").set("25")
    find("#save").click
    assert_selector "#result", exact_text: "Saved"
    visit "/"
    assert_selector "#identity", exact_text: "Signed in"
    find("#latest-link").click
    assert_selector "#persisted", exact_text: "Lunch: 25"
  end

  test "stateful fixture benchmark" do
    iterations = Integer(ENV.fetch("ITERATIONS", "10"))
    repeats = Integer(ENV.fetch("REPEATS", "5"))
    before = ExpenseReference::Expense.count
    scenario
    samples = Array.new(repeats) { Benchmark.realtime { iterations.times { scenario } } }
    assert_equal before + 1 + repeats * iterations, ExpenseReference::Expense.count
    result = { driver: "rails-jsdom", engine: "jsdom", version: RailsJsdom::VERSION,
      upstream_commit: "66dc701a48df7038db8e56e8d44e8c36874dae78", ruby: RUBY_VERSION, rails: Rails.version,
      iterations: iterations, samples: samples, median_seconds: samples.sort[samples.size / 2] }
    File.write(ENV.fetch("RESULT_PATH"), JSON.pretty_generate(result))
    puts JSON.pretty_generate(result)
  end
end
