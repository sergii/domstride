require "benchmark"
require "json"
require_relative "scenario"

engine = ENV.fetch("DOMSTRIDE_ENGINE", "jsdom")
clock = ENV.fetch("DOMSTRIDE_CLOCK", "real")
settling = ENV.fetch("DOMSTRIDE_SETTLING", "checkpoint")
iterations = 10
repeats = 5
Domstride::Session.open(app: Rails.application, profile: true) do |page|
  before = ExpenseReference::Expense.count
  ExpenseScenario.run(page)
  page.reset_profile!
  samples = Array.new(repeats) { Benchmark.realtime { iterations.times { ExpenseScenario.run(page) } } }
  raise "Persistence mismatch" unless ExpenseReference::Expense.count == before + 1 + repeats * iterations
  puts JSON.pretty_generate(engine: engine, clock: clock, settling: settling, iterations: iterations,
    samples: samples, median_seconds: samples.sort[repeats / 2], profile: page.profile, memory: page.memory)
end
