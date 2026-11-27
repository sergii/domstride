// Optional Playwright helper. A fresh context per test guarantees video ownership.
// Video is finalized on context.close(). Caller retains the test's own outcome.
async function recordBrowserCase(browser, directory, run, options = {}) {
  const context = await browser.newContext({
    viewport: { width: 800, height: 600 },
    ...options,
    recordVideo: { dir: directory, size: { width: 800, height: 600 } }
  });
  let page, video, error;
  try {
    page = await context.newPage();
    video = page.video();
    await run(page);
  } catch (caught) {
    error = caught;
  } finally {
    try { await context.close(); }
    catch (caught) { if (!error) throw caught; }
  }
  const path = video ? await video.path() : null;
  return { path, error };
}
module.exports = { recordBrowserCase };
