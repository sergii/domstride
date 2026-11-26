const readline = require("node:readline");
const engine = process.argv[2] || "jsdom";
let window, closeWindow, createWindow;
let requestId = 0;
const pending = new Map();
const send = message => process.stdout.write(JSON.stringify(message) + "\n");
function installBridge(win) {
  win.Headers = globalThis.Headers;
  win.Request = globalThis.Request;
  win.Response = globalThis.Response;
  win.fetch = async (input, init = {}) => {
    const options = { ...init };
    if (options.body instanceof win.URLSearchParams) {
      options.body = new URLSearchParams(options.body.toString());
    }
    const req = new Request(new URL(typeof input === "string" ? input : input.url || input.href, win.location.href), options);
    const body = req.method === "GET" || req.method === "HEAD" ? null : await req.text();
    const id = ++requestId;
    const reply = await new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      send({ kind: "request", request_id: id, url: req.url, method: req.method, headers: Object.fromEntries(req.headers), body });
    });
    const response = new Response(reply.body, { status: reply.status, headers: reply.headers });
    Object.defineProperty(response, "url", { value: reply.url });
    return response;
  };
  if (!win.IntersectionObserver) win.IntersectionObserver = class {
    observe() {} unobserve() {} disconnect() {}
  };
  if (!win.CSS) win.CSS = {};
  if (!win.CSS.escape) win.CSS.escape = value => String(value).replace(/[^a-zA-Z0-9_-]/g, c => "\\" + c);
  if (!win.requestAnimationFrame) win.requestAnimationFrame = callback => win.setTimeout(() => callback(Date.now()), 0);
  if (!win.cancelAnimationFrame) win.cancelAnimationFrame = id => win.clearTimeout(id);
}

async function boot() {
  if (engine === "jsdom") {
    const { JSDOM, VirtualConsole } = require("jsdom");
    createWindow = (html, url, bridge) => {
      const virtualConsole = new VirtualConsole();
      virtualConsole.on("jsdomError", error => process.stderr.write(error.message + "\n"));
      const dom = new JSDOM(html, { runScripts: "dangerously", url, virtualConsole, pretendToBeVisual: true, beforeParse: win => { if (bridge) installBridge(win); } });
      return dom.window;
    };
    closeWindow = win => win.close();
  } else if (engine === "happy-dom") {
    const { Window } = await import("happy-dom");
    createWindow = (html, url, bridge) => {
      const win = new Window({ url, settings: {
        enableJavaScriptEvaluation: true,
        disableJavaScriptFileLoading: true,
        disableCSSFileLoading: true
      } });
      if (bridge) installBridge(win);
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

async function execute(message) {
  if (message.command === "mount") {
    if (window) await closeWindow(window);
    window = createWindow(message.html, message.url || "https://example.test/", message.bridge);
    return true;
  }
  if (message.command === "wait_for_text") {
    const deadline = Date.now() + message.timeout * 1000;
    let actual;
    do {
      actual = window.document.querySelector(message.selector)?.textContent;
      if (actual === message.expected) return true;
      await new Promise(resolve => setTimeout(resolve, 5));
    } while (Date.now() < deadline);
    throw new Error("Timed out waiting for " + message.selector + ": expected " + JSON.stringify(message.expected) + ", got " + JSON.stringify(actual));
  }
  if (message.command === "batch") {
    for (const [index, command] of message.commands.entries()) {
      try { action(command); }
      catch (error) { throw new Error("Batch command " + index + ": " + error.message); }
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
      try { send({ id: message.id, ok: true, value: await execute(message) }); }
      catch (error) { send({ id: message.id, ok: false, error: error.message }); }
    });
  });
  await new Promise(resolve => lines.on("close", resolve));
  await queue;
  if (window) await closeWindow(window);
}
main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; });
