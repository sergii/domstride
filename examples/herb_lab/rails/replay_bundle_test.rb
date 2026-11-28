require "json"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "../../../viewer/lib/coverage_bundle"

input,cli = ARGV
mapping = JSON.parse(File.read(input))
root = File.dirname(File.realpath(input))
Dir.mktmpdir do |dir|
  output = File.join(dir,"bundle")
  stdout,stderr,status = Open3.capture3({"BUNDLE_GEMFILE"=>nil,"RUBYOPT"=>nil,"RUBYLIB"=>nil},cli,"coverage-bundle",input,output,chdir:dir)
  raise "Isolated bundle failed: #{stderr}" unless status.success?
  report = JSON.parse(File.read(File.join(output,"coverage.json")))
  html = File.read(File.join(output,"coverage.html"))
  raise "Expected two replay files" unless Dir.glob("run-*-event-*.html",base:output).size == 2
  report.fetch("runs").each_with_index do |run,index|
    linked = run.fetch("observations").select { |node| node["replay_href"] }
    raise "Unexpected linked nodes" unless linked.size == 1 && linked.first["clicked"]
    name = linked.first.fetch("replay_href")
    raise "Missing HTML link" unless html.include?("href=\"#{name}\"")
    replay = File.read(File.join(output,name))
    raise "Missing replay payload" unless replay.include?('"kind":"click"') && replay.include?('"html":')
    raise "Wrong event filename" unless name == "run-#{index+1}-event-#{mapping.fetch("runs")[index].fetch("recording_ref").fetch("event_sequence")}.html"
  end
  raise "Output overwrite accepted" if Open3.capture3(cli,"coverage-bundle",input,output).last.success?
  invalid = Marshal.load(Marshal.dump(mapping))
  invalid["runs"][0]["recording_ref"]["sha256"] = "0" * 64
  begin
    CoverageBundle.prepare(invalid,root)
    raise "Tampered digest accepted"
  rescue ArgumentError => e
    raise unless e.message == "Recording digest mismatch"
  end
  invalid = Marshal.load(Marshal.dump(mapping))
  invalid["runs"][0]["recording_ref"]["directory"] = "../recording-1"
  begin
    CoverageBundle.prepare(invalid,root)
    raise "Traversal accepted"
  rescue ArgumentError => e
    raise unless e.message == "Invalid recording reference"
  end
  invalid = Marshal.load(Marshal.dump(mapping))
  nodes = invalid["runs"][0]["nodes"]
  nodes.find { |n| n["clicked"] }["clicked"] = false
  nodes.find { |n| !n["clicked"] }["clicked"] = true
  begin
    CoverageBundle.prepare(invalid,root)
    raise "Wrong target accepted"
  rescue ArgumentError => e
    raise unless e.message == "Unverified recorded target"
  end
end
puts "Verified Rails recording-to-Viewer event bundle contract passed"
