require "json"
report = JSON.parse(File.read(ARGV.fetch(0)))
abort "Wrong Herb version" unless report.fetch("parser") == "0.11.2"
literal, helpers = report.fetch("reports")
abort "Unexpected parser modes" unless [literal, helpers].map { |r| r.fetch("action_view_helpers") } == [false, true]
[literal, helpers].each do |mode|
  files = mode.fetch("files").to_h { |f| [f.fetch("file"), f] }
  abort "Unexpected fixture files" unless files.keys.sort == %w[pets/_card.html.erb pets/new.html.erb]
  abort "Parser diagnostics: #{files.transform_values { |f| f.fetch("diagnostic_count") }}" unless files.values.all? { |f| f.fetch("diagnostic_count").zero? }
  main = files.fetch("pets/new.html.erb").fetch("candidates")
  partial = files.fetch("pets/_card.html.erb").fetch("candidates")
  tags = main.select { |c| c.fetch("origin") == "literal_html" }.map { |c| c.fetch("tag") }
  abort "Incorrect literal inventory: #{tags}" unless tags.sort == %w[button button form input label]
  abort "Incorrect partial inventory" unless partial.map { |c| c.fetch("tag") } == ["button"]
  all = main + partial
  abort "Duplicate candidate identity" unless all.map { |c| c.fetch("candidate_id") }.uniq.size == all.size
  abort "Unexpected source location" unless all.all? { |c| c.dig("source", "start", 0).positive? }
  abort "Unexpected helper inventory" unless main.count { |c| c.fetch("origin") == "helper_candidate" && c.fetch("tag") == "a" } == (mode.fetch("action_view_helpers") ? 1 : 0)
end
puts "Static literal/helper inventory contract passed"
