const { chromium } = require("playwright");
const { performance } = require("node:perf_hooks");
async function expectText(page, selector, text) {
  await page.waitForFunction(({ selector, text }) => document.querySelector(selector)?.textContent === text, { selector, text }, { timeout: 2000 });
}
async function scenario(page) {
  await page.goto("http://127.0.0.1:4567/");
  await expectText(page, "h1", "Expense Lab");
  await expectText(page, "#expense[data-ready=true] #total", "0");
  await page.locator("#add").click();
  await expectText(page, "#total", "25");
  await page.locator("#details-link").click();
  await expectText(page, "#receipt", "Receipt #42");
  await page.locator("#approve-link").click();
  await expectText(page, "#status", "Approved");
  await page.locator("#email").fill("tester@example.test");
  await page.locator("#password").fill("fixture-password");
  await page.locator("#login").click();
  await expectText(page, "#identity", "Signed in");
  await page.locator("#description").fill("Lunch");
  await page.locator("#amount").fill("0");
  await page.locator("#save").click();
  await expectText(page, "#result", "Invalid expense");
  await page.locator("#amount").fill("25");
  await page.locator("#save").click();
  await expectText(page, "#result", "Saved");
  await page.goto("http://127.0.0.1:4567/");
  await expectText(page, "#identity", "Signed in");
  await page.locator("#latest-link").click();
  await expectText(page, "#persisted", "Lunch: 25");
}
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await scenario(page);
    const samples = [], iterations = Number(process.env.ITERATIONS || 10), repeats = Number(process.env.REPEATS || 5);
    for (let i = 0; i < repeats; i++) {
      const start = performance.now();
      for (let j = 0; j < iterations; j++) await scenario(page);
      samples.push((performance.now() - start) / 1000);
    }
    console.log(JSON.stringify({ runtime: "chromium", browser: browser.version(), iterations, samples, median_seconds: [...samples].sort((a,b)=>a-b)[Math.floor(samples.length/2)] }, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
