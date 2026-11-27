# Validate malformed and legacy manifests against the actual Report exporter.
require "json"
require "tmpdir"
require "fileutils"
require_relative "../../lib/domstride/report"

root = File.realpath(ARGV.fetch(0))
source = Dir.glob(File.join(root, "domstride-case-*", "case.json")).find do |path|
  JSON.parse(File.read(path)).fetch("videos", []).any? { |v| v["timing_quality"] == "visual_candidates_unvalidated" }
end
raise "Missing observed source" unless source
original = JSON.parse(File.read(source))
Dir.mktmpdir("domstride-protocol-test") do |tmp|
  folder = File.join(tmp, "domstride-case-test")
  Dir.mkdir(folder)
  FileUtils.cp(File.join(File.dirname(source), "video-01.webm"), folder)
  meta = File.join(folder, "case.json")
  export = lambda do |name, item|
    File.write(meta, JSON.generate(item))
    Domstride::Report.export(tmp, output: File.join(tmp, name + ".html"))
  end
  export.call("valid", original)
  legacy = JSON.parse(JSON.generate(original))
  attachment = legacy["videos"].first
  attachment.delete("timing_quality")
  attachment.delete("step_timing_quality")
  attachment.delete("step_intervals")
  attachment["focus"].each { |f| f.delete("step_sequence"); f.delete("label") }
  attachment["cues"] = [{ "kind" => "step", "sequence" => 1, "time_ms" => 0 }]
  export.call("legacy", legacy)
  mutations = {
    "invalid_quality" => ->(v) { v["timing_quality"] = false },
    "unknown_quality" => ->(v) { v["timing_quality"] = "verified" },
    "missing_label" => ->(v) { v["focus"].first.delete("label") },
    "missing_step" => ->(v) { v["focus"].first["step_sequence"] = 999 },
    "mixed_cues" => ->(v) { v["cues"] = [{ "kind" => "step", "sequence" => 1, "time_ms" => 0 }] },
    "overlap" => ->(v) { v["focus"][1]["start_ms"] = v["focus"][0]["start_ms"] },
    "unexpected_element_value" => ->(v) { v["focus"].first["element"] = { "tag" => "input", "value" => "secret" } },
    "password_element" => ->(v) { v["focus"].first["element"] = { "tag" => "input", "type" => "password" } },
    "missing_step_timing_quality" => ->(v) { v.delete("step_timing_quality") },
    "overlapping_step_intervals" => ->(v) { v["step_intervals"][1]["start_ms"] = v["step_intervals"][0]["start_ms"] },
    "missing_focus_step_interval" => ->(v) { v["step_intervals"].reject! { |s| s["step_sequence"] == v["focus"].first["step_sequence"] } },
    "bad_geometry" => ->(v) { v["focus"].first["width"] = 2 }
  }
  mutations.each do |name, mutate|
    item = JSON.parse(JSON.generate(original))
    mutate.call(item["videos"].first)
    begin
      export.call(name, item)
    rescue Domstride::Error
      next
    end
    raise "Accepted invalid manifest: #{name}"
  end
end
puts "Verified observed focus validation, twelve malformed manifests and legacy video export."
