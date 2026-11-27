// Experimental same-origin Rails asset boot. Only trusted application code.
const { createHash } = require("node:crypto");
const MAX_FILES = 128;
// Bounded, process-local compiled output cache. Never cache HTML or Rack responses.
const compiledModules = new Map();
const MAX_CACHE_ENTRIES = 2;
function digest(source) { return createHash("sha256").update(source).digest("hex"); }
function remember(key, entry) {
  if (Buffer.byteLength(entry.code) > MAX_BYTES) return;
  compiledModules.delete(key);
  compiledModules.set(key, entry);
  while (compiledModules.size > MAX_CACHE_ENTRIES) compiledModules.delete(compiledModules.keys().next().value);
}
const MAX_BYTES = 8 * 1024 * 1024;

// Resolve computed controller imports against a bounded registry of exact pins.
function rewriteDynamicImports(source, imports) {
  const ast = require("acorn").parse(source, { ecmaVersion: "latest", sourceType: "module" });
  const edits = [], stack = [ast];
  let helper = "__domstride_import";
  while (source.includes(helper)) helper += "_";
  while (stack.length) {
    const node = stack.pop();
    if (!node || typeof node !== "object") continue;
    if (node.type === "ImportExpression") {
      if (node.options) throw new Error("UNSUPPORTED_IMPORT_OPTIONS");
      if (node.source.type !== "Literal" || typeof node.source.value !== "string") {
        edits.push({ start: node.start, end: node.start + 6, text: helper });
      }
    }
    for (const value of Object.values(node)) {
      if (Array.isArray(value)) stack.push(...value);
      else if (value && typeof value === "object") stack.push(value);
    }
  }
  if (!edits.length) return source;
  const pins = Object.keys(imports).filter(key => /(?:^|\/)[^/]+_controller$/.test(key) && typeof imports[key] === "string");
  if (pins.length > MAX_FILES) throw new Error("Dynamic controller pin limit exceeded");
  for (const edit of edits.sort((a,b) => b.start-a.start)) source = source.slice(0, edit.start) + edit.text + source.slice(edit.end);
  const cases = pins.map(pin => "case " + JSON.stringify(pin) + ": return import(" + JSON.stringify(pin) + ");").join("\n");
  return "function " + helper + "(specifier) { switch(String(specifier)) { " + cases +
    " default: return Promise.reject(new Error('UNSUPPORTED_DYNAMIC_IMPORT: ' + specifier)); } }\n" + source;
}

async function prepareAssets(html, url, request, warningPolicy = "strict", phases = null, Parser = null) {
  let phaseStart = performance.now();
  const mark = name => {
    if (phases) phases[name] = performance.now() - phaseStart;
    phaseStart = performance.now();
  };
  if (!["strict", "direct-eval"].includes(warningPolicy)) throw new Error("Unknown asset warning policy");
  // Reuse the selected DOM engine; do not load a second jsdom version.
  if (!Parser) throw new Error("Asset parser constructor required");
  mark("assets.load_parser");
  const parsed = new Parser(html, { url });
  mark("assets.parse_html");
  const doc = parsed.window.document;
  const origin = new URL(url).origin;
  const cache = new Map();
  let bytes = 0;
  function sameOrigin(specifier, base = url) {
    const target = new URL(specifier, base);
    if (target.origin !== origin || target.username || target.password) throw new Error("UNSUPPORTED_EXTERNAL_ASSET: " + target.href);
    target.hash = "";
    return target.href;
  }
  async function load(target) {
    if (!cache.has(target)) {
      if (cache.size >= MAX_FILES) throw new Error("Asset file limit exceeded");
      cache.set(target, (async () => {
        const reply = await request(target);
        if (reply.status !== 200) throw new Error("Asset HTTP " + reply.status + ": " + target);
        const mime = Object.entries(reply.headers).find(([name]) => name.toLowerCase() === "content-type")?.[1] || "";
        if (!/^(?:text|application)\/(?:javascript|ecmascript|x-javascript)\b/i.test(mime)) throw new Error("Unsupported JavaScript asset MIME: " + mime);
        bytes += Buffer.byteLength(reply.body);
        if (bytes > MAX_BYTES) throw new Error("Asset byte limit exceeded");
        return { source: reply.body, url: sameOrigin(reply.url) };
      })());
    }
    return cache.get(target);
  }
  try {
    const maps = Array.from(doc.querySelectorAll('script[type="importmap"]'));
    if (maps.length > 1) throw new Error("UNSUPPORTED_MULTIPLE_IMPORTMAPS");
    const map = maps.length ? JSON.parse(maps[0].textContent) : {};
    if (map.scopes && Object.keys(map.scopes).length) throw new Error("UNSUPPORTED_IMPORTMAP_SCOPES");
    const imports = map.imports || {};
    const modules = [];
    const inline = new Map();
    for (const script of Array.from(doc.querySelectorAll("script"))) {
      const type = (script.getAttribute("type") || "").trim().toLowerCase();
      const src = script.getAttribute("src");
      if (type === "module") {
        if (script.hasAttribute("async")) throw new Error("UNSUPPORTED_ASYNC_MODULE");
        if (script.hasAttribute("integrity")) throw new Error("UNSUPPORTED_ASSET_INTEGRITY");
        const key = "domstride:inline:" + modules.length;
        if (src) modules.push(sameOrigin(src));
        else { inline.set(key, script.textContent); modules.push(key); }
        script.remove();
      } else if (src && ["", "text/javascript", "application/javascript"].includes(type)) {
        if (script.hasAttribute("async") || script.hasAttribute("defer")) throw new Error("UNSUPPORTED_ASYNC_OR_DEFER_CLASSIC_SCRIPT");
        if (script.hasAttribute("integrity")) throw new Error("UNSUPPORTED_ASSET_INTEGRITY");
        const { source } = await load(sameOrigin(src));
        // Do not silently alter script strings or HTML parser boundaries.
        if (/<\/script\b/i.test(source)) throw new Error("UNSUPPORTED_CLASSIC_SCRIPT_END_TAG");
        script.removeAttribute("src");
        script.textContent = source;
      }
    }
    mark("assets.discover_scripts");
    let moduleCode = null;
    let importmapCache = null;
    if (modules.length) {
      const enabled = process.env.DOMSTRIDE_IMPORTMAP_CACHE === "1" && warningPolicy === "strict";
      const key = enabled ? digest(JSON.stringify([url, imports, modules, Array.from(inline), warningPolicy])) : null;
      const previous = enabled ? compiledModules.get(key) : null;
      const dependencies = new Map();
      if (previous) {
        let valid = true;
        // Re-fetch every previously resolved dependency through the current Rack session.
        // On a changed graph, let the normal compiler discover the new dependencies.
        for (const [target, hash] of previous.dependencies) {
          try {
            const asset = await load(target);
            if (asset.url !== target || digest(asset.source) !== hash) { valid = false; break; }
          } catch (_) { valid = false; break; }
        }
        if (valid) {
          moduleCode = previous.code;
          importmapCache = "hit";
          remember(key, previous);
        } else compiledModules.delete(key);
        mark("assets.cache_revalidate");
      }
      if (moduleCode === null) {
      if (enabled) importmapCache = "miss";
      const esbuild = require("esbuild");
      mark("assets.load_esbuild");
      const entry = "domstride:entry";
      const bundled = await esbuild.build({
        entryPoints: [entry], bundle: true, write: false, format: "iife", platform: "browser",
        target: "es2022", logLevel: "silent",
        plugins: [{
          name: "domstride-rack-assets",
          setup(build) {
            build.onResolve({ filter: /.*/ }, args => {
              const path = args.path;
              if (path === entry || inline.has(path)) return { path, namespace: "rack-js" };
              const base = args.importer.startsWith("http") ? args.importer : url;
              let resolved = path;
              if (Object.hasOwn(imports, path)) {
                if (typeof imports[path] !== "string") throw new Error("Blocked import: " + path);
                resolved = sameOrigin(imports[path]);
              } else {
                const prefix = Object.keys(imports).filter(key => key.endsWith("/") && path.startsWith(key)).sort((a,b) => b.length-a.length)[0];
                if (prefix) {
                  if (typeof imports[prefix] !== "string" || !imports[prefix].endsWith("/")) throw new Error("Invalid importmap prefix: " + prefix);
                  resolved = sameOrigin(imports[prefix] + path.slice(prefix.length));
                } else if (!/^(?:https?:|\/|\.\.?\/)/.test(path)) throw new Error("UNRESOLVED_IMPORT: " + path);
              }
              return { path: sameOrigin(resolved, base), namespace: "rack-js" };
            });
            build.onLoad({ filter: /.*/, namespace: "rack-js" }, async args => {
              if (args.path === entry) return { contents: modules.map(path => "import " + JSON.stringify(path) + ";").join("\n"), loader: "js" };
              if (inline.has(args.path)) return { contents: rewriteDynamicImports(inline.get(args.path), imports), loader: "js" };
              const asset = await load(args.path);
              if (asset.url !== args.path) throw new Error("UNSUPPORTED_MODULE_REDIRECT: " + args.path);
              if (enabled) dependencies.set(args.path, digest(asset.source));
              return { contents: rewriteDynamicImports(asset.source, imports), loader: "js" };
            });
          }
        }]
      });
      mark("assets.esbuild_with_rack_and_rewrite");
      const fatal = bundled.warnings.filter(warning => warningPolicy !== "direct-eval" || warning.id !== "direct-eval");
      for (const warning of bundled.warnings.filter(w => !fatal.includes(w))) {
        const location = warning.location;
        const site = location ? location.file + ":" + location.line + ":" + location.column : "(unknown location)";
        // Keep the warning visible without logging the source line or executing a different program.
        process.stderr.write("[domstride assets] permitted warning direct-eval at " + site + "\n");
      }
      if (fatal.length) throw new Error("Module bundle warnings: " + fatal.map(w => "[" + w.id + "] " + w.text).join("; "));
      moduleCode = bundled.outputFiles[0].text;
      if (enabled && !bundled.warnings.length) remember(key, { code: moduleCode, dependencies: Array.from(dependencies) });
      }
    }
    mark("assets.validate_warnings");
    const serialized = parsed.serialize();
    mark("assets.serialize_html");
    return { html: serialized, moduleCode, importmapCache };
  } finally {
    parsed.window.close();
    mark("assets.close_parser");
  }
}

module.exports = { prepareAssets };
