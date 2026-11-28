require_relative "application"
require_relative "../inventory_visitor"
require "specdrive"
require "rack/mock"
require "tmpdir"

enabled = ENV.fetch("HERB_SOURCE_ATTRIBUTION", "1") == "1"
root = Rails.root.join("app/views")
candidates = Dir.glob("**/*.html.erb", base: root).sort.flat_map do |relative|
  parsed = Herb.parse(File.read(root.join(relative)), strict: true)
  raise "Static parser diagnostics" unless parsed.value.recursive_errors.empty?
  visitor = InventoryVisitor.new("app/views/#{relative}")
  parsed.visit(visitor)
  visitor.candidates.select { |c| c[:tag] == "button" }
end
index = candidates.to_h { |c| ["#{c[:file]}:#{c[:source][:start][0]}:#{c[:source][:start][1] + 1}", c] }
raise "Expected three distinct source candidates" unless index.size == 3

reports = [false, true].map do |archive|
  Dir.mktmpdir("herb-rails-") do |dir|
    path = nil
    nodes = nil
    url = "/pets?archive=#{archive ? 1 : 0}"
    response = Rack::MockRequest.new(Rails.application).get(url)
    raise "Rails response failed: #{response.status}" unless response.status == 200
    raise "Unexpected partial rendering" unless response.body.scan(/<button\b[^>]*\bclass="open"/).size == 2
    # Use the actual Rails Rack application through Specdrive, not standalone engine eval.
    Specdrive::Session.open(app: Rails.application, engine: "jsdom31", recording_directory: dir, recording_html: false) do |page|
      path = page.recorder.path
      page.visit(url)
      nodes = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("button"), node => {
          let current = node;
          const path = [];
          while (current !== document.documentElement) {
            path.unshift(Array.from(current.parentElement.children).indexOf(current));
            current = current.parentElement;
          }
          return {source: node.getAttribute("data-herb-source"), path};
        })
      JS
      raise "Conditional or partial rendering mismatch" unless nodes.size == (archive ? 4 : 3)
      page.click("article:nth-of-type(2) button.open")
      page.assert_text("#result", "Luna")
    end
    events = File.readlines(File.join(path, "events.jsonl")).map { |line| JSON.parse(line) }
    click = events.find { |event| event["kind"] == "click" }
    raise "Missing successful recorded click" unless click && click["status"] == "passed"
    clicked = nodes.select { |node| node["path"] == click.dig("before", "target_path") }
    raise "Incorrect runtime target" unless clicked.size == 1
    if enabled
      raise "Unmapped source stamps: #{nodes.inspect}" unless nodes.all? { |node| index.key?(node["source"]) }
      repeated = nodes.group_by { |node| node["source"] }.values.select { |group| group.size == 2 }
      raise "Repeated source attribution mismatch" unless repeated.size == 1 && repeated.first.include?(clicked.first)
      raise "Wrong source for recorded click" unless index.fetch(clicked.first["source"])[:file] == "app/views/pets/_card.html.erb"
    else
      raise "Unexpected source stamps with attribution disabled" unless nodes.all? { |node| node["source"].nil? }
      raise "Unexpected source stamps in response" if response.body.include?("data-herb-source")
    end
    {archive_enabled: archive, observed_buttons: nodes.size, distinct_stamps: nodes.map { |node| node["source"] }.compact.uniq.size,
      clicked_source: clicked.first["source"], clicked_instances: clicked.size}
  end
end
puts JSON.pretty_generate(format: "specdrive.research.rails-source-attribution", version: 1,
  rails: Rails.version, herb: Gem.loaded_specs.fetch("herb").version.to_s,
  reactionview: Gem.loaded_specs.fetch("reactionview").version.to_s,
  attribution_enabled: enabled, runs: reports)
