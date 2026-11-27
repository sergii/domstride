# Core extraction and packaging: phase 1

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

Status: phase 3 implementation candidate; CI pending.
