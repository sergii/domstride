require "herb"
require "json"
require "digest"
require "benchmark"

# Research-only inventory. Parse templates without rendering or executing their Ruby.
class InventoryVisitor < Herb::Visitor
  TAGS = %w[form label input textarea select button a].freeze
  attr_reader :candidates

  def initialize(path)
    super()
    @path = path
    @candidates = []
  end

  def visit_html_element_node(node)
    tag = node.tag_name&.value
    if TAGS.include?(tag)
      location = node.location
      start = [location.start.line, location.start.column]
      finish = [location.end.line, location.end.column]
      origin = node.open_tag.is_a?(Herb::AST::HTMLOpenTagNode) ? "literal_html" : "helper_candidate"
      @candidates << {
        candidate_id: Digest::SHA256.hexdigest(JSON.generate([@path, start, tag, origin]))[0, 24],
        file: @path, tag: tag, origin: origin,
        source: {start: start, end: finish},
        evidence: "static_candidate"
      }
    end
    super
  end
end

root = File.join(__dir__, "views")
paths = Dir.glob("**/*.html.erb", base: root).sort
reports = [false, true].map do |helpers|
  files = paths.map do |relative|
    source = File.read(File.join(root, relative))
    result = nil
    samples = Array.new(5) do
      Benchmark.realtime { 100.times { result = Herb.parse(source, strict: true, action_view_helpers: helpers) } }
    end
    visitor = InventoryVisitor.new(relative)
    result.visit(visitor)
    {file: relative, diagnostic_count: result.value.recursive_errors.size,
     candidates: visitor.candidates, seconds_per_100_parses: samples}
  end
  {action_view_helpers: helpers, files: files}
end
puts JSON.pretty_generate(format: "specdrive.research.static-inventory", version: 1,
  parser: Gem.loaded_specs.fetch("herb").version.to_s, coordinates: "Herb line/column, column zero-based, end exclusive",
  reports: reports)
