require "herb"
require "json"
require "digest"

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

