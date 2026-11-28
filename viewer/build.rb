# Build an artifact-only preview directory from an explicit allowlist.
require "fileutils"
require "digest"
require "json"

root = File.expand_path("..", __dir__)
abort "Usage: ruby viewer/build.rb NEW_DIRECTORY" unless ARGV.size == 1
destination = File.expand_path(ARGV.fetch(0))
abort "Destination already exists" if File.exist?(destination) || File.symlink?(destination)
version = File.read(File.join(__dir__, "VERSION")).strip
abort "Invalid Viewer version" unless version.match?(/\A\d+\.\d+\.\d+\z/)
mapping = {
  "viewer/VERSION" => "VERSION",
  "viewer/bin/viewer" => "bin/viewer",
  "viewer/README.md" => "README.md",
  "LICENSE" => "LICENSE"
}
%w[
  lib/domstride/namespace.rb lib/domstride/errors.rb lib/domstride/protocol.rb
  lib/domstride/consumer.rb lib/domstride/consumer/report.rb
  lib/domstride/consumer/replay.rb lib/domstride/consumer/video.rb lib/domstride/replay.html
  lib/domstride/documentation/documentation-model.cjs
  lib/domstride/documentation/artifact-validation.cjs
  lib/domstride/documentation/export-docs.cjs
  protocol/case-v1.schema.json protocol/run-v1.schema.json
  protocol/specification-v1.schema.json protocol/compatibility-v1.json
].each { |path| mapping[path] = path }
entries = mapping.sort_by { |_, target| target }.map do |source, target|
  path = File.join(root, source)
  abort "Missing package source: #{source}" unless File.file?(path) && !File.symlink?(path)
  bytes = File.binread(path)
  [target, bytes]
end
FileUtils.mkdir_p(File.dirname(destination))
Dir.mkdir(destination)
entries.each do |target, bytes|
  path = File.join(destination, target)
  FileUtils.mkdir_p(File.dirname(path))
  File.binwrite(path, bytes)
  File.chmod(target == "bin/viewer" ? 0o755 : 0o644, path)
end
manifest = {
  format: "viewer.preview-package", schema_version: 1, version: version,
  files: entries.map { |target, bytes| {file: target, size_bytes: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes)} }
}
File.write(File.join(destination, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
puts destination
