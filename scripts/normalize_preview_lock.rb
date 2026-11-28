# Seed the candidate with baseline resolution; do not relax dependency comparison.
source, destination = ARGV
abort "Usage: ruby normalize_preview_lock.rb SOURCE DESTINATION" unless source && destination && ARGV.length == 2
lock = File.read(source)
old_spec = /^    domstride \(/
old_dep = /^  domstride!$/
if lock.match?(old_spec) || lock.match?(old_dep)
  abort "Unexpected baseline root gem declaration" unless lock.scan(old_spec).length == 1 && lock.scan(old_dep).length == 1
  lock = lock.sub(old_spec, "    specdrive (").sub(old_dep, "  specdrive!")
  # Bundler 4 records local path gems in CHECKSUMS without a digest.
  # Preserve every external checksum and maintain sorted checksum entries.
  if lock.match?(/^CHECKSUMS\n/)
    lock = lock.sub(/^CHECKSUMS\n((?:  [^\n]+\n)+)/) do
      entries = Regexp.last_match(1).lines
      local = entries.select { |line| line.match?(/\A  domstride \([^)]+\)\n\z/) }
      abort "Expected one digest-free local gem checksum entry" unless local.size == 1
      entries = entries.map { |line| line == local.first ? line.sub("  domstride (", "  specdrive (") : line }
      "CHECKSUMS\n" + entries.sort.join
    end
    abort "Missing renamed local checksum entry" unless lock.match?(/^  specdrive \([^)]+\)$/)
  end
end
abort "Missing canonical root gem" unless lock.scan(/^    specdrive \(/).length == 1 && lock.scan(/^  specdrive!$/).length == 1
File.write(destination, lock)
