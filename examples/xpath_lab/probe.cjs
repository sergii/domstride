const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { performance } = require("node:perf_hooks");
const { JSDOM } = require("jsdom");
const installXPath = require("./install.cjs");

const fixture = fs.readFileSync(path.join(__dirname, "../locator_compatibility/fixture.html"), "utf8");
const queries = [
  ["explicit label", "//label[@for='pet-name']", null, ["pet-name"]],
  ["native input", "//input[@name='pet_name']", null, ["pet-name"]],
  ["wrapping label", "//label[normalize-space(.)='Notes']/textarea", null, ["pet-notes"]],
  ["attribute lookup", "//input[@data-testid='adoption-name']", null, ["localized"]],
  ["scoped descendants", ".//input[@data-testid='duplicate-name']", "#second", ["second-name"]],
  ["union dedup and order", "//input[@id='second-name'] | //input[@data-testid='duplicate-name']", null, ["first-name", "second-name"]],
  ["text predicate", "//button[normalize-space(.)='Save']", null, ["save"]],
  ["ancestor axis", "//textarea/ancestor::label", null, [""]]
];

function select(doc, expression, context = doc) {
  const result = doc.evaluate(expression, context, null, 7, null);
  return Array.from({ length: result.snapshotLength }, (_, i) => result.snapshotItem(i));
}
function keys(nodes) {
  return nodes.map(n => n.tagName === "LABEL" ? n.getAttribute("for") || "" : n.id || "");
}
function verify(doc) {
  for (const [name, expression, scope, expected] of queries) {
    const nodes = select(doc, expression, scope ? doc.querySelector(scope) : doc);
    assert.deepEqual(keys(nodes), expected, name);
    for (const node of nodes) {
      assert.equal(node.ownerDocument, doc, name);
      if (node.id) assert.equal(node, doc.getElementById(node.id), name);
    }
  }
  const before = select(doc, "//input[@id='localized']")[0];
  assert.equal(before, doc.querySelector("#localized"));
  before.value = "Milo";
  assert.equal(doc.querySelector("#localized").value, "Milo");
  before.outerHTML = '<input id="localized" value="replacement">';
  const after = select(doc, "//input[@id='localized']")[0];
  assert.notEqual(after, before);
  assert.equal(before.isConnected, false);
  assert.equal(after, doc.querySelector("#localized"));
  assert.equal(after.value, "replacement");
  assert.throws(() => select(doc, "//*["));
  assert.throws(() => select(doc, "count(//input)"));
}
function measure(doc) {
  const query = "//input[@data-testid='duplicate-name']";
  for (let i = 0; i < 100; i++) select(doc, query);
  return Array.from({length: 5}, () => {
    const start = performance.now();
    for (let i = 0; i < 1000; i++) {
      const nodes = select(doc, query);
      assert.equal(nodes.length, 2);
    }
    return performance.now() - start;
  });
}
(async () => {
  const { Window } = await import("happy-dom");
  const happy = new Window({url: "https://example.test/", settings: {disableJavaScriptEvaluation: true, disableJavaScriptFileLoading: true, disableCSSFileLoading: true}});
  const reference = new JSDOM(fixture);
  try {
    happy.document.write(fixture);
    assert.equal(typeof happy.document.evaluate, "undefined");
    installXPath(happy);
    assert.equal(typeof happy.document.evaluate, "function");
    verify(reference.window.document);
    verify(happy.document);
    console.log(JSON.stringify({contract: "live nodes, scope, order, invalid/scalar queries, mutation", result: "passed", unit: "ms per 1000 queries", samples: {jsdom: measure(reference.window.document), happyDomWgxpath: measure(happy.document)}}, null, 2));
  } finally {
    reference.window.close();
    await happy.happyDOM.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
