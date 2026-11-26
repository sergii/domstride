const readline = require("node:readline");
const { createHash } = require("node:crypto");
const vm = require("node:vm");
const { VirtualClock } = require("./virtual_clock.cjs");
let pageState;
const turn = () => new Promise(resolve => setImmediate(resolve));
const pause = () => new Promise(resolve => setTimeout(resolve, 1));
let bundleEntry = null;
let bundleOutcome = null;
const BUNDLE_MARKER = '<script data-domstride-cache="bundle"></script>';
const MAX_BUNDLE_BYTES = 8 * 1024 * 1024;
const engine = process.argv[2] || "jsdom";
let window, closeWindow, createWindow;
const javascriptErrors = [];
const errorListeners = new Set();
class JavaScriptFailure extends Error {}
function reportJavaScript(error, source) {
  const message = error?.stack || error?.message || String(error);
  if (!javascriptErrors.some(item => item.message === message)) {
    javascriptErrors.push({ source, message });
    for (const listener of [...errorListeners]) listener();
  }
}
function checkJavaScript() {
  if (!javascriptErrors.length) return;
  const errors = javascriptErrors.splice(0);
  throw new JavaScriptFailure(errors.map(e => "[" + e.source + "] " + e.message).join("\n"));
}
function installErrorCapture(win) {
  win.addEventListener("error", event => {
    reportJavaScript(event.error || event.message || "Window error", "window.error");
  });
  win.addEventListener("unhandledrejection", event => {
    reportJavaScript(event.reason, "window.unhandledrejection");
  });
  // Keep plain console messages diagnostic, but catch Error objects logged by frameworks.
  const originalError = win.console.error.bind(win.console);
  win.console.error = (...args) => {
    for (const arg of args) {
      if (arg && typeof arg === "object" && typeof arg.stack === "string") {
        reportJavaScript(arg, "console.error");
      }
    }
    originalError(...args);
  };
}
process.on("unhandledRejection", reason => reportJavaScript(reason, "process.unhandledRejection"));
let nextHandle = 0;
let handles = new Map(), identities = new WeakMap();
function handle(node) {
  if (!identities.has(node)) {
    const id = ++nextHandle;
    identities.set(node, id);
    handles.set(id, node);
  }
  return identities.get(node);
}
function resolveHandle(id) {
  const node = handles.get(id);
  if (!node || !node.isConnected || node.ownerDocument !== window.document) throw new Error("STALE_ELEMENT");
  return node;
}
function visible(node) {
  for (let n = node; n && n.nodeType === 1; n = n.parentElement) {
    const style = window.getComputedStyle(n);
    if (n.hidden || style.display === "none" || ["hidden", "collapse"].includes(style.visibility) || n.type === "hidden") return false;
  }
  return true;
}
function visibleText(node) {
  if (node.nodeType === 3) return node.nodeValue;
  if (node.nodeType !== 1 || !visible(node) || ["SCRIPT", "STYLE", "TEMPLATE"].includes(node.tagName)) return "";
  return Array.from(node.childNodes, visibleText).join("");
}
function findHandles(message) {
  const root = message.root ? resolveHandle(message.root) : window.document;
  let nodes;
  if (message.kind_of_query === "css") {
    nodes = Array.from(root.querySelectorAll(message.query));
  } else {
    if (typeof window.document.evaluate !== "function") throw new Error("UNSUPPORTED_XPATH");
    const result = window.document.evaluate(message.query, root, null, 7, null);
    nodes = Array.from({ length: result.snapshotLength }, (_, i) => result.snapshotItem(i));
  }
  if (!message.prefetch) return nodes.map(handle);
  // Capybara owns filtering, matching and retry semantics. Return only initial metadata.
  return nodes.map(node => {
    const row = { id: handle(node), tag_name: node.tagName.toLowerCase() };
    if (message.uses_visibility) row.visible = visible(node);
    return row;
  });
}
function nodeAction(message) {
  const node = resolveHandle(message.handle);
  switch (message.operation) {
    case "all_text": return node.textContent;
    case "visible_text": return visibleText(node);
    case "attribute": {
      const name = message.name;
      if (["checked", "selected", "disabled", "multiple", "readonly"].includes(name)) return node[name === "readonly" ? "readOnly" : name] ? "true" : null;
      if (name === "value" && "value" in node) return node.value;
      return node.getAttribute(name);
    }
    case "value": return node.value ?? null;
    case "tag_name": return node.tagName.toLowerCase();
    case "visible": return visible(node);
    case "disabled": return node.matches(":disabled");
    case "checked": return Boolean(node.checked);
    case "selected": return Boolean(node.selected);
    case "click": node.click(); return true;
    case "set":
      if (node.tagName === "INPUT" && ["checkbox", "radio"].includes(node.type)) {
        if (typeof message.value !== "boolean" || (node.type === "radio" && !message.value)) throw new Error("UNSUPPORTED_SET");
        if (node.matches(":disabled")) throw new Error("Element is disabled");
        // Preserve native activation events and radio-group behavior.
        if (node.checked !== message.value) node.click();
        return true;
      }
      if (!["INPUT", "TEXTAREA"].includes(node.tagName) || ["checkbox", "radio", "file", "button", "submit"].includes(node.type)) throw new Error("UNSUPPORTED_SET");
      if (node.disabled || node.readOnly) throw new Error("Element is disabled or readonly");
      node.value = String(message.value);
      node.dispatchEvent(new window.Event("input", { bubbles: true }));
      node.dispatchEvent(new window.Event("change", { bubbles: true }));
      return true;
    default: throw new Error("Unsupported node operation");
  }
}
let requestId = 0;
const pending = new Map();
const send = message => process.stdout.write(JSON.stringify(message) + "\n");
function rackRequest(url, method, headers = {}, body = null, redirect = "follow") {
  const id = ++requestId;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    send({ kind: "request", request_id: id, url, method, headers, body, redirect });
  });
}
function installBridge(win, state) {
  win.Headers = globalThis.Headers;
  win.Request = globalThis.Request;
  win.Response = globalThis.Response;
  win.fetch = async (input, init = {}) => {
    state.fetches += 1; state.activity += 1;
    try {
    const options = { ...init };
    if (options.body instanceof win.URLSearchParams) {
      options.body = new URLSearchParams(options.body.toString());
    }
    const req = new Request(new URL(typeof input === "string" ? input : input.url || input.href, win.location.href), options);
    const body = req.method === "GET" || req.method === "HEAD" ? null : await req.text();
    const reply = await rackRequest(req.url, req.method, Object.fromEntries(req.headers), body, req.redirect);
    const response = new Response(req.method === "HEAD" || [204, 205, 304].includes(reply.status) ? null : reply.body, { status: reply.status, headers: reply.headers });
    Object.defineProperty(response, "url", { value: reply.url });
    Object.defineProperty(response, "redirected", { value: Boolean(reply.redirected) });
    return response;
    } finally { state.fetches -= 1; state.activity += 1; }
  };
  if (!win.IntersectionObserver) win.IntersectionObserver = class {
    observe() {} unobserve() {} disconnect() {}
  };
  if (!win.CSS) win.CSS = {};
  if (!win.CSS.escape) win.CSS.escape = value => String(value).replace(/[^a-zA-Z0-9_-]/g, c => "\\" + c);
  if (!win.requestAnimationFrame) win.requestAnimationFrame = callback => win.setTimeout(() => callback(Date.now()), 0);
  if (!win.cancelAnimationFrame) win.cancelAnimationFrame = id => win.clearTimeout(id);
}

function prepareWindow(win, bridge, state) {
  installErrorCapture(win);
  if (bridge) installBridge(win, state);
  if (state.mode === "virtual") state.clock = new VirtualClock(win, state.epoch);
  // Observe before application scripts, including parser-time DOM changes.
  if (state.tracked || state.clock) {
    state.observer = new win.MutationObserver(() => { state.activity += 1; });
    state.observer.observe(win.document, { subtree: true, childList: true, characterData: true, attributes: true });
  }
}

function budget() {
  return { callbacks: 0, deadline: performance.now() + 3000 };
}

function ensureBudget(b) {
  if (performance.now() >= b.deadline) throw new Error("Settling deadline exceeded");
}

async function drainDue(state, b) {
  let timer;
  while (state.clock && (timer = state.clock.next()) && timer.due <= state.clock.now) {
    ensureBudget(b);
    if (++b.callbacks > 1000) throw new Error("Virtual timer callback limit exceeded");
    try { state.clock.fire(timer); }
    catch (error) { reportJavaScript(error, "virtual.timer"); }
    await turn();
    checkJavaScript();
  }
}

async function settle(state, b = budget()) {
  if (!state) throw new Error("No document mounted");
  let quiet = 0;
  while (quiet < 3) {
    ensureBudget(b);
    const activity = state.activity;
    await drainDue(state, b);
    await turn();
    checkJavaScript();
    const due = state.clock?.next();
    const busy = state.fetches > 0 || (due && due.due <= state.clock.now);
    quiet = !busy && activity === state.activity ? quiet + 1 : 0;
    if (state.fetches > 0) await pause();
  }
  return true;
}

async function advance(state, milliseconds, b = budget()) {
  if (!state?.clock) throw new Error("Virtual clock is not enabled");
  if (!Number.isSafeInteger(milliseconds) || milliseconds < 0 || !Number.isSafeInteger(state.clock.now + milliseconds)) throw new Error("Invalid time advance");
  const target = state.clock.now + milliseconds;
  await settle(state, b);
  let next;
  while ((next = state.clock.next()) && next.due <= target) {
    state.clock.now = next.due;
    await settle(state, b);
  }
  state.clock.now = target;
  await settle(state, b);
  return true;
}

async function waitVirtual(message) {
  const state = pageState;
  const b = budget();
  const duration = Math.round(message.timeout * 1000);
  if (!Number.isSafeInteger(duration) || duration < 0) throw new Error("Invalid wait timeout");
  const target = state.clock.now + duration;
  await settle(state, b);
  for (;;) {
    checkJavaScript();
    const actual = window.document.querySelector(message.selector)?.textContent;
    if (actual === message.expected) return true;
    const next = state.clock.next();
    if (next && next.due <= target) {
      state.clock.now = next.due;
      await settle(state, b);
    } else {
      state.clock.now = target;
      await settle(state, b);
      if (window.document.querySelector(message.selector)?.textContent === message.expected) return true;
      throw new Error("Timed out waiting for " + message.selector + " in virtual time");
    }
  }
}

async function boot() {
  if (engine === "jsdom" || engine === "jsdom31") {
    const { JSDOM, VirtualConsole } = require(engine);
    createWindow = (html, url, bridge, compiledBundle, state) => {
      const virtualConsole = new VirtualConsole();
      virtualConsole.on("jsdomError", error => reportJavaScript(error.cause || error.detail || error, "jsdom"));
      const dom = new JSDOM(html, { runScripts: "dangerously", url, virtualConsole, pretendToBeVisual: true, beforeParse: win => prepareWindow(win, bridge, state) });
      if (compiledBundle) {
        try { compiledBundle.runInContext(dom.getInternalVMContext()); }
        catch (error) { reportJavaScript(error, "compiled.bundle"); }
      }
      return dom.window;
    };
    closeWindow = win => win.close();
  } else if (engine === "happy-dom") {
    const { Window } = await import("happy-dom");
    createWindow = (html, url, bridge, compiledBundle, state) => {
      const win = new Window({ url, settings: {
        enableJavaScriptEvaluation: true,
        disableJavaScriptFileLoading: true,
        disableCSSFileLoading: true
      } });
      prepareWindow(win, bridge, state);
      win.document.write(html);
      return win;
    };
    closeWindow = win => win.happyDOM.close();
  } else {
    throw new Error("Unsupported DOM engine: " + engine);
  }
}

function element(selector) {
  if (!window) throw new Error("No document mounted");
  const node = window.document.querySelector(selector);
  if (!node) throw new Error("Element not found: " + selector);
  return node;
}

function action(message) {
  switch (message.command) {
    case "check_javascript": checkJavaScript(); return true;
    case "find_handles": return findHandles(message);
    case "node_action": return nodeAction(message);
    case "current_url": return window.location.href;
    case "html": return window.document.documentElement.outerHTML;
    case "click": element(message.selector).click(); return true;
    case "fill": {
      const node = element(message.selector);
      node.value = message.value;
      node.dispatchEvent(new window.Event("input", { bubbles: true }));
      node.dispatchEvent(new window.Event("change", { bubbles: true }));
      return true;
    }
    case "text": return element(message.selector).textContent;
    case "count":
      if (!window) throw new Error("No document mounted");
      return window.document.querySelectorAll(message.selector).length;
    case "assert_text": {
      const actual = element(message.selector).textContent;
      if (actual !== message.expected) throw new Error("Expected " + JSON.stringify(message.expected) + ", got " + JSON.stringify(actual));
      return true;
    }
    default: throw new Error("Unknown command: " + message.command);
  }
}

function observeText(message) {
  return new Promise((resolve, reject) => {
    let observer, timer;
    function finish(error) {
      observer?.disconnect();
      clearTimeout(timer);
      errorListeners.delete(check);
      if (error) reject(error); else resolve(true);
    }
    function check() {
      try {
        checkJavaScript();
        if (window.document.querySelector(message.selector)?.textContent === message.expected) finish();
      } catch (error) { finish(error); }
    }
    observer = new window.MutationObserver(check);
    observer.observe(window.document, { subtree: true, childList: true, characterData: true, attributes: true });
    errorListeners.add(check);
    timer = setTimeout(() => {
      try {
        checkJavaScript();
        const actual = window.document.querySelector(message.selector)?.textContent;
        if (actual === message.expected) finish();
        else finish(new Error("Timed out waiting for " + message.selector + ": expected " + JSON.stringify(message.expected) + ", got " + JSON.stringify(actual)));
      } catch (error) { finish(error); }
    }, message.timeout * 1000);
    check();
  });
}

function prepareBundle(message) {
  bundleOutcome = null;
  if (!message.bundle) return { html: message.html };
  const { digest, source, mode } = message.bundle;
  if (!/^[a-f0-9]{64}$/.test(digest) || !["source", "compiled"].includes(mode)) throw new Error("Invalid bundle metadata");
  if (mode === "compiled" && !["jsdom", "jsdom31"].includes(engine)) throw new Error("Compiled bundles require jsdom");
  const endMarker = message.html.lastIndexOf(BUNDLE_MARKER);
  if (endMarker === -1 || !/^\s*<\/body>\s*<\/html>\s*$/i.test(message.html.slice(endMarker + BUNDLE_MARKER.length))) throw new Error("Missing final bundle marker");
  if (source !== null && source !== undefined) {
    if (typeof source !== "string" || Buffer.byteLength(source) > MAX_BUNDLE_BYTES) throw new Error("Invalid bundle size");
    if (createHash("sha256").update(source).digest("hex") !== digest) throw new Error("Bundle digest mismatch");
    // Single-entry cache, bounded by source size and scoped to this worker.
    if (bundleEntry?.digest !== digest || bundleEntry.mode !== mode) {
      const compiled = mode === "compiled" ? new vm.Script(source, { filename: "domstride-bundle-" + digest.slice(0, 12) + ".js" }) : null;
      bundleEntry = { digest, mode, source, compiled };
    }
    bundleOutcome = "miss";
  } else {
    if (!bundleEntry || bundleEntry.digest !== digest || bundleEntry.mode !== mode) throw new Error("Bundle cache miss");
    bundleOutcome = "hit";
  }
  if (mode === "compiled") return { html: message.html, compiled: bundleEntry.compiled };
  // Restore the exact classic script before HTML parsing.
  const insertion = endMarker + BUNDLE_MARKER.indexOf("</script>");
  return { html: message.html.slice(0, insertion) + bundleEntry.source + message.html.slice(insertion) };
}

function scriptValue(value, seen = new Set()) {
  if (value === undefined || value === null) return null;
  if (typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "object" || seen.has(value)) throw new Error("UNSUPPORTED_SCRIPT_RESULT");
  seen.add(value);
  let result;
  if (Array.isArray(value)) result = Array.from(value, item => scriptValue(item, seen));
  else if (Object.getPrototypeOf(value) === window.Object.prototype || Object.getPrototypeOf(value) === null) {
    result = Object.fromEntries(Object.entries(value).map(([key, item]) => [key, scriptValue(item, seen)]));
  } else throw new Error("UNSUPPORTED_SCRIPT_RESULT");
  seen.delete(value);
  return result;
}

function scriptCommand(message) {
  if (!window) throw new Error("No document mounted");
  const args = message.arguments.map(arg => arg.kind === "element" ? resolveHandle(arg.handle) : window.JSON.parse(JSON.stringify(arg.value)));
  const source = message.command === "evaluate_script" ? "return (" + message.script.replace(/;\s*$/, "") + "\n);" : message.script;
  let value;
  try { value = window.Function(source).apply(window, args); }
  catch (error) { throw new JavaScriptFailure(error.stack || error.message); }
  if (value && typeof value.then === "function") {
    Promise.resolve(value).catch(() => {});
    throw new Error("UNSUPPORTED_ASYNC_SCRIPT_RESULT");
  }
  return message.command === "evaluate_script" ? scriptValue(value) : true;
}

async function execute(message) {
  if (["execute_script", "evaluate_script"].includes(message.command)) return scriptCommand(message);
  if (message.command === "mount") {
    const prepared = prepareBundle(message);
    let moduleCode;
    if (message.assets === "bundle" && message.bridge) {
      const { prepareAssets } = require("./assets.cjs");
      const resolved = await prepareAssets(prepared.html, message.url, url => rackRequest(url, "GET"));
      prepared.html = resolved.html;
      moduleCode = resolved.moduleCode;
    }
    if (window) {
      pageState?.observer?.disconnect();
      pageState?.clock?.timers.clear();
      await closeWindow(window);
    }
    handles.clear(); identities = new WeakMap();
    pageState = { mode: message.clock || "real", tracked: message.settling === "tracked", epoch: message.clock_epoch_ms, fetches: 0, activity: 0 };
    window = createWindow(prepared.html, message.url || "https://example.test/", message.bridge, prepared.compiled, pageState);
    if (moduleCode) {
      try { window.eval(moduleCode); }
      catch (error) { reportJavaScript(error, "module.bundle"); }
    }
    return true;
  }
  if (message.command === "settle") return settle(pageState);
  if (message.command === "advance_time") return advance(pageState, message.milliseconds);
  if (message.command === "clock_state") return pageState?.clock ? { now_ms: pageState.clock.now, epoch_ms: pageState.clock.epoch, pending_timers: pageState.clock.timers.size } : null;
  if (message.command === "wait_for_text") {
    if (pageState?.clock) return waitVirtual(message);
    if (message.strategy === "observer") return observeText(message);
    if (message.strategy !== "poll") throw new Error("Unsupported wait strategy: " + message.strategy);
    const deadline = Date.now() + message.timeout * 1000;
    let actual;
    do {
      checkJavaScript();
      actual = window.document.querySelector(message.selector)?.textContent;
      if (actual === message.expected) return true;
      await new Promise(resolve => setTimeout(resolve, 5));
    } while (Date.now() < deadline);
    throw new Error("Timed out waiting for " + message.selector + ": expected " + JSON.stringify(message.expected) + ", got " + JSON.stringify(actual));
  }
  if (message.command === "batch") {
    for (const [index, command] of message.commands.entries()) {
      try {
        action(command);
        if (message.settling === "tracked") await settle(pageState);
        checkJavaScript();
      } catch (error) {
        const ErrorClass = error instanceof JavaScriptFailure ? JavaScriptFailure : Error;
        throw new ErrorClass("Batch command " + index + ": " + error.message);
      }
    }
    return true;
  }
  return action(message);
}

async function main() {
  await boot();
  const lines = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
  let queue = Promise.resolve();
  lines.on("line", line => {
    let message;
    try { message = JSON.parse(line); } catch (error) { send({ ok: false, error: error.message }); return; }
    if (message.kind === "response") {
      const task = pending.get(message.request_id);
      if (task) {
        pending.delete(message.request_id);
        if (message.ok) task.resolve(message); else task.reject(new Error(message.error));
      }
      return;
    }
    queue = queue.then(async () => {
      bundleOutcome = null;
      const start = message.profile ? performance.now() : null;
      const timing = () => start === null ? {} : { worker_ms: performance.now() - start };
      try {
        checkJavaScript();
        const value = await execute(message);
        // One event-loop checkpoint, not a deterministic timer/network drain.
        const mutating = ["mount", "click", "fill", "execute_script", "evaluate_script"].includes(message.command) || (message.command === "node_action" && ["click", "set"].includes(message.operation));
        if (message.settling === "tracked" && mutating) await settle(pageState);
        else await turn();
        checkJavaScript();
        send({ id: message.id, ok: true, value, ...(bundleOutcome ? { bundle_cache: bundleOutcome } : {}), ...timing() });
      } catch (error) {
        // Prefer a captured JavaScript exception over a generic action failure.
        if (javascriptErrors.length) {
          try { checkJavaScript(); } catch (captured) { error = captured; }
        }
        send({ id: message.id, ok: false, error: error.message, error_type: error instanceof JavaScriptFailure ? "javascript" : "command", ...timing() });
      }
    });
  });
  await new Promise(resolve => lines.on("close", resolve));
  await queue;
  if (window) { pageState?.observer?.disconnect(); pageState?.clock?.timers.clear(); await closeWindow(window); }
}
main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; });
