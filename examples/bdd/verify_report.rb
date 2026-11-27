require "json"
require "domstride"
require "domstride/report"

directory = ENV.fetch("DOMSTRIDE_BDD_REPORT_DIR")
output = Domstride::Report.export(directory)
json = File.read(output).split('<script type="application/json" id="recording-data">',2).last.split("</script>",2).first
cases = JSON.parse(json).fetch("cases")
abort "Expected two passed BDD cases" unless cases.size == 2 && cases.all? { |item| item["status"] == "passed" && item["framework"] == ENV.fetch("BDD_FRAMEWORK") }
abort "Expected 14 real Gherkin steps" unless cases.sum { |item| item["steps"].size } == 14
cases.each do |item|
  steps = item.fetch("steps")
  abort "Unexpected step status" unless steps.all? { |step| step["status"] == "passed" && !step["text"].to_s.empty? }
  events = item.fetch("recordings").flat_map { |trace| trace.fetch("events") }
  abort "Expected mapped DOM operations" unless events.any? { |event| event["step_sequence"] == 1 && event["kind"] == "mount" }
  abort "Invalid step sequence" unless events.all? { |event| event["step_sequence"].nil? || steps.any? { |step| step["sequence"] == event["step_sequence"] } }
end
puts "Verified two scenarios, 14 Gherkin steps and mapped DOM interactions"
