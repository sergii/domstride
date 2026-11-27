require "digest"
require "fileutils"
require "tmpdir"
require "json"

module Domstride
  module Runtime
    ROOT = File.expand_path("../..", __dir__)
    FILES = %w[worker.cjs virtual_clock.cjs assets.cjs forms.cjs websocket.cjs media.cjs package.json].freeze

    def self.source
      File.join(ROOT, "runtime")
    end

    def self.cache_path
      digest = Digest::SHA256.new
      FILES.each { |name| digest.update(name).update(File.binread(File.join(source, name))) }
      base = ENV["DOMSTRIDE_RUNTIME_HOME"] || File.join(Dir.home, ".cache", "domstride")
      File.join(File.expand_path(base), digest.hexdigest[0, 24])
    end

    def self.worker_path
      # Use checkout dependencies for development; explicit runtime home always uses the installed cache.
      return File.join(source, "worker.cjs") if !ENV.key?("DOMSTRIDE_RUNTIME_HOME") && File.directory?(File.join(ROOT, "node_modules"))
      path = cache_path
      return File.join(path, "worker.cjs") if ready?(path)
      raise Domstride::Error, "JavaScript dependencies missing. Run domstride setup (requires Node.js and npm)."
    end

    def self.ready?(path)
      File.file?(File.join(path, ".ready")) &&
        FILES.all? { |name| File.file?(File.join(path, name)) } &&
        %w[jsdom jsdom31 happy-dom esbuild acorn].all? { |name| File.file?(File.join(path, "node_modules", name, "package.json")) }
    end

    def self.setup!
      path = cache_path
      FileUtils.mkdir_p(File.dirname(path))
      File.open("#{path}.lock", File::RDWR | File::CREAT, 0600) do |lock|
        lock.flock(File::LOCK_EX)
        return path if ready?(path)
        staging = Dir.mktmpdir("setup-", File.dirname(path))
        begin
          FILES.each { |name| FileUtils.cp(File.join(source, name), staging) }
          ok = system("npm", "install", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund", chdir: staging)
          raise Domstride::Error, "npm install failed; runtime was not installed" unless ok
          File.write(File.join(staging, ".ready"), "ready\n")
          raise Domstride::Error, "Runtime dependencies incomplete" unless ready?(staging)
          FileUtils.rm_rf(path)
          File.rename(staging, path)
        ensure
          FileUtils.rm_rf(staging)
        end
      end
      path
    end
  end
end
