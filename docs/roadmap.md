# Domstride roadmap

Ordered work, not a commitment to a release date. Keep related changes in one functional batch with tests and documentation.

| Priority | Batch | Scope | Status |
|---|---|---|---|
| 1 | 008 | Interaction recording and DOM replay: target highlight, live control state, before/after, configurable sidebar position | Verified (45914593771) |
| 2 | 007.1 follow-up | Fizzy functional compatibility; investigate direct eval bundler warning and subsequent observed failures | 1/8 original cases verified; resize/editor APIs remain |
| 3 | 009 | Interactive HTML test reports: suite/scenario navigation, automatic test-framework step and assertion mapping, replay timeline | 009.1 verified (45921278517); 009.2 verified (45921849166); 009.3 verified (45922715942); 009.4 verified (45924024922) |
| 4 | 010 | Real-browser video recording and shared report integration | 010.1 verified (45924024922); Protocol v1 / standalone Studio verified (45924668233) |
| 5 | 011 | Performance optimization and benchmarks | Planned |
| 6 | 007.2 | Webpack and legacy frontend asset compatibility, informed by local experiment | Deferred to last |

Replay viewer must support viewport left / steps right and steps left / viewport right, without changing the current event or before/after selection. Default viewport left. On narrow screens stack panels in selected order. Selected operation and exact corresponding target must be clearly outlined in green. The preview is reconstructed from saved state and does not execute application scripts or repeat actions. Full visual browser fidelity is not promised. Existing recording is opt-in; raw snapshots and replay reports are sensitive. No automatic publishing or upload.

## Resume original roadmap after Playwright reporter

- 010.2a: native Playwright Test reporter verified (45924985700).
- 010.2b: isolated Xvfb/FFmpeg automatic Selenium and Cuprite recording implemented; CI pending. Headless capture remains future.
- 010.3: cue import and one-way seeking verified (45925493199); bidirectional playback highlight and real URL reference added, CI pending; X11 capture workflow still unverified. Playwright clock alignment remains future.
- 011: performance optimization, local worker reuse experiment, reporting overhead benchmarks.
- 007.1: finish real-app compatibility; Fizzy blockers remain explicit.
- 007.2: Webpack/legacy frontend compatibility remains last, as requested.

No separate product or repository. Further cross-platform adapters are backlog, not a prerequisite for resuming the original plan.
