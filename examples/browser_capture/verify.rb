require "domstride/report"
require "json"
require "open3"

root = ARGV.fetch(0)
rspec = JSON.parse(File.read(File.join(root, "rspec.json")))
examples = rspec.fetch("examples").to_h { |example| [example.fetch("description"), example] }
abort "Unexpected RSpec examples" unless examples.keys.sort == ["failed case", "passed case"]
abort "Passing scenario failed: #{examples.fetch("passed case").inspect}" unless examples.fetch("passed case").fetch("status") == "passed"
failed = examples.fetch("failed case")
abort "Wrong failure: #{failed.inspect}" unless failed.fetch("status") == "failed" &&
  failed.fetch("exception").fetch("class") == "RSpec::Expectations::ExpectationNotMetError" &&
  failed.fetch("exception").fetch("message").include?("Approved")
paths = Dir[File.join(root,"domstride-case-*")]
abort "Expected two cases" unless paths.size == 2
statuses = []
paths.each do |path|
  item = JSON.parse(File.read(File.join(path,"case.json")))
  statuses << item.fetch("status")
  video = item.fetch("videos").fetch(0)
  file = File.join(path, video.fetch("file"))
  output, result = Open3.capture2e("ffprobe", "-v", "error", "-select_streams", "v:0",
    "-count_frames", "-show_entries", "stream=nb_read_frames,width,height,codec_name", "-of", "json", file)
  abort "Invalid captured video" unless result.success?
  stream = JSON.parse(output).fetch("streams").fetch(0)
  abort "Expected multiple real frames" unless stream.fetch("nb_read_frames").to_i >= 3 && stream.values_at("width","height","codec_name") == [800,600,"vp8"]
  cues = video.fetch("cues")
  abort "Missing assertion video cue for #{item.fetch("name")}: #{cues.inspect}" unless cues.any? { |cue| cue["kind"] == "assertion" && cue["sequence"] == 1 && cue["time_ms"].positive? }
  abort "Expected private attachment" unless File.stat(file).mode & 0o777 == 0o600
end
abort "Wrong final statuses" unless statuses.sort == %w[failed passed]
output = Domstride::Report.export(root)
abort "Missing offline video evidence" unless File.read(output).include?("X11 browser display")
puts "Verified passed and failed real-browser cases with decoded WebM frames"
