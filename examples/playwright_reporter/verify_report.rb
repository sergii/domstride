require "json"
require "domstride/report"

abort "Runner was loaded" if defined?(Domstride::Session) || defined?(Domstride::Runtime)
root = ARGV.fetch(0)
output = Domstride::Report.export(root)
json = File.read(output).split('<script type="application/json" id="recording-data">',2).last.split("</script>",2).first
cases = JSON.parse(json).fetch("cases")
abort "Expected five separate attempts" unless cases.size == 5
abort "Wrong statuses" unless cases.map { |item| item["status"] }.tally == {"passed"=>2,"failed"=>2,"skipped"=>1}
abort "Missing provenance" unless cases.all? { |item| item.values_at("framework","runner","platform") == ["playwright-test","playwright","web"] }
passed = cases.find { |item| item["name"].include?("create expense") }
failed = cases.find { |item| item["name"].include?("failed assertion") }
retry_cases = cases.select { |item| item["name"].include?("retry attempt") }
abort "Missing steps" unless passed.fetch("steps").map { |step| step["text"] } == ["Enter amount","Save expense"]
abort "Missing assertions" unless passed.fetch("assertion_events").map { |row| row.values_at("status","step_sequence") } == [["passed",1],["passed",2]]
abort "Missing failure evidence" unless failed.fetch("assertion_events").first["status"] == "failed" && failed.fetch("steps").first["status"] == "failed"
abort "Missing actual video" unless [passed,failed].all? { |item| item.fetch("videos").any? { |video| video.fetch("base64").bytesize > 100 } }
abort "Retry metadata missing" unless retry_cases.any? { |item| item["name"].end_with?("[attempt 1]") && item["status"]=="failed" } && retry_cases.any? { |item| item["name"].end_with?("[attempt 2]") && item["status"]=="passed" }
abort "Unexpected worker traces" unless cases.all? { |item| item.fetch("recordings").empty? }
puts "Verified native Playwright reporter: five attempts, passed/failed/skipped, retries, steps, assertions, WebM, standalone Studio"
