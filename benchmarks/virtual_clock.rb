require "benchmark"
require "json"
require_relative "../lib/domstride"

clock = ENV.fetch("DOMSTRIDE_CLOCK", "real")
samples = []
Domstride::Session.open(clock: clock, settling: "tracked", wait_strategy: "observer") do |page|
  html = '<p id="status">Pending</p><button id="start" onclick="setTimeout(() => document.querySelector(\'#status\').textContent = \'Done\', 250)">Start</button>'
  5.times do
    samples << Benchmark.realtime do
      10.times do
        page.mount_html(html)
        page.click("#start")
        page.wait_for_text("#status", "Done")
      end
    end
  end
end
puts JSON.pretty_generate(engine: ENV.fetch("DOMSTRIDE_ENGINE", "jsdom"), clock: clock, delay_ms: 250,
  iterations: 10, samples: samples, median_seconds: samples.sort[2])
