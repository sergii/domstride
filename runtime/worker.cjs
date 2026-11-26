const readline = require("node:readline");
const engine = process.argv[2] || "jsdom";
let window, closeWindow, createWindow;

async function boot() {
  if (engine === "jsdom") {
    const { JSDOM, VirtualConsole } = require("jsdom");
    createWindow = html => {
      const virtualConsole = new VirtualConsole();
      virtualConsole.on("jsdomError", error => process.stderr.write(error.message + "\n"));
      const dom = new JSDOM(html, { runScripts: "dangerously", url: "https://example.test/", virtualConsole });
      return dom.window;
    };
    closeWindow = win => win.close();
  } else if (engine === "happy-dom") {
    const { Window } = await import("happy-dom");
    createWindow = html => {
      const win = new Window({ url: "https://example.test/", settings: {
        enableJavaScriptEvaluation: true,
        disableJavaScriptFileLoading: true,
        disableCSSFileLoading: true
      } });
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
    window = createWindow(message.html);
    return true;
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
  for await (const line of lines) {
    let message;
    try {
      message = JSON.parse(line);
      const value = await execute(message);
      process.stdout.write(JSON.stringify({ id: message.id, ok: true, value }) + "\n");
    } catch (error) {
      process.stdout.write(JSON.stringify({ id: message?.id, ok: false, error: error.message }) + "\n");
    }
  }
  if (window) await closeWindow(window);
}
main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; });
