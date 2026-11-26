require "benchmark"
require "json"
require_relative "capybara_scenario"

mode = ENV.fetch("CAPYBARA_DRIVER", "domstride").to_sym
if mode == :cuprite
  require "capybara/cuprite"
  Capybara.server = :puma, { Silent: true }
  Capybara.register_driver(:cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, browser_path: ENV.fetch("CHROME_PATH"), headless: true, timeout: 5, process_timeout: 30, browser_options: { "no-sandbox" => nil, "disable-dev-shm-usage" => nil })
  end
end
page = Capybara::Session.new(mode, Rails.application)
iterations = Integer(ENV.fetch("ITERATIONS", "10"))
repeats = Integer(ENV.fetch("REPEATS", "5"))
begin
  before = ExpenseReference::Expense.count
  matching_before = ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count
  CapybaraExpenseScenario.run(page)
  samples = Array.new(repeats) { Benchmark.realtime { iterations.times { CapybaraExpenseScenario.run(page) } } }
  raise "Persistence mismatch" unless ExpenseReference::Expense.count == before + 1 + repeats * iterations && ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count == matching_before + 1 + repeats * iterations
  puts JSON.pretty_generate(driver: mode, engine: mode == :domstride ? ENV.fetch("DOMSTRIDE_ENGINE", "jsdom") : "chromium", ruby: RUBY_VERSION, rails: Rails.version, persistence_checked: true, iterations: iterations, repeats: repeats, samples: samples, median_seconds: samples.sort[samples.size / 2])
ensure
  page.driver.quit
end
