require "json"
require "tmpdir"
require "open3"
cli = File.expand_path(ARGV.fetch(0))
raise "Producer leaked into Viewer package" if File.exist?(File.join(File.dirname(cli),"../lib/domstride.rb"))
Dir.mktmpdir do |dir|
  input = File.join(dir,"mapping.json")
  output = File.join(dir,"coverage.html")
  c = {"candidate_id"=>"a", "file"=>"pets/<script>.erb", "source"=>{"start"=>[2,2],"end"=>[2,10]}, "tag"=>"button"}
  n = ->(path,clicked) { {"path"=>path,"candidate_ids"=>["a"],"status"=>"source_matched","clicked"=>clicked} }
  File.write(input, JSON.generate({"format"=>"specdrive.research.source-mapping","version"=>1,"source_revision"=>"synthetic",
    "runs"=>[{"archive_enabled"=>false,"candidates"=>[c],"nodes"=>[n.call([1,0],false),n.call([1,1],true)]}]}))
  run = ->(*args) { Open3.capture3({"RUBYOPT"=>nil,"RUBYLIB"=>nil,"BUNDLE_GEMFILE"=>nil},cli,*args,chdir:dir) }
  stdout, stderr, status = run.call("coverage",input,output)
  raise "Coverage export failed: #{stderr}" unless status.success?
  html = File.read(output)
  %w[run-1-candidate-1 run-1-observation-1 run-1-observation-2].each do |id|
    raise "Missing cross-link #{id}" unless html.include?("id=\"#{id}\"") && html.include?("href=\"##{id}\"")
  end
  raise "Incorrect instance evidence" unless html.include?("50.0%") && html.include?("Successful click")
  raise "Unescaped filename" if html.include?("<script>")
  raise "No-overwrite regression" if run.call("coverage",input,output).last.success?
  raise "Changed existing report" unless File.read(output)==html
  bad = File.join(dir,"bad.json")
  File.write(bad, '{"format":"specdrive.research.source-mapping","version":99}')
  raise "Unknown version accepted" if run.call("coverage",bad,File.join(dir,"bad.html")).last.success?
  File.symlink(input,File.join(dir,"link.json"))
  raise "Symlink accepted" if run.call("coverage",File.join(dir,"link.json"),File.join(dir,"link.html")).last.success?
end
puts "Independent coverage CLI contract passed"
