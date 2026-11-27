require "json"
data = JSON.parse(File.read(ARGV.fetch(0)))
puts "## DOM engine / runtime matrix"
puts "| Runtime | Engine | Cold (ms) | Individual (ms) | Batch (ms) | Persistent (ms) | Fresh (ms) | Worker peak RSS (MiB, individual) |"
puts "|---|---|---:|---:|---:|---:|---:|---:|"
data.fetch("results").each do |row|
  if row["error"]
    puts "| #{row["runtime"]} | #{row["engine"]} | FAILED | | | | | |"
    next
  end
  m = row.fetch("medians")
  values = %w[cold_seconds individual_seconds batch_seconds persistent_seconds fresh_seconds].map { |key| (m.fetch(key) * 1000).round(2) }
  rss = m["individual_memory_kib"] ? (m["individual_memory_kib"] / 1024.0).round(1) : "N/A"
  puts "| #{row["runtime"]} | #{row["engine"]} | #{values.join(" | ")} | #{rss} |"
end
puts "\n#{data["iterations"]} click/assert pairs per warm measurement; #{data["isolation_cases"]} remount cases; #{data["repeats"]} repeats. RSS is Linux worker VmHWM, not total suite RAM."
