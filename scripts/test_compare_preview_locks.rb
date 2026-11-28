require_relative "compare_preview_locks"

base = <<~LOCK
  PATH
    remote: .
    specs:
      specdrive (0.0.1)
        rack (~> 3.0)

  GEM
    remote: https://rubygems.org/
    specs:
      rack (3.2.0)

  PLATFORMS
    ruby
    x86_64-linux

  DEPENDENCIES
    specdrive!
    rack (~> 3.0)

  CHECKSUMS
    rack (3.2.0) sha256=abcdef
    specdrive (0.0.1)

  BUNDLED WITH
     4.0.10
LOCK
reordered = base.sub("  specdrive!\n  rack (~> 3.0)", "  rack (~> 3.0)\n  specdrive!")
raise "Order-only change rejected" unless canonical_lock(base) == canonical_lock(reordered)
[
  base.sub("rack (3.2.0)", "rack (3.2.1)"),
  base.sub("sha256=abcdef", "sha256=123456"),
  base.sub("    rack (~> 3.0)", "    rack (~> 3.1)"),
  base.sub("https://rubygems.org/", "https://example.invalid/"),
  base.sub("4.0.10", "4.0.11")
].each do |changed|
  raise "Dependency or metadata drift accepted" if canonical_lock(base) == canonical_lock(changed)
end
puts "Lockfile comparison fixtures passed"
