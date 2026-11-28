# Compare full lockfile content, ignoring only order in flat set-valued sections.
# Preserve sources, versions, dependency edges, platforms, checksums and Bundler version.
require "fileutils"

def canonical_lock(text)
  sections = text.split(/(?=^[A-Z][A-Z ]*\n)/)
  sections.map do |section|
    header, *rows = section.lines
    if %w[DEPENDENCIES CHECKSUMS PLATFORMS].include?(header&.strip)
      entries = rows.reject { |row| row.strip.empty? }
      raise "Unexpected nested or duplicate entry in #{header.strip}" unless entries.all? { |row| row.match?(/\A  \S[^\n]*\n?\z/) } && entries.uniq.size == entries.size
      header + entries.sort.join + "\n"
    else
      section
    end
  end.join
end

if $PROGRAM_NAME == __FILE__
  base, head, out = ARGV
  abort "Usage: compare_preview_locks.rb BASE HEAD OUTPUT_DIRECTORY" unless ARGV.size == 3
  a = canonical_lock(File.read(base))
  b = canonical_lock(File.read(head))
  File.write(File.join(out, "base-comparable.lock"), a)
  File.write(File.join(out, "head-comparable.lock"), b)
  unless a == b
    system("diff", "-u", File.join(out, "base-comparable.lock"), File.join(out, "head-comparable.lock"))
    abort "Dependency graph or lockfile metadata changed; refusing benchmark"
  end
  puts "Lockfiles match after flat section ordering normalization"
end
