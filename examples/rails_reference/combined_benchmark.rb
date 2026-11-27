require "benchmark"
require "json"
require_relative "scenario"
require_relative "capybara_scenario"

engine = ENV.fetch("DOMSTRIDE_ENGINE", "jsdom")
dsl = ENV.fetch("DOMSTRIDE_DSL", "native")
name = ENV.fetch("BENCHMARK_PROFILE", "baseline")
raise "Invalid DSL" unless %w[native capybara].include?(dsl)
raise "Invalid profile" unless %w[baseline candidate].include?(name)

# Keep defaults explicit to make this comparison reproducible.
options = { engine: engine, runtime: "node", profile: false, wait_strategy: "poll",
            bundle_cache: "off", settling: "checkpoint", clock: "real" }
prefetch = false
if name == "candidate"
  options[:wait_strategy] = "observer"
  if engine != "happy-dom"
    options[:bundle_cache] = "compiled"
    if dsl == "native"
      options[:settling] = "tracked"
      options[:clock] = "virtual"
    end
    prefetch = dsl == "capybara"
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "10"))
repeats = Integer(ENV.fetch("REPEATS", "5"))
raise "Invalid benchmark dimensions" unless iterations.positive? && repeats.positive? && repeats.odd?
startup = Process.clock_gettime(Process::CLOCK_MONOTONIC)
if dsl == "capybara"
  # Driver configuration is passed via the existing public environment switches.
  ENV["DOMSTRIDE_ENGINE"] = engine
  ENV["DOMSTRIDE_RUNTIME"] = options[:runtime]
  ENV["DOMSTRIDE_PROFILE"] = "0"
  ENV["DOMSTRIDE_WAIT"] = options[:wait_strategy]
  ENV["DOMSTRIDE_BUNDLE_CACHE"] = options[:bundle_cache]
  ENV["DOMSTRIDE_SETTLING"] = options[:settling]
  ENV["DOMSTRIDE_CLOCK"] = options[:clock]
  ENV["DOMSTRIDE_QUERY_PREFETCH"] = prefetch ? "1" : "0"
  page = Capybara::Session.new(:domstride, Rails.application)
  worker = page.driver.worker
  scenario = CapybaraExpenseScenario
else
  page = worker = Domstride::Session.new(app: Rails.application, **options)
  scenario = ExpenseScenario
end

begin
  before = ExpenseReference::Expense.count
  matching_before = ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count
  scenario.run(page)
  startup_and_warmup = Process.clock_gettime(Process::CLOCK_MONOTONIC) - startup
  samples = Array.new(repeats) { Benchmark.realtime { iterations.times { scenario.run(page) } } }
  expected = 1 + repeats * iterations
  raise "Persistence mismatch" unless ExpenseReference::Expense.count == before + expected &&
    ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count == matching_before + expected
  puts JSON.pretty_generate(driver: "domstride", engine: engine, dsl: dsl, profile: name,
    settings: options.merge(query_prefetch: prefetch), ruby: RUBY_VERSION, rails: Rails.version,
    yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?, persistence_checked: true,
    iterations: iterations, repeats: repeats, samples: samples, median_seconds: samples.sort[repeats / 2],
    startup_and_warmup_seconds: startup_and_warmup, worker_memory_kib: worker.memory)
ensure
  dsl == "capybara" ? page.driver.quit : worker.close
end
