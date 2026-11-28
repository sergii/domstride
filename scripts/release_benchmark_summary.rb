# Report paired ratios; do not turn noisy shared-runner measurements into a pass/fail SLA.
require "json"

root = ARGV.fetch(0)
def median(values)
  sorted = values.sort
  (sorted[(sorted.size - 1) / 2] + sorted[sorted.size / 2]) / 2.0
end
results = %w[jsdom jsdom31].map do |engine|
  pairs = (1..4).map do |round|
    base, head = %w[base head].map do |variant|
      row = JSON.parse(File.read(File.join(root, "#{engine}-#{round}-#{variant}.json")))
      abort "Unexpected benchmark metadata" unless row.values_at("engine", "driver", "iterations", "repeats", "persistence_checked") == [engine, "domstride", 10, 5, true]
      abort "Invalid samples" unless row["samples"].size == 5 && row["samples"].all? { |x| x.is_a?(Numeric) && x.finite? && x.positive? }
      median(row.fetch("samples"))
    end
    {round: round, base_seconds: base, head_seconds: head, ratio: head / base}
  end
  {engine: engine, pairs: pairs, median_head_to_base_ratio: median(pairs.map { |p| p.fetch(:ratio) })}
end
puts JSON.pretty_generate(method: "same-runner alternating AB/BA; fresh process per sample group; no acceptance threshold", results: results)
