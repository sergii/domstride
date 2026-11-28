require_relative "inventory_visitor"
require "herb/engine"
require "herb/engine/visitors/source_attribution_visitor"
require "specdrive"
require "tmpdir"

ROOT = File.join(__dir__, "runtime_views")
class SyntheticRenderer
  def initialize(root, archive:)
    @root = root
    @can_archive = archive
    @pets = %w[Milo Luna]
  end

  def render(relative, context = binding)
    path = File.join(@root, relative)
    engine = Herb::Engine.new(File.read(path), filename: path, project_path: @root, escape: true,
      visitors: [Herb::Engine::SourceAttributionVisitor.new])
    # Only checked-in synthetic fixtures, never evaluate scanned application templates.
    eval(engine.src, context, path)
  end

  def render_card(pet)
    render("pets/_card.html.erb", binding)
  end
end

candidates = Dir.glob("**/*.html.erb", base: ROOT).sort.flat_map do |relative|
  result = Herb.parse(File.read(File.join(ROOT, relative)), strict: true)
  raise "Unexpected parser diagnostics" unless result.value.recursive_errors.empty?
  visitor = InventoryVisitor.new(relative)
  result.visit(visitor)
  visitor.candidates
end
# Source stamps have one-based columns; the AST uses zero-based columns.
index = candidates.group_by { |c| "#{c[:file]}:#{c[:source][:start][0]}:#{c[:source][:start][1] + 1}" }
raise "Fixture source collision" unless index.values.all? { |rows| rows.size == 1 }

reports = [false, true].map do |archive|
  Dir.mktmpdir("herb-map-") do |dir|
    recorder_path = nil
    observed = nil
    Specdrive::Session.open(engine: "jsdom31", recording_directory: dir, recording_html: false) do |page|
      recorder_path = page.recorder.path
      rendered = SyntheticRenderer.new(ROOT, archive: archive).render("pets/index.html.erb")
      # Synthetic fixture only: retain diagnostic markup if partial composition fails.
      unless rendered.scan(/<button\b[^>]*\bclass="open"/).size == 2
        warn "Synthetic rendered HTML:\n#{rendered}"
        raise "Partial composition failed before DOM mount"
      end
      page.mount_html("<!doctype html><html><body>#{rendered}</body></html>")
      page.execute_script(<<~JS)
        document.querySelector("#dynamic").innerHTML = '<button id="dynamic-button">Dynamic</button>';
        const fake = document.createElement("button");
        fake.id = "unknown";
        fake.setAttribute("data-herb-source", "unknown.html.erb:1:1");
        document.querySelector("#dynamic").append(fake);
      JS
      observed = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("button"), node => {
          const path = [];
          let current = node;
          while (current !== document.documentElement) {
            path.unshift(Array.from(current.parentElement.children).indexOf(current));
            current = current.parentElement;
          }
          return {tag: node.localName, source: node.getAttribute("data-herb-source"), path};
        });
      JS
      partial_count = page.count("button.open")
      raise "Unexpected repeated partial count: #{partial_count}" unless partial_count == 2
      page.click("article:nth-of-type(2) button.open")
      page.assert_text("#result", "Luna")
    end
    events = File.readlines(File.join(recorder_path, "events.jsonl")).map { |line| JSON.parse(line) }
    click = events.find { |event| event["kind"] == "click" }
    raise "Missing recorded click" unless click && click["status"] == "passed"
    mapped = observed.map do |node|
      matches = (index[node["source"]] || []).select { |c| c[:tag] == node["tag"] }
      status = if node["source"].nil?
        "unstamped"
      elsif matches.size == 1
        "source_matched"
      elsif matches.empty?
        "unresolved_stamp"
      else
        "ambiguous"
      end
      {path: node["path"], source: node["source"], candidate_ids: matches.map { |c| c[:candidate_id] },
       status: status, clicked: node["path"] == click.dig("before", "target_path")}
    end
    matched = mapped.select { |m| m[:status] == "source_matched" }
    clicked = matched.select { |m| m[:clicked] }
    raise "Expected one recorded mapped instance" unless clicked.size == 1
    open = candidates.find { |c| c[:file] == "pets/_card.html.erb" && c[:tag] == "button" }
    instances = matched.select { |m| m[:candidate_ids] == [open[:candidate_id]] }
    raise "Repeated partial attribution mismatch" unless instances.size == 2 && instances.count { |m| m[:clicked] } == 1
    raise "Expected unmatched dynamic button" unless mapped.count { |m| m[:status] == "unstamped" } == 1
    raise "Expected unresolved stamp" unless mapped.count { |m| m[:status] == "unresolved_stamp" } == 1
    raise "Unexpected matched count" unless matched.size == (archive ? 4 : 3)
    button_candidates = candidates.select { |c| c[:tag] == "button" }
    report = button_candidates.map do |candidate|
      nodes = matched.select { |m| m[:candidate_ids] == [candidate[:candidate_id]] }
      {candidate_id: candidate[:candidate_id], rendered_instances: nodes.size, clicked_instances: nodes.count { |m| m[:clicked] },
       status: nodes.empty? ? "not_observed_in_snapshot" : nodes.any? { |m| m[:clicked] } ? "observed_interaction" : "rendered_not_clicked"}
    end
    {archive_enabled: archive, candidates: button_candidates, nodes: mapped, source_summary: report}
  end
end
puts JSON.pretty_generate(format: "specdrive.research.source-mapping", version: 1,
  source_revision: ENV.fetch("GITHUB_SHA", "local-unversioned"),
  scope: "synthetic mounted page and recorded click, not full UI coverage", runs: reports)
