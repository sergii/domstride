const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
const {pathToFileURL} = require("node:url");
const {chromium} = require("playwright");
const {recordBrowserCase} = require("../examples/browser_video/record.cjs");

test("actual Chromium video is attached to a failed case and plays offline", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(),"domstride-video-"));
  let browser;
  try {
    browser = await chromium.launch({headless:true});
    const result = await recordBrowserCase(browser, root, async page=>{
      await page.setContent('<h1>Expense</h1><input aria-label="Amount"><button onclick="document.querySelector(\'h1\').textContent=\'Saved\'">Save</button>');
      await page.getByLabel("Amount").fill("25");
      await page.getByRole("button",{name:"Save"}).click();
      await page.waitForTimeout(400);
      throw new Error("Expected approved");
    });
    assert.equal(result.error.message,"Expected approved");
    assert.ok(fs.statSync(result.path).size>100);
    const cases = path.join(root,"cases");
    execFileSync("bundle",["exec","ruby","-Ilib","-rdomstride","-rdomstride/report","-e",
      'Domstride::Report.capture(directory: ARGV[0], name: "Browser expense") { |item| Domstride::Video.attach(ARGV[1], label: "Chromium"); item.status = "failed" }; Domstride::Report.export(ARGV[0])',cases,result.path],{stdio:"pipe"});
    const viewer = await browser.newPage();
    const errors = [], requests = [];
    viewer.on("pageerror",error=>errors.push(error.message));
    viewer.on("request",request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    await viewer.goto(pathToFileURL(path.join(cases,"report.html")).href);
    assert.equal(await viewer.locator("#evidence-mode").inputValue(),"video");
    assert.equal(await viewer.locator("#video-select option").innerText(),"Chromium");
    assert.match(await viewer.locator("#suite-summary").innerText(),/1 failed/);
    await viewer.waitForFunction(()=>document.querySelector("#browser-video").readyState>=2);
    await viewer.locator("#browser-video").evaluate(video=>video.play());
    await viewer.waitForFunction(()=>document.querySelector("#browser-video").currentTime>0);
    assert.deepEqual(errors,[]);
    assert.deepEqual(requests,[]);
    await viewer.locator("#evidence-mode").selectOption("dom");
    assert.equal(await viewer.locator("#browser-video").getAttribute("src"),null);
    await viewer.close();
  } finally {
    await browser?.close();
    fs.rmSync(root,{recursive:true,force:true});
  }
});
