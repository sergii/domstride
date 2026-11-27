# Playwright Test reporter

Use the source-checkout adapter with existing JavaScript or TypeScript Playwright Test projects. No changes to individual tests. Example playwright.config.ts:

```typescript
reporter: [
  ['list'],
  ['./path/to/domstride/adapters/playwright/reporter.cjs', {
    directory: 'tmp/domstride-suite',
    video: true,
    stepText: true
  }]
],
use: { video: 'retain-on-failure' }
```

Keep the reporter and adjacent adapters/protocol/write_case.cjs together. Video capture belongs to Playwright; reporter video: true only copies finalized WebM attachments. Both video and stepText default false. Explicit test titles may contain private values. Do not publish real test reports automatically. Use a fresh output directory each run. The adapter preserves Playwright's actual attempt status and exit code, including timed-out attempts (failed), interrupted (unknown), skips and retries (one case per attempt, suffix in title). It does not compute logical test-level outcomes or reinterpret expected failures/flaky tests. Step data comes from Playwright test.step and expect categories; nested expectations are linked to their nearest recorded test.step. No assertion count is inferred. No video seeking by step timestamp yet. Video limits follow Protocol v1; invalid optional video drops the video rather than the entire case. Producer logs failures; no reporter exit code override. Protocol v1 export limits still apply.

Render locally with ruby -I/path/to/domstride/lib /path/to/domstride/exe/domstride report tmp/domstride-suite. No runner dependencies needed for report generation from source. npm packaging is not yet published. Reference workflow uses actual Playwright Test 1.56.1 and exports synthetic failed/passed/skipped/retry evidence.
