# BATCH-012: Executable Living Documentation

Accepted product direction, implementation staged. The conversation initially called this BATCH-011; existing roadmap reserves 011 for performance, so preserve that batch and assign 012 here. No separate product or repo.

## Existing foundation
Ruby Cucumber/Turnip adapters, Playwright Test reporter, case-v1, standalone Studio, DOM/video replay, assertions, cues, bidirectional step highlighting, and focus/smart zoom exist in foundation/mvp. Automatic Playwright timing/geometry, native mobile adapters and living docs are not yet complete.

## Milestones
- [x] Record design, standard, artifact layout, screenshot policy and modes.
- [x] Isolated reference feature with Overview, Business value, Actors, Preconditions, Background, Rule, data table, happy path, negative outline (0.00/-10.00/abc). Keep existing Ruby BDD 2-scenario/14-step fixture and its CI intact.
- [x] Execute one positive and three negative cases with Cucumber.js/TypeScript against the real public Rails Petstore; raw Messages, actual browser screenshots and video from selected scenario. Fast mode no capture.
- [ ] Standard AST normalization, stable identities, source mapping, case/run/spec schema extensions and validation; preserve existing protocol and reports.
- [x] Generate reference offline HTML documentation: intro, steps, inline actual screenshots, verified/expected outcomes, video at bottom; related negative examples and missing/stale evidence labels.
- [ ] Link Studio Docs, Test Report, Replay; screenshot checkpoints and element capture; action/assertion links and safe optional technical detail.
- [ ] Playwright Screencast integration, clock calibration, cues, focus, VTT and chapters; no invented offsets. Native adapters later.
- [ ] CI, dependency pinning, privacy/publication policy, cross-platform result provenance, stable example/attempt keys and performance overhead benchmark.

## Reference implementation

[Reference example](../../examples/petstore/README.md) references the canonical Petstore feature and includes Cucumber.js/TypeScript steps, Playwright checkpoint screenshot and Screencast capture, Messages-based exporter, HTML generator and dedicated CI verification. Reference execution and TypeScript checking verified in CI; downloaded HTML and media inspected. Production integration remains pending. The reference uses Screencast without calibrated timestamps; no VTT, focus, DOM snapshots or Studio integration yet. Existing 011 performance roadmap is unchanged.

## Acceptance gates
Positive test publishes a listing with correct price, seller ownership and guest visibility; all three invalid price examples pass as expected rejection. Only the public reference application's behavior is verified. Generated documentation shows actual evidence for the matching run/attempt and original feature text, screenshots inline and video at bottom. Missing/failed/skipped/retry/outline cases have honest outcomes. Raw artifacts stay local unless allowlisted. No video/pacing/extra UI queries in fast mode. Validate paths, escaping, schema and artifact existence. Run type checks and E2E/CI; report failures and unverified gaps rather than declaring completion.

## Next sequence

- [x] Public-only reference policy and domain-oriented feature organization; canonical Gherkin lives in Petstore.
- [x] CI: real Rails application, browser capture, four passed cases in each mode and actual HTML; synthetic artifact uploaded and inspected.
- [ ] Extract reusable generator/specification normalization into Domstride, with configurable paths and domain/actor/platform/journey navigation.
- [ ] Studio integration and Ruby Cucumber/Rails acceptance adapter, using the same canonical spec; benchmark fast mode.

CI reference runs as an independent job in the existing Rails reference and browser parity workflow on Ubuntu 24.04; Rails stays alive for both execution modes in one shell. No change to existing benchmark job.

## Verified reference run (2026-11-27)

[CI run 45973830161](https://github.com/sergii/domstride/actions/runs/45973830161), head 7e27991f6f1ea8a87a696f89daba9726dc77dda0. Both Fast and Documentation: four scenarios and 37 steps passed each; typecheck and artifact verification passed. Downloaded artifact 15186356652 contains six PNG screenshots, a 4.12-second VP8 WebM at 1280x800, four generated HTML pages, case/run/spec JSON and raw Messages. No capture errors. Fast mode has no media. No automatic calibrated cues, VTT or DOM snapshots yet; video presentation pacing and production Studio integration remain follow-up. Artifact is synthetic and expires after seven days.

## Presentation iteration

- [x] Implement offline responsive reference Docs UI with sidebar, search, domain/capability, actor, declared platform and journey groupings, feature context, numbered steps, actual outcome pills, screenshots and video at the bottom. Unspecified journey metadata stays unclassified.
- [x] Increase checkpoint holds to 1100 ms and form-field presentation holds to 650 ms only for selected recorded scenarios. Fast mode unchanged. CI validation of this iteration pending; not a calibrated media timeline.
- [ ] Inspect actual new video duration and browser UI; follow with measured cues, focus and subtitles.
