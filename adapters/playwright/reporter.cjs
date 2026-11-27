// Playwright Test reporter. No Ruby or Domstride execution dependency.
const path = require("node:path");
const { writeCase } = require("../protocol/write_case.cjs");

function bounded(value, limit) {
  let text = String(value);
  while (Buffer.byteLength(text)>limit) text = text.slice(0,-1);
  return text;
}

function collect(steps, includeText) {
  const groups = [], assertions = [];
  function visit(step, parent = null) {
    let group = parent;
    if (step.category === "test.step" && groups.length < 100) {
      group = groups.length + 1;
      groups.push({sequence:group,keyword:"Step",text:includeText?bounded(step.title,1024):null,
        status:step.error?"failed":"passed",duration_ms:Math.max(0,step.duration)});
    }
    if (step.category === "expect" && assertions.length < 200) {
      assertions.push({sequence:assertions.length+1,kind:"playwright.expect",
        status:step.error?"failed":"passed",duration_ms:Math.max(0,step.duration),step_sequence:group});
    }
    for (const child of step.steps || []) visit(child,group);
  }
  for (const step of steps || []) visit(step);
  return {steps:groups,assertion_events:assertions};
}

class DomstrideReporter {
  constructor(options = {}) {
    this.directory = path.resolve(options.directory || "tmp/domstride-suite");
    this.video = options.video === true;
    this.stepText = options.stepText === true;
    this.written = 0;
    this.errors = 0;
  }

  onTestEnd(test, result) {
    try {
      const statuses = {passed:"passed",failed:"failed",timedOut:"failed",skipped:"skipped",interrupted:"unknown"};
      const project = test.parent.project()?.name || "default";
      const title = test.titlePath().filter(Boolean).join(" / ");
      const suffix = " [attempt " + (result.retry+1) + "]";
      const name = bounded(title,1024-Buffer.byteLength(suffix))+suffix;
      const metadata = {name,status:statuses[result.status] || "unknown",duration_ms:Math.max(0,result.duration),
        producer:"domstride-playwright-reporter",framework:"playwright-test",runner:"playwright",platform:"web",language:"javascript",
        ...collect(result.steps,this.stepText)};
      const videos = this.video ? result.attachments.filter(a=>a.path && a.contentType==="video/webm").slice(0,4)
        .map((a,i)=>({path:a.path,label:bounded(project+" video "+(i+1),128)})) : [];
      try {
        writeCase(this.directory,metadata,videos);
      } catch (error) {
        if (!videos.length) throw error;
        // Preserve test metadata even if the optional recording is invalid or too large.
        console.warn("Domstride: video evidence omitted for an attempt");
        writeCase(this.directory,metadata);
      }
      this.written++;
    } catch (error) {
      this.errors++;
      console.warn("Domstride: unable to write test attempt ("+error.name+")");
    }
  }

  onEnd() {
    console.log("Domstride: "+this.written+" attempt(s) written, "+this.errors+" export error(s)");
    // Do not override Playwright's own exit status.
  }
}
module.exports = DomstrideReporter;
