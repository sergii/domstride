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
- [x] Increase checkpoint holds to 1100 ms and form-field presentation holds to 650 ms only for selected recorded scenarios. Fast mode unchanged. CI passed in run 45974971779; not a calibrated media timeline.
- [ ] Inspect actual new video duration and browser UI; follow with measured cues, focus and subtitles.

## Dual video and external documentation roadmap

- [x] Reference unpaced and guided capture, isolated data/reset, independent attempt/run IDs and measured media duration; Fast zero capture and Execution zero intentional holds. Calibrated per-profile cues remain pending.
- [ ] Action-aware pacing, target focus, calibrated per-video cues, captions and chapters; preserve unmodified evidence.
- [x] Reference portable documentation model and Markdown/MDX export from approved verified artifacts without test execution at site build. Reader-facing section structure and production normalization remain follow-up.
- [x] Starlight reference adapter: actual static build and browser smoke.
- [ ] Improve reader-facing guide structure, then Fumadocs and Docusaurus adapters; plain Markdown fallback. No duplicate feature source. Optional player integration later.
- [ ] Media publication manifest and local/S3-compatible adapters; safe allowlist, private by default, immutable versioned assets, auth-aware delivery and stale evidence handling. See [documentation publishing](../documentation-publishing.md).

UI v2 CI: [45974971779](https://github.com/sergii/domstride/actions/runs/45974971779), Petstore job passed; artifact 15185619987 available. New design output inspection remains pending.

## Dual recording reference implementation

Implemented three reference CLI runs (fast, execution, documentation/guided), independent attempt/run IDs and feature source digest, no capture in Fast, no screenshots or intentional waits in Execution, selected screenshots and action-aware holds in Guided. Paired HTML links both videos from separate passed attempts after matching provenance. CI resets synthetic state between all three runs and verifies twelve scenario executions. CI and actual duration inspection pending; calibration, focus, static framework export and core extraction remain follow-up.

## Portable documentation model and export

Dual-profile CI verified in [45977292382](https://github.com/sergii/domstride/actions/runs/45977292382): 12 scenarios / 111 steps passed across Fast, Execution and Guided. Downloaded original videos measured 1.44 s (Execution) and 12.36 s (Guided); 11650 ms intentional guided holds, zero execution holds. New reference model shared by HTML and offline Markdown/MDX export; local publication manifest with checksums and allowlisted screenshot/video media, no raw logs copied. CI verification pending for this change. Generic MDX is not yet a native Starlight/Fumadocs integration.

## Starlight reference iteration

Portable model and static export passed in CI run 45979024431. Implemented standalone Starlight reference site with generated namespace, native Steps, navigation/TOC, integrity-checked local assets, two video profiles, desktop/mobile smoke. Actual site build and CI browser verification passed. No hosted site or production plugin yet.

## Verified Starlight reference (2026-11-27)

[CI run 45980012782](https://github.com/sergii/domstride/actions/runs/45980012782), head 64502b65318285711a606ed1cc96083a35d94602: all five workflows passed. Petstore ran 12 cases / 111 steps successfully across three modes. Static exporter produced two guides and eight approved media assets. Starlight build and Chromium smoke passed both scenario routes, six loaded screenshots, two playable videos, native numbered Steps and mobile viewport. [Site artifact](https://github.com/sergii/domstride/actions/runs/45980012782/artifacts/15188339187) contains built dist and desktop/mobile screenshots; retention seven days. Downloaded archive inspected: positive page has eight native Steps entries, six images, two videos; no raw NDJSON in dist. Desktop/mobile CI screenshots visually inspected. Local independent browser navigation was blocked by the execution environment, not an observed site failure.

Next UX work: separate reader-facing Overview, Actors, Prerequisites and Expected results into meaningful headings; put source/attempt/timing provenance in an expandable technical details section; avoid exposing setup assertions as user instructions; use task-oriented wording from explicit specification metadata, not invented actions; retain original Gherkin and distinguish verification from actual user actions. Add real links between related scenarios. Keep native Steps, accessible images and ordinary video controls. Validate these changes before adding another framework. This is a reference integration, not a released plugin or hosted site.

## Reader-facing guide iteration

Reference static export now separates Overview, Business value, Actors, Prerequisites, initial context, actual action steps and verified outcomes using inherited Gherkin keyword semantics. Preserve exact step wording rather than invent navigation instructions. Only actions enter Starlight native numbered Steps; screenshots remain attached to their original context/action/outcome. Original executed steps, attempt IDs and provenance are collapsed in Technical details; related scenario links resolve to actual routes. Negative examples remain separate attempts. Model classification test and stronger Starlight smoke added. CI verification pending; standalone HTML report retains its existing technical presentation for now.

## Fumadocs reference iteration

Reader-facing Starlight guide passed after distinguishing related-scenario link from pagination in CI 45989250145. Added a shared publication importer and Fumadocs static Next.js reference with native Steps, MDX, sidebar, TOC and local approved media. Search intentionally disabled in the initial static reference. CI build and browser smoke pending. No hosted deployment or released plugin. See [Fumadocs reference](../../examples/petstore/fumadocs/README.md).

## Guided focus reference

Fumadocs dependencies and static build passed in CI 45992816860; browser smoke failed on exact accessible heading name (investigating anchor-copy label). Updated heading assertion and failure artifacts for diagnosis. Guided reference now applies a temporary 3 px emerald outline to the five form fields and publish button, holds before/after meaningful actions, and removes the annotation before normal screenshots. Fast/Execution bypass all focus DOM operations and presentation waits. Internal focus-proof PNG and six-focus count verified by CI assertions; actual recorded visibility still needs media inspection. No calibrated offsets, Smart Zoom, or production focus protocol yet.

## Smart Zoom geometry groundwork

Guided-only capture records six observed target rectangles with actual runtime step IDs, viewport dimensions, Node wall/monotonic observation times and raw Screencast frame timestamps/receive times. No additional capture in Fast/Execution. Offline crop candidates preserve aspect ratio and target visibility, clamp to viewport, and cap magnification at 2.5x. Unit tests cover center, edges, full viewport and invalid bounds. These are geometry observations, not calibrated video cues: no playback-time mapping or zoomed media is claimed. Raw focus metadata stays outside the approved static publication. CI and media inspection pending.
