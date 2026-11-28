# Domstride roadmap

Ordered work, not a commitment to a release date. Keep related changes in one functional batch with tests and documentation.

| Priority | Batch | Scope | Status |
|---|---|---|---|
| 1 | 008 | Interaction recording and DOM replay: target highlight, live control state, before/after, configurable sidebar position | Verified (45914593771) |
| 2 | 007.1 follow-up | Fizzy functional compatibility; investigate direct eval bundler warning and subsequent observed failures | 1/8 original cases verified; resize/editor APIs remain |
| 3 | 009 | Interactive HTML test reports: suite/scenario navigation, automatic test-framework step and assertion mapping, replay timeline | 009.1 verified (45921278517); 009.2 verified (45921849166); 009.3 verified (45922715942); 009.4 verified (45924024922) |
| 4 | 010 | Real-browser video recording and shared report integration | 010.1 verified (45924024922); Protocol v1 / standalone Studio verified (45924668233) |
| 5 | 011 | Performance optimization and benchmarks | Planned |
| 6 | 012 | [Executable Living Documentation](roadmap/batch-012-living-documentation.md) | Reference implementation; CI pending |
| 7 | 013 | [Rails UI Intelligence: Herb static analysis + runtime evidence](#batch-013-rails-ui-intelligence) | Research backlog; optional, non-blocking |
| 8 | 007.2 | Webpack and legacy frontend asset compatibility, informed by local experiment | Deferred to last |

Replay viewer must support viewport left / steps right and steps left / viewport right, without changing the current event or before/after selection. Default viewport left. On narrow screens stack panels in selected order. Selected operation and exact corresponding target must be clearly outlined in green. The preview is reconstructed from saved state and does not execute application scripts or repeat actions. Full visual browser fidelity is not promised. Existing recording is opt-in; raw snapshots and replay reports are sensitive. No automatic publishing or upload.

## Resume original roadmap after Playwright reporter

- 010.2a: native Playwright Test reporter verified (45924985700).
- 010.2b: isolated Xvfb/FFmpeg automatic Selenium and Cuprite recording implemented; CI pending. Headless capture remains future.
- 010.3: cue import and one-way seeking verified (45925493199); bidirectional playback highlight and real URL reference verified (45926523887 / 45926523970); X11 capture workflow still unverified. Playwright clock alignment remains future.
- 010.4: smart zoom / element focus protocol, viewer and explicit viewport geometry helper implemented; CI pending. Automatic geometry/timing calibration and higher-quality capture presets remain follow-up.
- 011: performance optimization, local worker reuse experiment, reporting overhead benchmarks.
- 012: [Living Documentation](roadmap/batch-012-living-documentation.md); independent reference, then Studio integration.
- 007.1: finish real-app compatibility; Fizzy blockers remain explicit.
- 013: optional Herb integration research after Living Documentation foundations; does not block compatibility, performance or release readiness.
- 007.2: Webpack/legacy frontend compatibility remains last, as requested.

No separate product or repository. Further cross-platform adapters are backlog, not a prerequisite for resuming the original plan.

## BATCH-013: Rails UI Intelligence

Status: Research / planned. No implementation or mandatory dependency approved. Keep the existing browserless runtime, browser parity and fast execution path independent of static analysis.

Investigate [Herb](https://github.com/marcoroth/herb) ([documentation](https://herb-tools.dev/)) as an optional static HTML/ERB analysis adapter. Combine template AST evidence with Domstride runtime DOM, interaction traces, assertions and executable living documentation. Consider Prism for Ruby expressions and Rails helpers where appropriate; do not execute application code for static discovery.

### Research milestones

- [ ] Evaluate supported Herb versions, Ruby/Rails compatibility, API stability, parser diagnostics, licensing and parsing overhead using public synthetic Petstore templates.
- [ ] Discover forms, fields, buttons, links, labels, test IDs, conditional branches, partials and potential interactions; retain file path, source range, stable candidate identity and confidence. Record unresolved helpers, component boundaries and dynamic/JavaScript-generated DOM separately.
- [ ] Prototype source-to-runtime mapping using explicit stable IDs or other defensible evidence; handle repeated partials, conditional rendering, roles/permissions, Turbo updates and ambiguous matches. Preserve unmatched runtime elements and static candidates.
- [ ] Produce an opt-in UI interaction coverage report: observed, not observed, not rendered in this run, ambiguous/unresolved, and excluded with reason. Separate rendering, interaction and assertion evidence; report the denominator and scope, never treat this as complete functional coverage or automatically label an unobserved candidate a missing test.
- [ ] Explore test suggestions, source links in Studio replay, accessibility diagnostics, and living documentation enrichment with provenance. Keep suggestions distinct from verified outcomes; do not invent steps, assertions or results.
- [ ] Define a versioned adapter-neutral evidence schema, tests and privacy controls (local/private by default; no automatic upload or publication of template source, DOM or sensitive values).

### Acceptance gates for a proof of concept

Use a public/synthetic Rails Petstore fixture with a form, a conditional control, a repeated partial and a dynamically added element. Demonstrate reproducible AST inventory and runtime interaction mapping, including deliberate unmatched/ambiguous cases; show source locations, evidence and honest coverage scope in a small report. Compare fast-mode performance with integration disabled against the existing baseline; no parser dependency, extra UI queries or capture required in normal execution. Document limitations, false positives and go/no-go criteria before proposing production integration. Keep Herb-specific types outside the core protocol where practical.

## Consolidation before core extraction

See [MVP consolidation review](mvp-consolidation.md) and [Petstore performance evidence and native/WASM research](petstore-performance-native-wasm.md). Keep experimental optimizations opt-in. Core Extraction & Packaging follows a reviewed consolidated baseline.

## Core Extraction & Packaging

[Six-phase Core Extraction & Packaging](core-extraction-packaging.md): independent installed consumer verified on 03d8d50 (19/20 workflows, known Fizzy limitation). Final audit hardening CI pending. No merge or release. General publication, redaction, npm distribution and independent third-party Viewer remain follow-ups.

## Specdrive Product Separation & Rebranding

See [product separation and migration](product-separation.md). Phase 1 introduces compatible public names; independent Viewer extraction, package rename and release are separate review gates.
