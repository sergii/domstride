require "fileutils"
require "json"
require "specdrive/runtime"

abort "Set isolated SPECDRIVE_RUNTIME_HOME" if ENV.fetch("SPECDRIVE_RUNTIME_HOME", "").empty?
root = File.realpath(File.join(__dir__, "../.."))
cache = Specdrive::Runtime.cache_path
abort "Cache already exists" if File.exist?(cache)
adapter = File.realpath(File.join(__dir__, "install.cjs"))
dependencies = File.realpath(File.join(root, "node_modules"))
FileUtils.mkdir_p(cache)
Specdrive::Runtime::FILES.each { |name| FileUtils.cp(File.join(Specdrive::Runtime.source, name), cache) }
File.symlink(dependencies, File.join(cache, "node_modules"))

worker = File.join(cache, "worker.cjs")
source = File.read(worker)
needle = '    nodes = require("./happy_xpath.cjs").select(message.query, root);'
abort "Worker boundary changed" unless source.scan(needle).length == 1
replacement = <<~JS.chomp
    require(#{JSON.generate(adapter)})(window);
    const result = window.document.evaluate(message.query, root, null, 7, null);
    nodes = Array.from({ length: result.snapshotLength }, (_, i) => result.snapshotItem(i));
JS
File.write(worker, source.sub(needle, replacement))
File.write(File.join(cache, ".ready"), "ready\n")
abort "Staged runtime is incomplete" unless Specdrive::Runtime.ready?(cache)
puts "Experimental worker staged at #{cache}; checkout unchanged"
