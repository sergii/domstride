require "benchmark"
require "json"
require_relative "scenario"

engine = ENV.fetch("DOMSTRIDE_ENGINE", "jsdom")
mode = ENV.fetch("DOMSTRIDE_BUNDLE_CACHE", "off")
iterations = Integer(ENV.fetch("ITERATIONS", "10"))
repeats = Integer(ENV.fetch("REPEATS", "5"))
cold_samples = []
repeats.times do
  cold_samples << Benchmark.realtime do
    Domstride::Session.open(app: Rails.application, profile: false) do |page|
      page.visit("/")
      page.wait_for_text("#expense[data-ready=true] #total", "0")
    end
  end
end
Domstride::Session.open(app: Rails.application, profile: true) do |page|
  before = ExpenseReference::Expense.count
  ExpenseScenario.run(page)
  page.reset_profile!
  samples = Array.new(repeats) { Benchmark.realtime { iterations.times { ExpenseScenario.run(page) } } }
  raise "Persistence mismatch" unless ExpenseReference::Expense.count == before + 1 + repeats * iterations
  profile = page.profile
  if mode != "off"
    raise "Expected warm bundle hits" unless profile[:bundle_hits] == repeats * iterations * 2 && profile[:bundle_misses] == 0
  end
  puts JSON.pretty_generate(engine: engine, cache: mode, iterations: iterations, repeats: repeats,
    cold_samples: cold_samples, cold_median_seconds: cold_samples.sort[repeats / 2],
    samples: samples, median_seconds: samples.sort[repeats / 2],
    profile: profile, worker_memory_kib: page.memory)
end
