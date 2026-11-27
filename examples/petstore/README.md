# Petstore reference

The public [Petstore Rails application](https://github.com/sergii/petstore) is the actual system under test. The canonical feature is in that repository at features/marketplace/listings/publish_listing.feature; no copied feature or synthetic HTML implementation here. Only synthetic public demo data. The example illustrates Cucumber.js / TypeScript / Playwright evidence collection and offline documentation, independent of the Ruby runner.

Use a disposable Rails test database and a local Rails server (never production). Seed Alex Demo / seller@example.test with the synthetic password synthetic-demo-password; clear that user's listings before each suite. See the dedicated workflow for exact setup. Install Node 22+, npm dependencies and Chromium.

```sh
cd examples/petstore
npm install
npx playwright install chromium
export PETSTORE_FEATURE=/absolute/path/to/petstore/features/marketplace/listings/publish_listing.feature
export PETSTORE_BASE_URL=http://127.0.0.1:3000
export PETSTORE_COMMIT=<checked-out-application-commit>
export GIT_COMMIT=$(git rev-parse HEAD)
npm run typecheck
npm test
# Reset the isolated test database's demo listings before the next run.
npm run execution
# Reset demo listings again before guided capture.
npm run docs
npm run docs:pair
node verify.cjs
```

Open artifacts/<documentation-run>/documentation/index.html. The feature intro, numbered steps, inline real screenshots, results and video are generated from Gherkin and runtime evidence. Four cases in each mode; only the selected positive case records media. Screencast starts after sign-in. Fast mode has no recording or pacing. Execution mode records the selected positive scenario without screenshots or intentional holds. Documentation mode records guided video and checkpoints with semantic holds. Pairing checks identical source hash, application and Domstride commits, browser/platform/viewport, and separate run/attempt IDs; the guided report links the unpaced video from its own run. Preserve both run directories. No claim that capture duration equals Fast test time. Browser-native invalid price errors are asserted using validity state and non-empty validation message; server-side validation is a separate Rails concern.

Reference only: no calibrated timestamps, VTT, DOM snapshots, production schema validation, public publication, Studio integration or mobile drivers yet. Do not claim verified until CI passes. Production generator extraction and Ruby acceptance adapter remain planned. Dependencies are pinned directly; lockfile is pending.

## Portable static export (reference)

After successful pairing, run `npm run docs:export -- --synthetic-reference <exact-guided-run-directory>` once. The generated static-export directory contains Markdown, generic MDX, approved local media, and a publication manifest. JSON documentation-model stays at the run root. No tests rerun, no storage upload, no raw messages copied into the publication. Generic MDX needs framework-specific asset routing; Starlight/Fumadocs adapters are not implemented yet. Only approved public synthetic reference artifacts are supported.

## Starlight reference

See [Help Center](help-center/README.md). Imports the approved static export, then builds a separate Astro site with native Steps and ordinary video. No Rails or acceptance test execution is required at site build. CI build and browser smoke pending.

See [Fumadocs reference](fumadocs/README.md) for the second static framework integration.
