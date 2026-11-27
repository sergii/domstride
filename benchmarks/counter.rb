require "benchmark"
require "json"
require_relative "../lib/domstride"

html = File.read(File.expand_path("../examples/counter.html", __dir__))
iterations = Integer(ENV.fetch("ITERATIONS", "1000"))
repeats = Integer(ENV.fetch("REPEATS", "5"))
abort "Positive iterations and repeats required" unless iterations.positive? && repeats.positive?
runtime = ENV.fetch("DOMSTRIDE_RUNTIME", "node")
samples = []
repeats.times do
  cold = Benchmark.realtime do
    Domstride::Session.open(runtime: runtime) do |page|
      page.mount_html(html)
      page.click("#increment")
      page.assert_text("#count", "1")
    end
  end
  Domstride::Session.open(runtime: runtime) do |page|
    page.mount_html(html)
    100.times { page.click("#increment") }
    page.mount_html(html)
    elapsed = Benchmark.realtime do
      iterations.times do |i|
        page.click("#increment")
        page.assert_text("#count", (i + 1).to_s)
      end
    end
    samples << { cold_seconds: cold, warm_seconds: elapsed, iterations_per_second: iterations / elapsed }
  end
end
median = ->(values) { sorted = values.sort; (sorted[(sorted.size - 1) / 2] + sorted[sorted.size / 2]) / 2.0 }
result = { runtime: runtime, runtime_version: IO.popen([runtime, "--version"], &:read).strip, ruby: RUBY_VERSION,
  iterations: iterations, repeats: repeats, samples: samples,
  median_cold_seconds: median.call(samples.map { |s| s[:cold_seconds] }),
  median_warm_seconds: median.call(samples.map { |s| s[:warm_seconds] }) }
puts JSON.pretty_generate(result)
