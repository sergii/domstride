# Seed the candidate with baseline resolution; do not relax dependency comparison.
source, destination = ARGV
abort "Usage: ruby normalize_preview_lock.rb SOURCE DESTINATION" unless source && destination && ARGV.length == 2
lock = File.read(source)
# Rename only the local root gem's declaration and direct dependency entry.
old_spec = /^    domstride \(/
old_dep = /^  domstride!$/
if lock.match?(old_spec) || lock.match?(old_dep)
  abort "Unexpected baseline root gem declaration" unless lock.scan(old_spec).length == 1 && lock.scan(old_dep).length == 1
  lock = lock.sub(old_spec, "    specdrive (").sub(old_dep, "  specdrive!")
end
abort "Missing canonical root gem" unless lock.scan(/^    specdrive \(/).length == 1 && lock.scan(/^  specdrive!$/).length == 1
File.write(destination, lock)
