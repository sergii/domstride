# BATCH-012: Executable Living Documentation

Accepted product direction, implementation staged. The conversation initially called this BATCH-011; existing roadmap reserves 011 for performance, so preserve that batch and assign 012 here. No separate product or repo.

## Existing foundation
Ruby Cucumber/Turnip adapters, Playwright Test reporter, case-v1, standalone Studio, DOM/video replay, assertions, cues, bidirectional step highlighting, and focus/smart zoom exist in foundation/mvp. Automatic Playwright timing/geometry, native mobile adapters and living docs are not yet complete.

## Milestones
- [x] Record design, standard, artifact layout, screenshot policy and modes.
- [x] Isolated reference feature with Overview, Business value, Actors, Preconditions, Background, Rule, data table, happy path, negative outline (0.00/-10.00/abc). Keep existing Ruby BDD 2-scenario/14-step fixture and its CI intact.
- [ ] Execute one positive and three negative cases with Cucumber.js/TypeScript against the real public Rails Petstore; raw Messages, actual browser screenshots and video from selected scenario. Fast mode no capture.
- [ ] Standard AST normalization, stable identities, source mapping, case/run/spec schema extensions and validation; preserve existing protocol and reports.
- [ ] Generate offline HTML documentation: intro, steps, inline actual screenshots, verified/expected outcomes, video at bottom; related negative examples and missing/stale evidence labels.
- [ ] Link Studio Docs, Test Report, Replay; screenshot checkpoints and element capture; action/assertion links and safe optional technical detail.
- [ ] Playwright Screencast integration, clock calibration, cues, focus, VTT and chapters; no invented offsets. Native adapters later.
- [ ] CI, dependency pinning, privacy/publication policy, cross-platform result provenance, stable example/attempt keys and performance overhead benchmark.

## Reference implementation

[Reference example](../../examples/petstore/README.md) references the canonical Petstore feature and includes Cucumber.js/TypeScript steps, Playwright checkpoint screenshot and Screencast capture, Messages-based exporter, HTML generator and dedicated CI verification. Source is committed; end-to-end execution, TypeScript checking and output inspection remain pending. The reference uses Screencast without calibrated timestamps; no VTT, focus, DOM snapshots or Studio integration yet. Existing 011 performance roadmap is unchanged.

## Acceptance gates
Positive test publishes a listing with correct price, seller ownership and guest visibility; all three invalid price examples pass as expected rejection. Only the public reference application's behavior is verified. Generated documentation shows actual evidence for the matching run/attempt and original feature text, screenshots inline and video at bottom. Missing/failed/skipped/retry/outline cases have honest outcomes. Raw artifacts stay local unless allowlisted. No video/pacing/extra UI queries in fast mode. Validate paths, escaping, schema and artifact existence. Run type checks and E2E/CI; report failures and unverified gaps rather than declaring completion.

## Next sequence

- [x] Public-only reference policy and domain-oriented feature organization; canonical Gherkin lives in Petstore.
- [ ] CI: real Rails application, browser capture, four passed cases and actual HTML; inspect and publish only synthetic artifacts.
- [ ] Extract reusable generator/specification normalization into Domstride, with configurable paths and domain/actor/platform/journey navigation.
- [ ] Studio integration and Ruby Cucumber/Rails acceptance adapter, using the same canonical spec; benchmark fast mode.

CI reference runs as an independent job in the existing Rails reference and browser parity workflow on Ubuntu 24.04; Rails stays alive for both execution modes in one shell. No change to existing benchmark job.
