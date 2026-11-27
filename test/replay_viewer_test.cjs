const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { pathToFileURL } = require("node:url");
const { chromium } = require("playwright");

test("offline viewer switches panels without losing selection or executing snapshot code", async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "domstride-viewer-"));
  let browser;
  try {
    const malicious = '<script>globalThis.injected = true</script><img src="https://example.invalid/track" onerror="globalThis.injected = true"><iframe src="https://example.invalid/frame"></iframe>';
    fs.writeFileSync(path.join(directory, "000001-after.html"), '<label>Amount <input value="0"></label>');
    fs.writeFileSync(path.join(directory, "000002-before.html"), '<label>Amount <input value="0"></label>');
    fs.writeFileSync(path.join(directory, "000002-after.html"), '<label>Amount <input value="25"></label>' + malicious);
    const frame = (sequence, phase) => ({ snapshot: String(sequence).padStart(6, "0") + "-" + phase + ".html", body_path: [1], target_path: [1, 0, 0] });
    const events = [
      {type:"header", schema_version:1},
      {type:"interaction", sequence:1, kind:"mount", status:"passed", duration_ms:1, after:frame(1,"after")},
      {type:"interaction", sequence:2, kind:"fill", status:"passed", duration_ms:2, before:frame(2,"before"), after:frame(2,"after")},
      {type:"footer", event_count:2}
    ];
    fs.writeFileSync(path.join(directory,"events.jsonl"), events.map(row=>JSON.stringify(row)).join("\n")+"\n");
    execFileSync("bundle", ["exec", "ruby", "exe/domstride", "replay", directory], {stdio:"pipe"});
    browser = await chromium.launch({headless:true});
    const page = await browser.newPage({viewport:{width:1280,height:800}});
    const requests = [], errors = [];
    page.on("request", request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
    page.on("pageerror", error => errors.push(error.message));
    await page.goto(pathToFileURL(path.join(directory,"replay.html")).href);
    await page.locator("#next").click();
    assert.equal(await page.locator("#viewport input.target").inputValue(), "25");
    assert.equal(await page.locator("#position").innerText(), "2 / 2");
    const viewport = page.locator("main > section");
    const sidebar = page.locator("main > aside");
    assert.ok((await viewport.boundingBox()).x < (await sidebar.boundingBox()).x);
    await page.locator("#layout").selectOption("left");
    assert.ok((await sidebar.boundingBox()).x < (await viewport.boundingBox()).x);
    assert.equal(await page.locator("#position").innerText(), "2 / 2");
    await page.locator("#phase").selectOption("before");
    assert.equal(await page.locator("#viewport input.target").inputValue(), "0");
    await page.locator("#layout").selectOption("right");
    assert.equal(await page.locator("#phase").inputValue(), "before");
    await page.locator("#phase").selectOption("after");
    await page.setViewportSize({width:500,height:800});
    await page.locator("#layout").selectOption("left");
    assert.ok((await sidebar.boundingBox()).y < (await viewport.boundingBox()).y);
    assert.equal(await page.locator("#viewport script, #viewport iframe, #viewport img").count(),0);
    assert.equal(await page.evaluate(() => typeof globalThis.injected), "undefined");
    assert.deepEqual(requests,[]);
    assert.deepEqual(errors,[]);
  } finally {
    await browser?.close();
    fs.rmSync(directory,{recursive:true,force:true});
  }
});


test("suite report filters cases and selects recordings independently of operation status", async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "domstride-suite-"));
  let browser;
  try {
    for (const [id, name, status] of [["a","Create expense","passed"],["b","Failed assertion","failed"],["c","Skipped","skipped"]]) {
      const root = path.join(directory, "domstride-case-"+id);
      fs.mkdirSync(root);
      fs.writeFileSync(path.join(root,"case.json"),JSON.stringify({schema_version:1,name,status,duration_ms:120}));
      if (id === "c") continue;
      const recording = path.join(root,"domstride-recording-a");
      fs.mkdirSync(recording);
      fs.writeFileSync(path.join(recording,"events.jsonl"),[
        {type:"header",schema_version:1,engine:"jsdom31"},
        {type:"interaction",sequence:1,kind:"click",status:"passed",duration_ms:2,after:{snapshot:"000001-after.html",body_path:[1],target_path:[1,0]}},
        {type:"footer",event_count:1}
      ].map(row=>JSON.stringify(row)).join("\n")+"\n");
      fs.writeFileSync(path.join(recording,"000001-after.html"),"<p>"+name+"</p>");
    }
    execFileSync("bundle",["exec","ruby","exe/domstride","report",directory],{stdio:"pipe"});
    browser = await chromium.launch({headless:true});
    const page = await browser.newPage({viewport:{width:1280,height:800}});
    const errors = [];
    page.on("pageerror",error=>errors.push(error.message));
    await page.goto(pathToFileURL(path.join(directory,"report.html")).href);
    assert.match(await page.locator("#suite-summary").innerText(),/3 tests · 1 passed · 1 failed · 1 skipped/);
    assert.equal(await page.locator("#viewport").innerText(),"Create expense");
    await page.locator("#case-status").selectOption("failed");
    assert.equal(await page.locator("#viewport").innerText(),"Failed assertion");
    assert.match(await page.locator("#steps").innerText(),/passed/);
    await page.locator("#layout").selectOption("left");
    await page.locator("#case-status").selectOption("skipped");
    assert.equal(await page.locator("#viewport").innerText(),"No recorded interactions.");
    assert.equal(await page.locator("#layout").inputValue(),"left");
    await page.locator("#case-status").selectOption("");
    await page.locator("#case-search").fill("no match");
    assert.equal(await page.locator("#case-select option").count(),0);
    assert.equal(await page.locator("#viewport").innerText(),"No recorded interactions.");
    assert.deepEqual(errors,[]);
  } finally {
    await browser?.close();
    fs.rmSync(directory,{recursive:true,force:true});
  }
});
