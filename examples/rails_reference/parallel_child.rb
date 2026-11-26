require "json"
require_relative "scenario"

directory, index, per_worker, repeats, expected_yjit = ARGV
per_worker, repeats = Integer(per_worker), Integer(repeats)
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
raise "Unexpected YJIT state: #{yjit}" unless yjit == (expected_yjit == "on")
def signal(directory, name, value)
  path = File.join(directory, name)
  File.write("#{path}.tmp", JSON.generate(value))
  File.rename("#{path}.tmp", path)
end

def await_signal(directory, name)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 180
  until File.exist?(File.join(directory, name))
    raise "Barrier timeout: #{name}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    sleep 0.01
  end
end

Domstride::Session.open(app: Rails.application, profile: false, wait_strategy: "observer",
                        settling: "checkpoint", clock: "real", bundle_cache: "off") do |page|
  raise "Nonempty database at startup" unless ExpenseReference::Expense.count.zero?
  page.visit("/")
  page.assert_text("#identity", "Anonymous")
  3.times { ExpenseScenario.run(page) }
  raise "Warmup persistence mismatch" unless ExpenseReference::Expense.count == 3
  database = ActiveRecord::Base.connection_db_config.database
  signal(directory, "ready-#{index}", { ruby_pid: Process.pid, node_pid: page.worker_pid, database: database, yjit: yjit })
  repeats.times do |sample|
    await_signal(directory, "start-#{sample}")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    per_worker.times { ExpenseScenario.run(page) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    expected = 3 + per_worker * (sample + 1)
    raise "Persistence mismatch: worker #{index}" unless ExpenseReference::Expense.count == expected &&
      ExpenseReference::Expense.where(description: "Lunch", amount: 25, user_id: 1).count == expected
    signal(directory, "done-#{sample}-#{index}", { seconds: elapsed, records: expected, scenarios: per_worker })
  end
  await_signal(directory, "finish")
end
