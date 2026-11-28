require_relative "coverage"

def check(condition, message)
  raise message unless condition
end

def candidate(id)
  {"candidate_id"=>id, "file"=>"pets/<script>.html.erb", "source"=>{"start"=>[2,2],"end"=>[2,20]}, "tag"=>"button"}
end

def node(path, ids, status, clicked=false)
  {"path"=>path, "candidate_ids"=>ids, "status"=>status, "clicked"=>clicked}
end

def mapping(candidates, nodes)
  {"format"=>"specdrive.research.source-mapping", "version"=>1, "source_revision"=>"fixture",
   "runs"=>[{"archive_enabled"=>false,"candidates"=>candidates,"nodes"=>nodes}]}
end

def reject(mapping)
  begin
    UICoverage.aggregate(mapping)
  rescue ArgumentError
    return
  end
  raise "Expected invalid input rejection"
end

input = mapping([candidate("a"),candidate("b"),candidate("c")], [
  node([1,0],["a"],"source_matched",true),
  node([1,1],["a"],"source_matched"),
  node([1,2],["b"],"source_matched"),
  node([1,3],[],"unstamped"),
  node([1,4],[],"unresolved_stamp"),
  node([1,5],["b","c"],"ambiguous",true)
])
report = UICoverage.aggregate(input)
run = report.fetch("runs").first
check(run["source_rendering"] == UICoverage.ratio(2,3),"Wrong source rendering")
check(run["source_interaction"] == UICoverage.ratio(1,3),"Wrong source interaction")
check(run["matched_instance_interaction"] == UICoverage.ratio(1,3),"Wrong matched instance interaction")
check(run["all_observed_instance_interaction"] == UICoverage.ratio(2,6),"Wrong all observed interaction")
check(run["unmatched_clicked_instances"] == 1,"Lost unmatched click")
check(run["mapping_counts"]["ambiguous"] == 1,"Lost ambiguity")
check(run["candidates"].first["rendered_instances"] == 2,"Lost repeated partial")
check(run["candidates"].last["status"] == "not_observed_in_snapshot","Ambiguity promoted to matched")
check(report["assertion_coverage"].nil?,"Invented assertion coverage")
check(!UICoverage.render(report).include?("<script>"),"Unescaped source path")
check(UICoverage.render(report).include?("&lt;script&gt;"),"Missing escaped source path")
empty = UICoverage.aggregate(mapping([],[]))["runs"].first
check(empty["source_rendering"]["percent"].nil? && empty["all_observed_instance_interaction"]["percent"].nil?,"Zero denominator must be unknown")
reject(mapping([candidate("a"),candidate("a")],[]))
reject(mapping([candidate("a")],[node([1],["a"],"source_matched"),node([1],["a"],"source_matched")]))
reject(mapping([candidate("a")],[node([1],["missing"],"source_matched")]))
reject(mapping([candidate("a")],[node([1],["a"],"ambiguous")]))
if ARGV[0]
  actual = UICoverage.aggregate(JSON.parse(File.read(ARGV[0])))
  check(actual["runs"].size == 2,"Expected two actual runs")
  actual["runs"].each_with_index do |row,i|
    check(row["source_rendering"] == UICoverage.ratio(2+i,3),"Actual source rendering mismatch")
    check(row["source_interaction"] == UICoverage.ratio(1,3),"Actual source interaction mismatch")
    check(row["matched_instance_interaction"] == UICoverage.ratio(1,3+i),"Actual instance interaction mismatch")
    check(row["all_observed_instance_interaction"] == UICoverage.ratio(1,5+i),"Actual all-instance mismatch")
    check(row["mapping_counts"].values_at("unstamped","unresolved_stamp","ambiguous") == [1,1,0],"Actual unmatched mismatch")
  end
end
puts "UI interaction evidence aggregation contract passed"
