# Standalone consumer contract: run with --disable-gems and only the staged file allowlist.
require "domstride/consumer"
require "tmpdir"
require "fileutils"

def check(value, message)
  raise message unless value
end

consumer = Domstride::Consumer
check(!defined?(Domstride::Session), "Engine loaded")
check(!defined?(Domstride::ReportCase), "Producer hooks loaded")
check(!defined?(Domstride::Runtime), "Runtime loaded")
check(!consumer::Report.respond_to?(:capture), "Capture leaked into consumer")
check(!consumer::Video.respond_to?(:attach), "Attachment producer leaked into consumer")

Dir.mktmpdir do |dir|
  case_dir = File.join(dir, "domstride-case-external")
  FileUtils.mkdir_p(case_dir)
  metadata = {format: "domstride.case", schema_version: 1, producer: "external-framework",
              name: "Independent result", status: "failed", duration_ms: 12,
              videos: [{file: "video-01.webm", label: "External video"}]}
  File.write(File.join(case_dir, "case.json"), JSON.generate(metadata))
  # Header-only fixture verifies import bounds, not media playback.
  File.binwrite(File.join(case_dir, "video-01.webm"), "\x1a\x45\xdf\xa3\x42\x82\x84webm".b)
  output = consumer::Report.export(dir)
  html = File.read(output)
  payload = JSON.parse(html.split('<script type="application/json" id="recording-data">', 2).last.split("</script>", 2).first)
  result = payload.fetch("cases").fetch(0)
  check(result["producer"] == "external-framework", "Producer lost")
  check(result["status"] == "failed", "Framework status lost")
  check(result.fetch("videos").size == 1, "Video lost")
  check(File.stat(output).mode & 0o777 == 0o600, "Output permission changed")
  begin
    consumer::Report.export(dir)
    raise "Existing output overwritten"
  rescue Errno::EEXIST
  end
  File.unlink(File.join(case_dir, "video-01.webm"))
  File.symlink("/dev/null", File.join(case_dir, "video-01.webm"))
  begin
    consumer::Report.export(dir, output: File.join(dir, "invalid.html"))
    raise "Symlink accepted"
  rescue Domstride::Error
  end
end
puts "Independent artifact-only consumer verified without RubyGems, engine or producer hooks."
