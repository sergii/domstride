const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
const {pathToFileURL} = require("node:url");
const {chromium} = require("playwright");
const http = require("node:http");
const {recordBrowserCase} = require("../examples/browser_video/record.cjs");
const {writeCase} = require("../examples/protocol/write_case.cjs");
const {viewportTarget} = require("../adapters/playwright/viewport_target.cjs");

test("actual Chromium video is attached to a failed case and plays offline", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(),"domstride-video-"));
  let browser, server;
  try {
    server=http.createServer((req,res)=>{res.writeHead(200,{"Content-Type":"text/html"});res.end('<h1>Expense Lab</h1><input aria-label="Amount"><button>Save</button>');});
    await new Promise(resolve=>server.listen(0,"127.0.0.1",resolve));
    const url="http://127.0.0.1:"+server.address().port+"/expenses/new";
    browser = await chromium.launch({headless:true});
    const start = performance.now();
    let inputTarget, buttonTarget;
    const result = await recordBrowserCase(browser, root, async page=>{
      await page.goto(url);
      assert.equal(page.url(),url);
      inputTarget=await viewportTarget(page.getByLabel("Amount"),page,{width:800,height:600});
      buttonTarget=await viewportTarget(page.getByRole("button",{name:"Save"}),page,{width:800,height:600});
      assert.ok(inputTarget && buttonTarget);
      await page.getByLabel("Amount").fill("25");
      await page.getByRole("button",{name:"Save"}).click();
      await page.waitForTimeout(1000);
      throw new Error("Expected approved");
    });
    assert.equal(result.error.message,"Expected approved");
    assert.ok(fs.statSync(result.path).size>100);
    const cases = path.join(root,"cases");
    writeCase(cases,{name:"Browser expense",status:"failed",duration_ms:performance.now()-start,
      producer:"external-node",framework:"node:test",runner:"playwright",platform:"web",language:"javascript",
      steps:[{sequence:1,keyword:"Step",text:"Synthetic cue",status:"passed",duration_ms:100},{sequence:2,keyword:"Step",text:"Second cue",status:"passed",duration_ms:400}],
      assertion_events:[{sequence:1,kind:"synthetic.assert",status:"failed",duration_ms:20,step_sequence:1},{sequence:2,kind:"unmapped",status:"failed",duration_ms:20}]},
      [{path:result.path,label:"Chromium",cues:[{kind:"step",sequence:1,time_ms:100},{kind:"assertion",sequence:1,time_ms:300},{kind:"step",sequence:2,time_ms:600}],focus:[
        {kind:"fill",status:"passed",start_ms:100,end_ms:300,...inputTarget},
        {kind:"assert",status:"failed",start_ms:300,end_ms:600,...buttonTarget}]}]);
    execFileSync("ruby",["-Ilib","-rdomstride/report","-e",
      'abort "Runner loaded" if defined?(Domstride::Session) || defined?(Domstride::Runtime); Domstride::Report.export(ARGV[0])',cases],{stdio:"pipe"});
    const viewer = await browser.newPage();
    const errors = [], requests = [];
    viewer.on("pageerror",error=>errors.push(error.message));
    viewer.on("request",request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    await viewer.goto(pathToFileURL(path.join(cases,"report.html")).href);
    assert.equal(await viewer.locator("#evidence-mode").inputValue(),"video");
    assert.equal(await viewer.locator("#video-select option").innerText(),"Chromium");
    assert.match(await viewer.locator("#suite-summary").innerText(),/1 failed/);
    assert.deepEqual(await viewer.locator("#case-provenance .provenance-tag").allTextContents(),["external-node","node:test","playwright","web","javascript"]);
    assert.equal(await viewer.locator("#trace-picker").isVisible(),false);
    await viewer.waitForFunction(()=>document.querySelector("#browser-video").readyState>=2);
    await viewer.locator("#browser-video").evaluate(video=>video.play());
    await viewer.waitForFunction(()=>document.querySelector("#browser-video").currentTime>0);
    await viewer.locator("#browser-video").evaluate(video=>video.pause());
    await viewer.locator("#gherkin-steps button").first().click();
    await viewer.waitForFunction(()=>Math.abs(document.querySelector("#browser-video").currentTime-0.1)<0.08);
    await viewer.locator("#assertion-steps button").first().click();
    await viewer.waitForFunction(()=>Math.abs(document.querySelector("#browser-video").currentTime-0.3)<0.08);
    assert.equal(await viewer.locator("#assertion-steps button").first().getAttribute("aria-current"),"true");
    assert.equal(await viewer.locator("#assertion-steps button").last().isDisabled(),true);
    await viewer.waitForFunction(()=>!document.querySelector("#focus-outline").hidden && document.querySelector("#focus-outline").classList.contains("failed"));
    assert.notEqual(await viewer.locator("#video-layer").evaluate(el=>el.style.transform),"none");
    await viewer.locator("#smart-zoom").uncheck();
    assert.equal(await viewer.locator("#video-layer").evaluate(el=>el.style.transform),"none");
    assert.equal(await viewer.locator("#focus-outline").isVisible(),true);
    await viewer.locator("#focus-highlight").uncheck();
    assert.equal(await viewer.locator("#focus-outline").isVisible(),false);
    await viewer.locator("#smart-zoom").check();
    await viewer.locator("#focus-highlight").check();
    // Playback alone updates the sidebar; no click on a step.
    await viewer.locator("#browser-video").evaluate(video=>{video.currentTime=0;return video.play();});
    await viewer.waitForFunction(()=>document.querySelector('#gherkin-steps button[data-sequence="2"]').getAttribute("aria-current")==="true");
    await viewer.locator("#browser-video").evaluate(video=>{video.pause();video.currentTime=0.15;});
    await viewer.waitForFunction(()=>document.querySelector('#gherkin-steps button[data-sequence="1"]').getAttribute("aria-current")==="true");
    assert.equal(await viewer.locator("#assertion-steps button").first().getAttribute("aria-current"),"false");
    await viewer.locator("#browser-video").evaluate(video=>{video.currentTime=0;});
    await viewer.waitForFunction(()=>!document.querySelector("#gherkin-steps [aria-current=true]"));
    assert.equal(await viewer.locator("#video-layer").evaluate(el=>el.style.transform),"none");
    assert.equal(await viewer.locator("#focus-outline").isVisible(),false);
    assert.deepEqual(errors,[]);
    assert.deepEqual(requests,[]);
    await viewer.locator("#evidence-mode").selectOption("dom");
    assert.equal(await viewer.locator("#browser-video").getAttribute("src"),null);
    await viewer.close();
  } finally {
    await browser?.close();
    if (server) await new Promise(resolve=>server.close(resolve));
    fs.rmSync(root,{recursive:true,force:true});
  }
});
