require_relative "inventory_visitor"
require "benchmark"

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
