const assert = require("node:assert/strict");
const path = require("node:path");
const fs = require("node:fs");
const { select } = require("../runtime/happy_xpath.cjs");

(async () => {
  const { Window } = await import("happy-dom");
  const win = new Window({ url: "https://example.test/", settings: { disableJavaScriptEvaluation: true, disableJavaScriptFileLoading: true, disableCSSFileLoading: true } });
  const doc = win.document;
  try {
    doc.write(fs.readFileSync(path.join(__dirname, "../examples/locator_compatibility/fixture.html"), "utf8"));
    const originalEvaluate = doc.evaluate;
    assert.deepEqual(select("//input[@data-testid='duplicate-name']", doc).map(node => node.id), ["first-name", "second-name"]);
    const scope = doc.querySelector("#second");
    assert.equal(select(".//input[@data-testid='duplicate-name']", scope)[0], doc.querySelector("#second-name"));
    assert.deepEqual(select("//input[@id='second-name'] | //input[@data-testid='duplicate-name']", doc).map(node => node.id), ["first-name", "second-name"]);
    const old = select("//input[@id='localized']", doc)[0];
    assert.equal(old, doc.getElementById("localized"));
    old.value = "Milo";
    assert.equal(doc.getElementById("localized").value, "Milo");
    old.outerHTML = '<input id="localized" value="replacement">';
    const fresh = select("//input[@id='localized']", doc)[0];
    assert.notEqual(old, fresh);
    assert.equal(old.isConnected, false);
    assert.equal(fresh, doc.getElementById("localized"));
    assert.equal(fresh.value, "replacement");
    assert.throws(() => select("//*[", doc));
    assert.throws(() => select("count(//input)", doc));
    assert.throws(() => select("//input/@id", doc), /UNSUPPORTED_XPATH_RESULT/);
    assert.equal(doc.evaluate, originalEvaluate, "Do not patch the document");
    console.log("Happy DOM runtime XPath contract passed");
  } finally {
    await win.happyDOM.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
