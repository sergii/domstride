# Test the lockfile migration without network access or dependency resolution.
require "tmpdir"
require "open3"

script = File.expand_path("normalize_preview_lock.rb", __dir__)
baseline = <<~LOCK
  PATH
    remote: .
    specs:
      domstride (0.0.1)
        capybara (~> 3.40)

  GEM
    remote: https://rubygems.org/
    specs:
      capybara (3.40.0)
      rack (3.2.0)

  DEPENDENCIES
    domstride!

  CHECKSUMS
    capybara (3.40.0) sha256=abcdef
    domstride (0.0.1)
    rack (3.2.0) sha256=123456

  BUNDLED WITH
     4.0.10
LOCK
expected = baseline.sub("    domstride (", "    specdrive (").sub("  domstride!", "  specdrive!").sub("  domstride (0.0.1)\n  rack (3.2.0) sha256=123456", "  rack (3.2.0) sha256=123456\n  specdrive (0.0.1)")
Dir.mktmpdir do |dir|
  source = File.join(dir, "source.lock")
  output = File.join(dir, "output.lock")
  [ [baseline, expected],
    [expected, expected],
    [baseline.sub(/CHECKSUMS\n[\s\S]*?(?=BUNDLED WITH)/, ""), expected.sub(/CHECKSUMS\n[\s\S]*?(?=BUNDLED WITH)/, "")] ].each do |input, want|
    File.write(source, input)
    log, status = Open3.capture2e(RbConfig.ruby, script, source, output)
    raise log unless status.success?
    raise "Unexpected lockfile normalization" unless File.read(output) == want
  end
  # Use exact line matching to ensure a local digest is not silently rewritten.
  File.write(source, baseline.sub(/^  domstride \(0\.0\.1\)$/, "  domstride (0.0.1) sha256=bad"))
  _, status = Open3.capture2e(RbConfig.ruby, script, source, output)
  raise "Unexpected local digest accepted" if status.success?
end
puts "Lockfile rename fixtures passed"
