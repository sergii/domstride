require "benchmark"
require "json"
require_relative "scenario"
require_relative "capybara_scenario"

mode = ENV.fetch("DOMSTRIDE_DSL", "native")
engine = ENV.fetch("DOMSTRIDE_ENGINE", "jsdom")
strategy = ENV.fetch("DOMSTRIDE_WAIT", "poll")
iterations = Integer(ENV.fetch("ITERATIONS", "10"))
repeats = Integer(ENV.fetch("REPEATS", "5"))
if mode == "capybara"
  page = Capybara::Session.new(:domstride, Rails.application)
  worker = page.driver.worker
  scenario = CapybaraExpenseScenario
else
  worker = page = Domstride::Session.new(app: Rails.application)
  scenario = ExpenseScenario
end
begin
  before = ExpenseReference::Expense.count
  scenario.run(page)
  worker.reset_profile!
  samples = Array.new(repeats) { Benchmark.realtime { iterations.times { scenario.run(page) } } }
  raise "Persistence mismatch" unless ExpenseReference::Expense.count == before + 1 + repeats * iterations
  puts JSON.pretty_generate(engine: engine, dsl: mode, wait: strategy, ruby: RUBY_VERSION, rails: Rails.version,
    iterations: iterations, repeats: repeats, samples: samples, median_seconds: samples.sort[samples.size / 2],
    profile: worker.profile, worker_memory_kib: worker.memory)
ensure
  worker.close
end
