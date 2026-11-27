const {defineConfig} = require("@playwright/test");
const path = require("node:path");

module.exports = defineConfig({
  testDir: "./tests",
  outputDir: "test-results",
  workers: 1,
  retries: 0,
  reporter: [["list"],[path.resolve(__dirname,"../../adapters/playwright/reporter.cjs"),{
    directory: process.env.DOMSTRIDE_TEST_REPORT_DIR || "tmp/domstride-suite",
    video: true,
    stepText: true
  }]],
  use: { browserName:"chromium", headless:true, video:"on", viewport:{width:640,height:480} }
});
