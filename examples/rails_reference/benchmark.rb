require "benchmark"
require "json"
require_relative "scenario"

repeats = Integer(ENV.fetch("REPEATS", "5"))
iterations = Integer(ENV.fetch("ITERATIONS", "10"))
samples = []
Domstride::Session.open(app: Rails.application) do |page|
  ExpenseScenario.run(page)
  repeats.times do
    samples << Benchmark.realtime { iterations.times { ExpenseScenario.run(page) } }
  end
end
puts JSON.pretty_generate(runtime: ENV.fetch("DOMSTRIDE_RUNTIME", "node"), engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"), ruby: RUBY_VERSION, rails: Rails.version, iterations: iterations, samples: samples, median_seconds: samples.sort[samples.length / 2])
