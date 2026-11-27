# Domstride roadmap

Ordered work, not a commitment to a release date. Keep related changes in one functional batch with tests and documentation.

| Priority | Batch | Scope | Status |
|---|---|---|---|
| 1 | 008 | Interaction recording and DOM replay: target highlight, live control state, before/after, configurable sidebar position | In progress |
| 2 | 007.1 follow-up | Fizzy functional compatibility; investigate direct eval bundler warning and subsequent observed failures | Next |
| 3 | 009 | Interactive HTML test reports: suite/scenario navigation, automatic test-framework step and assertion mapping, replay timeline | Planned |
| 4 | 010 | Real-browser video recording and shared report integration | Planned |
| 5 | 011 | Performance optimization and benchmarks | Planned |
| 6 | 007.2 | Webpack and legacy frontend asset compatibility, informed by local experiment | Deferred to last |

Replay viewer must support viewport left / steps right and steps left / viewport right, without changing the current event or before/after selection. Default viewport left. On narrow screens stack panels in selected order. Selected operation and exact corresponding target must be clearly outlined in green. The preview is reconstructed from saved state and does not execute application scripts or repeat actions. Full visual browser fidelity is not promised. Existing recording is opt-in; raw snapshots and replay reports are sensitive. No automatic publishing or upload.
