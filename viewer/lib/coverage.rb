require "json"
require "cgi"

# Offline aggregation of the trusted synthetic single-checkpoint mapping format.
# Never treat a structural path as identity across checkpoints or runs.
module UICoverage
  module_function

  def ratio(numerator, denominator)
    { "numerator" => numerator, "denominator" => denominator,
      "percent" => denominator.zero? ? nil : (100.0 * numerator / denominator).round(2) }
  end

  def aggregate(mapping)
    raise ArgumentError, "Unsupported mapping" unless mapping["format"] == "specdrive.research.source-mapping" && mapping["version"] == 1
    runs = mapping.fetch("runs")
    raise ArgumentError, "Invalid runs" unless runs.is_a?(Array)
    { "format" => "specdrive.research.ui-coverage", "version" => 1,
      "scope" => "Synthetic button candidates; one pre-action checkpoint per run",
      "source_revision" => mapping.fetch("source_revision"),
      "assertion_coverage" => nil,
      "runs" => runs.each_with_index.map { |run, index| aggregate_run(run, index + 1) } }
  end

  def aggregate_run(run, number)
    candidates = run.fetch("candidates")
    ids = candidates.map { |c| c.fetch("candidate_id") }
    raise ArgumentError, "Duplicate candidate IDs" unless ids.uniq == ids
    nodes = run.fetch("nodes")
    paths = nodes.map { |n| n.fetch("path") }
    raise ArgumentError, "Invalid or duplicate checkpoint paths" unless paths.all? { |p| p.is_a?(Array) && !p.empty? && p.all? { |part| part.is_a?(Integer) && part >= 0 } } && paths.uniq == paths
    statuses = %w[source_matched unstamped unresolved_stamp ambiguous]
    counts = statuses.to_h { |status| [status, 0] }
    matched = Hash.new { |h,k| h[k] = [] }
    nodes.each do |node|
      status = node.fetch("status")
      raise ArgumentError, "Unknown mapping status" unless statuses.include?(status)
      raise ArgumentError, "Invalid click evidence" unless [true, false].include?(node.fetch("clicked"))
      references = node.fetch("candidate_ids")
      raise ArgumentError, "Invalid candidate references" unless references.is_a?(Array) && references.uniq == references && (references - ids).empty?
      valid = case status
      when "source_matched" then references.size == 1
      when "ambiguous" then references.size > 1
      else references.empty?
      end
      raise ArgumentError, "Inconsistent mapping status" unless valid
      counts[status] += 1
      matched[references.first] << node if status == "source_matched"
    end
    rows = candidates.map do |candidate|
      id = candidate.fetch("candidate_id")
      instances = matched[id]
      clicked = instances.count { |n| n.fetch("clicked") }
      { "candidate_id" => id, "file" => candidate.fetch("file"), "source" => candidate.fetch("source"),
        "tag" => candidate.fetch("tag"), "rendered_instances" => instances.size, "clicked_instances" => clicked,
        "status" => instances.empty? ? "not_observed_in_snapshot" : clicked.positive? ? "observed_interaction" : "rendered_not_clicked" }
    end
    successful = rows.sum { |r| r["clicked_instances"] }
    rendered = rows.count { |r| r["rendered_instances"].positive? }
    interacted = rows.count { |r| r["clicked_instances"].positive? }
    { "run" => number, "archive_enabled" => run.fetch("archive_enabled"),
      "source_rendering" => ratio(rendered, ids.size),
      "source_interaction" => ratio(interacted, ids.size),
      "matched_instance_interaction" => ratio(successful, counts["source_matched"]),
      "all_observed_instance_interaction" => ratio(nodes.count { |n| n["clicked"] }, nodes.size),
      "mapping_counts" => counts,
      "unmatched_clicked_instances" => nodes.count { |n| n["clicked"] && n["status"] != "source_matched" },
      "candidates" => rows,
      "observations" => nodes.each_with_index.map { |node,index| {
        "observation" => index + 1, "path" => node.fetch("path"),
        "candidate_ids" => node.fetch("candidate_ids"), "status" => node.fetch("status"),
        "clicked" => node.fetch("clicked") } } }
  end

  def escape(value)
    CGI.escapeHTML(value.to_s)
  end

  def render(report)
    panels = report.fetch("runs").map do |run|
      metrics = {
        "Source rendering" => run.fetch("source_rendering"),
        "Source interaction" => run.fetch("source_interaction"),
        "Matched instance interaction" => run.fetch("matched_instance_interaction"),
        "All observed instance interaction" => run.fetch("all_observed_instance_interaction")
      }.map do |name, metric|
        value = metric["percent"].nil? ? "N/A" : "#{metric["percent"]}%"
        "<div class=\"metric\"><span>#{escape(name)}</span><strong>#{escape(value)}</strong><small>#{metric.fetch("numerator")} / #{metric.fetch("denominator")}</small></div>"
      end.join
      counts = run.fetch("mapping_counts").map { |key,count| "<li>#{escape(key)}: #{escape(count)}</li>" }.join
      number = run.fetch("run")
      rows = run.fetch("candidates").map.with_index do |row, index|
        start = row.fetch("source").fetch("start")
        observations = run.fetch("observations").select { |node| node.fetch("candidate_ids").include?(row.fetch("candidate_id")) }
        links = observations.map { |node| "<a href=\"#run-#{number}-observation-#{node.fetch("observation")}\">#{node.fetch("observation")}</a>" }.join(", ")
        "<tr id=\"run-#{number}-candidate-#{index + 1}\"><td>#{escape(row.fetch("file"))}:#{escape(start.join(":"))}</td><td>#{escape(row.fetch("tag"))}</td><td>#{escape(row.fetch("rendered_instances"))}</td><td>#{escape(row.fetch("clicked_instances"))}</td><td>#{escape(row.fetch("status"))}</td><td>#{links.empty? ? "None" : links}</td></tr>"
      end.join
      observations = run.fetch("observations").map do |node|
        links = run.fetch("candidates").each_with_index.filter_map do |candidate,index|
          next unless node.fetch("candidate_ids").include?(candidate.fetch("candidate_id"))
          "<a href=\"#run-#{number}-candidate-#{index + 1}\">#{escape(candidate.fetch("file"))}:#{escape(candidate.fetch("source").fetch("start").join(":"))}</a>"
        end.join(", ")
        "<tr id=\"run-#{number}-observation-#{node.fetch("observation")}\"><td>#{node.fetch("observation")}</td><td>#{escape(node.fetch("path").join("/"))}</td><td>#{escape(node.fetch("status"))}</td><td>#{node.fetch("clicked") ? "Successful click" : "Not clicked"}</td><td>#{links.empty? ? "Unmatched" : links}</td></tr>"
      end.join
      "<section><h2>Run #{escape(run.fetch("run"))} / Archive #{run.fetch("archive_enabled") ? "enabled" : "disabled"}</h2><div class=\"metrics\">#{metrics}</div><h3>Mapping evidence</h3><ul>#{counts}</ul><p>Unmatched clicked instances: #{escape(run.fetch("unmatched_clicked_instances"))}</p><div class=\"scroll\"><table><thead><tr><th>Source (AST coordinates)</th><th>Tag</th><th>Rendered</th><th>Clicked</th><th>Evidence</th><th>Observations</th></tr></thead><tbody>#{rows}</tbody></table></div><h3>Runtime observations</h3><p>Paths identify nodes only in this pre-action checkpoint. No replay link is inferred.</p><div class=\"scroll\"><table><thead><tr><th>Observation</th><th>DOM path</th><th>Mapping</th><th>Interaction</th><th>Source candidates</th></tr></thead><tbody>#{observations}</tbody></table></div></section>"
    end.join
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>Specdrive UI interaction evidence</title>
      <style>body{font:15px system-ui,sans-serif;color:#182536;background:#f5f7fa;max-width:1100px;margin:32px auto;padding:0 20px}h1{font-size:26px}h2{font-size:19px}h3{font-size:15px}p,small{color:#526170}section{background:white;border:1px solid #dce2e8;border-radius:12px;padding:20px;margin:18px 0}.metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}.metric{border:1px solid #dce2e8;border-radius:8px;padding:12px;display:grid;gap:6px}.metric strong{font-size:28px}.scroll{overflow:auto}table{border-collapse:collapse;width:100%;text-align:left}th,td{padding:10px;border-bottom:1px solid #e3e8ed}th{font-size:12px;color:#526170}td{font-size:13px;overflow-wrap:anywhere}code{overflow-wrap:anywhere}a{color:#125a98}tr:target{outline:2px solid #16835d;outline-offset:-2px}</style></head>
      <body><h1>UI interaction evidence</h1><p>#{escape(report.fetch("scope"))}. Not total functional or UI coverage.</p><p>Source revision: <code>#{escape(report.fetch("source_revision"))}</code></p><p>Assertion coverage: unknown. Successful recorded clicks do not prove target-specific assertion coverage. No cross-run instance aggregation.</p>#{panels}</body></html>
    HTML
  end
end

