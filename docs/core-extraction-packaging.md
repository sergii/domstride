# Core extraction and packaging

Scope: reusable documentation model and static Markdown/MDX exporter, shipped via the existing Ruby gem lib/ packaging. No changes to engine, runtime cache, capture, Viewer, or default test execution. The implementation uses Node built-ins only; no npm install or Rails server required to export an existing run.

```sh
domstride docs export --synthetic-reference /absolute/path/to/guided-run
```

Requires explicitly approved trusted synthetic reference artifacts in the existing paired Chromium run format. This is not a general untrusted-artifact ingestion or production publication API. No upload, no automatic redaction, no new recording. Existing output format, framework importers and UI stay unchanged. Duplicate scenario/media IDs and symlink inputs rejected; no overwrite of an existing export directory. Failed export may leave a partial generated directory; remove it explicitly before retrying. Local input must be controlled by the caller; full security/schema validation and atomic export are later gates.

The Petstore example delegates to the packaged model/exporter. CLI and installed-gem smoke use separate synthetic library-domain fixtures; actual Petstore CI still exercises real recorded media and both documentation sites. Later phases: reusable Cucumber Messages normalizer, separate Playwright recorder API, stable schema and retry/example mapping, generic platform and publication policies, framework adapters. Core performance A/B remains separate. No release publication.

Phase 1: installed gem smoke and reference workflows passed on 935cb5b; Fizzy compatibility workflow failed separately.

## Phase 2: Cucumber Messages normalizer

`lib/domstride/documentation/cucumber-messages.cjs` exports `parseMessages(text)` and `normalizeMessages(envelopes)`. It is a pure Node module with no browser, Rails, recorder, filesystem or publication dependency. Input is trusted NDJSON using the existing explicit feature/scenario tag convention; output is a specification plus normalized cases, with source mapping, resolved arguments, hook outcomes, distinct retries and unknown incomplete attempts. Petstore owns media and runner metadata only. Missing durations are null rather than fabricated zero. Stable example identity, generic untagged ingestion, full envelope/schema validation, bounded input and redaction remain later gates. Raw documents/arguments are not safe to publish by default. Independent synthetic library fixture runs in product readiness CI.

Phase 2: reference and product readiness workflows passed on 2ac1492; Fizzy failed separately.

## Phase 3: Playwright recorder extraction

`lib/domstride/documentation/playwright-recorder.cjs` provides an explicit recorder for caller-owned Playwright pages using the pinned reference screencast API. `prepare`, `start`, `checkpoint`, `hold`, `stop` and `writeCapture` manage local media and capture metadata. Execution mode records unpaced; guided mode supports screenshots, holds and frame observations. The caller selects scenarios, starts after authentication, owns browser lifecycle and supplies checkpoint IDs. Fast mode constructs no recorder. Petstore retains business steps, focus/landmark presentation and navigation policy; those are not general recorder APIs. No calibrated media clock, redaction, automatic capture, arbitrary browser compatibility or public upload. Input/output directories are trusted and caller-owned. Fake lifecycle tests and an independent actual Chromium smoke are added to CI; installed gem packaging includes the module under lib/.

Phase 3: 17/19 workflows passed on d3e015e. Petstore typecheck failed because screencast.start returns Promise<Disposable>; declaration corrected in f6955de. Real browser smoke and downstream checks require a new green CI. Fizzy remains separate.

## Phase 4: documentation protocol validation

Add version-1 specification/run JSON Schemas and a dependency-free structural/cross-reference validator for the trusted local documentation profile. The existing general case-v1 schema and Ruby report reader remain unchanged. Both guided and paired execution bundles are checked before the exporter creates output: unique feature/scenario/attempt/folder identities, run entry and specification links, contiguous step sequences, local evidence names, step references, video provenance and mode constraints. The normalizer may retain incomplete attempts with null duration, but they cannot be published as valid v1 cases; no invented timings. This is not a comprehensive JSON Schema engine, an untrusted artifact parser, a file size/security audit or redaction layer. Existing exporter approval and file checks are still required. Independent negative tests and updated installed-gem fixture added. Schema/validator consistency beyond the documented subset, stable example identity, raw envelope limits and external consumer conformance remain open.

Phase 3/4: 18/19 workflows passed on 832e075, including real browser reference, typecheck and product readiness; Fizzy failed separately.

## Phase 5: reusable framework integrations

`lib/domstride/documentation/cucumber-run-adapter.cjs` exposes `writeCucumberRun(root, run, metadata)`. It materializes existing Cucumber Messages and explicit per-attempt capture metadata into specification/case/run manifests. Caller supplies actual producer, framework, runner, platform, language, browser, viewport and video label. No test execution or rendering; Petstore delegates and retains presentation only. Use a fresh caller-controlled run directory; failed writes can leave a partial run. Missing or mismatched capture is reported rather than interpreted as a test failure. Incomplete attempts with unknown duration remain diagnostic, not publication-ready v1 cases. No untrusted ingestion or redaction.

The existing Playwright Test reporter, protocol writer and viewport helper now ship in the Ruby gem under adapters/ without changing their behavior or public source-checkout paths. They produce general case-v1 bundles, not Gherkin specifications. Ruby Cucumber/Turnip, Minitest and RSpec continue to use their existing integrations; no automatic new hooks. npm-only distribution and generic framework adapters remain future work. CI adds independent library-domain adapter tests and installed-gem reporter/adapter smoke outside checkout. Phase 6 will verify consumers end to end.

Phase 5: 18/19 workflows passed on 765d9ac; Fizzy failed separately.

## Phase 6: independent consumer verification

A separate workflow builds and installs the gem into an isolated temporary directory and copies only the independent library fixture there. Actual Cucumber.js and Chromium run three distinct modes against a loopback HTTP application; the installed recorder and adapter create real media and manifests. The installed CLI exports Markdown/MDX with checksummed media and generates a standalone Ruby report. A fresh Chromium instance loads Replay offline and tests video playback. No Petstore, Rails server, runtime setup, or source-checkout imports. The fixture supplies the trusted synthetic pair explicitly; a generalized pairing API and independent third-party Viewer are not implemented. Unmapped video must not imply synchronized actions. CI uploads synthetic evidence for review.

Phase 6: independent installed consumer passed on 03d8d50. No merge or release. Full security validation, redaction, stable example IDs, npm packaging, generalized focus/clock mapping and broader framework conformance remain separate follow-ups.

## Final consolidation review (2026-11-28)

Reviewed all 32 changed paths on 03d8d50: no changes to the Ruby execution core, runtime worker, Capybara driver or Replay rendering templates. 19/20 workflows passed, including installed consumer (46085282412), product readiness (46085282279), and Rails reference / Petstore / both static sites (46085282494). Offline replay and actual browser playback are confirmed by CI, not a manual visual review. The synthetic independent consumer is not a third-party production application. See [PR #19](https://github.com/sergii/domstride/pull/19).

Fizzy 46085282265 matches accepted baseline 46068831277: join_account passed; create_card fails ambiguous Add a card; navigation/lightbox fail missing ResizeObserver; lightbox also reports ElementInternals.setValidity. No workflow suppression. Experimental Bun/Happy DOM still fails some tests despite a green aggregate workflow; Happy DOM reference also has a pending example. These are not full browser parity claims.

Capybara/Cuprite benchmark 46085282237: medians of five samples of ten iterations, Domstride/jsdom 1.8665 s, Domstride/Happy DOM 0.4291 s, Cuprite/Chromium 10.4159 s. These are comparative driver measurements, not main-vs-PR regression measurements; no controlled A/B baseline was collected. Gem preview artifact ZIP 86,653 bytes versus phase 1 ZIP 78,068 bytes; actual installed footprint and pre-extraction baseline not measured.

Audit hardening: validate pair format/version and distinct attempts, match the paired execution manifest ID and require clean execution evidence, compare resolved steps and arguments across the selected recordings, and distinguish scenarios not executed in this run from historically verified scenarios. Added negative installed CLI fixtures. This is still trusted synthetic publication only; no general security guarantee, no stable example identity, no atomic export, no dependency lockfile for the independent fixture. Review hardening commit CI pending. Maintainer approval required before merge/tag/publication.
