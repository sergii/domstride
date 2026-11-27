require "benchmark"
require "json"
require_relative "../lib/domstride"

HTML = File.read(File.expand_path("../examples/counter.html", __dir__))
ITERATIONS = Integer(ENV.fetch("ITERATIONS", "1000"))
REPEATS = Integer(ENV.fetch("REPEATS", "5"))
ISOLATION_CASES = Integer(ENV.fetch("ISOLATION_CASES", "10"))
abort "Positive counts required" unless [ITERATIONS, REPEATS, ISOLATION_CASES].all?(&:positive?)
CONFIGS = %w[node bun].product(%w[jsdom happy-dom])
def with_page(runtime, engine, &block)
  Domstride::Session.open(runtime: runtime, engine: engine, &block)
end
def one(page)
  page.mount_html(HTML)
  page.click("#increment")
  page.assert_text("#count", "1")
end
def warm(runtime, engine, batched)
  memory = {}
  duration = with_page(runtime, engine) do |page|
    page.mount_html(HTML)
    100.times { page.click("#increment") }
    page.mount_html(HTML)
    elapsed = Benchmark.realtime do
      if batched
        page.batch do |b|
          ITERATIONS.times { |i| b.click("#increment"); b.assert_text("#count", (i + 1).to_s) }
        end
      else
        ITERATIONS.times { |i| page.click("#increment"); page.assert_text("#count", (i + 1).to_s) }
      end
    end
    page.assert_text("#count", ITERATIONS.to_s)
    memory = page.memory
    elapsed
  end
  [duration, memory]
end
def sample(runtime, engine, reverse)
  cold = Benchmark.realtime { with_page(runtime, engine) { |page| one(page) } }
  modes = reverse ? [true, false] : [false, true]
  data = {}
  modes.each { |mode| data[mode] = warm(runtime, engine, mode) }
  persistent = -> { with_page(runtime, engine) { |page| ISOLATION_CASES.times { one(page) } } }
  fresh = -> { ISOLATION_CASES.times { with_page(runtime, engine) { |page| one(page) } } }
  isolation = {}
  (reverse ? [[:fresh, fresh], [:persistent, persistent]] : [[:persistent, persistent], [:fresh, fresh]]).each do |key, task|
    isolation[key] = Benchmark.realtime { task.call }
  end
  { cold_seconds: cold, individual_seconds: data[false][0], batch_seconds: data[true][0],
    individual_memory_kib: data[false][1], batch_memory_kib: data[true][1],
    persistent_seconds: isolation[:persistent], fresh_seconds: isolation[:fresh] }
end
def median(values)
  sorted = values.sort
  (sorted[(sorted.length - 1) / 2] + sorted[sorted.length / 2]) / 2.0
end

results = CONFIGS.to_h { |runtime, engine| [[runtime, engine], { runtime: runtime, engine: engine, samples: [] }] }
REPEATS.times do |i|
  order = CONFIGS.rotate(i % CONFIGS.length)
  order = order.reverse if i.odd?
  order.each do |runtime, engine|
    row = results[[runtime, engine]]
    next if row[:error]
    begin
      row[:samples] << sample(runtime, engine, i.odd?)
    rescue StandardError => e
      row[:error] = "#{e.class}: #{e.message}"
      warn "#{runtime}/#{engine}: #{row[:error]}"
    end
  end
end
rows = results.values
rows.each do |row|
  next if row[:error]
  keys = %i[cold_seconds individual_seconds batch_seconds persistent_seconds fresh_seconds]
  row[:medians] = keys.to_h { |k| [k, median(row[:samples].map { |s| s[k] })] }
  %i[individual_memory_kib batch_memory_kib].each do |k|
    values = row[:samples].filter_map { |s| s[k]["VmHWM"] }
    row[:medians][k] = median(values) unless values.empty?
  end
end
puts JSON.pretty_generate(iterations: ITERATIONS, repeats: REPEATS, isolation_cases: ISOLATION_CASES, results: rows)
abort "Required baseline failed" if rows.first[:error]
