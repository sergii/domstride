# Execution modes

Target behavior, not an implemented CLI contract yet.

| Evidence | Fast | Debug | Documentation | Demo |
|---|---|---|---|---|
| Framework results and specification IDs | yes | yes | yes | yes |
| DOM snapshots | no | yes | optional | optional |
| Screenshots | no | failure/selected | checkpoints + final | selected |
| Video | no | opt-in | selected @replay | selected |
| Captions/chapters and focus | no | optional | when calibrated | when calibrated |
| Artificial presentation pacing | no | no | optional | yes |
| Generated HTML docs | separate offline command | optional | yes | yes |

Same Gherkin and step definitions; modes change capture/presentation only, never business assertions. Fast mode avoids video, screenshot, DOM capture, bounding-box queries and decorative waits; benchmark overhead against uninstrumented baseline. Raw native runner results may be kept. Documentation mode uses only selected synthetic/approved scenarios. Demo is a separate presentation policy, not another set of business tests.

For Playwright use supported screencast APIs when available and pinned (1.59+ baseline from design; custom CSS option requires version verification). Existing Playwright Test reporter copies finalized video but has no verified automatic video clock anchor. Do not conflate Cucumber.js with Playwright Test reporter. Use recorder adapter and raw Messages. Prefer real HTTP URLs, never substitute about:blank for recorded navigation.

Record monotonic and wall origins, recorder frame timestamps and media PTS where available; calibrate offset/drift and label timing quality. If uncertain, omit cues/focus and allow ordinary video playback. Fast actions may occupy one frame; don't promise visibility of every action. VTT and chapters derive from calibrated mapping, not wall time or evenly spaced guesses. Keep CI performance and demo pacing separate.
