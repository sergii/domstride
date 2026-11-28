require "fileutils"
require "json"
require "specdrive/runtime"

abort "Set isolated SPECDRIVE_RUNTIME_HOME" if ENV.fetch("SPECDRIVE_RUNTIME_HOME", "").empty?
root = File.realpath(File.join(__dir__, "../.."))
cache = Specdrive::Runtime.cache_path
abort "Cache already exists" if File.exist?(cache)
candidate = File.realpath(File.join(__dir__, "node_modules/wicked-good-xpath"))
dependencies = File.realpath(File.join(root, "node_modules"))
FileUtils.mkdir_p(cache)
Specdrive::Runtime::FILES.each { |name| FileUtils.cp(File.join(Specdrive::Runtime.source, name), cache) }
File.symlink(dependencies, File.join(cache, "node_modules"))

worker = File.join(cache, "worker.cjs")
source = File.read(worker)
needle = '    if (typeof window.document.evaluate !== "function") throw new Error("UNSUPPORTED_XPATH");'
abort "Worker boundary changed" unless source.scan(needle).length == 1
replacement = <<~JS.chomp
    if (engine === "happy-dom" && typeof window.document.evaluate !== "function") {
      require(#{JSON.generate(candidate)}).install(window);
    }
JS
File.write(worker, source.sub(needle, replacement + "\n" + needle))
File.write(File.join(cache, ".ready"), "ready\n")
abort "Staged runtime is incomplete" unless Specdrive::Runtime.ready?(cache)
puts "Experimental worker staged at #{cache}; checkout unchanged"
