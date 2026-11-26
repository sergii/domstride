const { JSDOM, VirtualConsole } = require("jsdom");
const readline = require("node:readline");
let dom;

function element(selector) {
  if (!dom) throw new Error("No document mounted");
  const node = dom.window.document.querySelector(selector);
  if (!node) throw new Error("Element not found: " + selector);
  return node;
}

function execute(message) {
  switch (message.command) {
    case "mount": {
      dom?.window.close();
      const virtualConsole = new VirtualConsole();
      virtualConsole.on("jsdomError", error => process.stderr.write(error.message + "\n"));
      dom = new JSDOM(message.html, { runScripts: "dangerously", url: "https://example.test/", virtualConsole });
      return true;
    }
    case "click":
      element(message.selector).click();
      return true;
    case "text":
      return element(message.selector).textContent;
    case "count":
      if (!dom) throw new Error("No document mounted");
      return dom.window.document.querySelectorAll(message.selector).length;
    default:
      throw new Error("Unknown command: " + message.command);
  }
}

const lines = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
lines.on("line", line => {
  let message;
  try {
    message = JSON.parse(line);
    const value = execute(message);
    process.stdout.write(JSON.stringify({ id: message.id, ok: true, value }) + "\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id: message?.id, ok: false, error: error.message }) + "\n");
  }
});
lines.on("close", () => dom?.window.close());
