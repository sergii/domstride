require "domstride/report"
require "tmpdir"
require "json"

abort "Execution runtime was loaded" if defined?(Domstride::Session) || defined?(Domstride::Runtime) || defined?(Capybara)

Dir.mktmpdir do |root|
  directory = File.join(root, "domstride-case-external")
  Dir.mkdir(directory)
  path = File.join(directory, "case.json")
  manifest = {format: "domstride.case", schema_version: 1, name: "External API check",
    status: "passed", duration_ms: 12, producer: "external", framework: "pytest",
    runner: "http-client", platform: "api", language: "python",
    assertions: 1, assertion_events: [{sequence: 1, kind: "status_code", status: "passed", duration_ms: 1}]}
  File.write(path, JSON.generate(manifest))
  output = Domstride::Report.export(root)
  html = File.read(output)
  json = html.split('<script type="application/json" id="recording-data">',2).last.split("</script>",2).first
  item = JSON.parse(json).fetch("cases").first
  abort "Missing external metadata" unless item.values_at("framework","runner","platform","language") == ["pytest","http-client","api","python"]
  abort "Unexpected evidence" unless item["recordings"].empty? && item["videos"].empty?
  abort "Assertion not retained" unless item.fetch("assertion_events").first["status"] == "passed"
  File.write(path, JSON.generate(manifest.merge(schema_version: 99)))
  begin
    Domstride::Report.export(root, output: File.join(root,"invalid.html"))
    abort "Accepted unsupported schema"
  rescue Domstride::Error
  end
  File.write(path, JSON.generate(manifest.merge(format: "other.case")))
  begin
    Domstride::Report.export(root, output: File.join(root,"invalid.html"))
    abort "Accepted unsupported format"
  rescue Domstride::Error
  end
  File.write(path, JSON.generate(manifest.merge(runner: ["invalid"])))
  begin
    Domstride::Report.export(root, output: File.join(root,"invalid.html"))
    abort "Accepted malformed producer metadata"
  rescue Domstride::Error
  end
end
puts "Verified independent Studio import with external producer and no Runner"
