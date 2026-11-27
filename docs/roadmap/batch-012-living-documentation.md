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

## Media clock investigation

CI 45994018831 identified Playwright 1.59 onFrame's actual type as data-only. Preserve receive sequence/bytes and Node receive timestamps, not invented browser capture timestamps. Keep the pinned dependency. Downloaded guided artifact from CI 45993679060: 13.64 s media; actual Title outline verified in PNG and decoded video frames at PTS 2.44 through 3.32 s inclusive. Fumadocs diagnostic static HTML confirmed Overview heading has an additional Copy Anchor Link button; select the exact anchor text inside the heading. Add reference offline ffprobe/ffmpeg visual matching of observed target rectangles to green outline bands, producing conservative candidate intervals and rejecting ambiguous/overlapping detections. Candidate intervals are not yet validated cues, not actual action start/end or synchronized playback. New CI pending. No production clock calibration or zoom animation yet.

## Focus replay prototype

CI 45994829613 passed typecheck, 12 scenarios / 111 steps, geometry validation and static export, then stopped because ffmpeg was not installed on its runner. Added explicit ffmpeg installation. Offline inspection of downloaded artifact 15195238378 (341 decoded frames, 1280x800) using the same outline-band matching rules found six ordered non-overlapping candidates: Title 2440–3280 ms, Description 3360–4200 ms, Category 4280–5120 ms, Condition 5160–6000 ms, Price 6080–6880 ms, Publish 8120–8800 ms. These are observed visible-frame intervals, not action boundaries. Added standalone experimental focus replay generator with embedded original WebM, seekable candidate actions, active runtime step highlight and reversible viewport crop, deterministic 120 ms easing. Other steps and unmatched intervals remain uncalibrated. Local generated HTML syntax checked; browser verification pending. Core Replay Viewer and static publication unchanged. Fumadocs was not reached in this CI run.

## Focus replay browser verification and WebVTT

CI [46012940852](https://github.com/sergii/domstride/actions/runs/46012940852) passed all five workflows, 12 acceptance scenarios / 111 steps, six matched focus candidates in a second independent run (345 frames), Starlight and Fumadocs full browser smoke. Added observed-interval WebVTT captions and chapter tracks, seekable timeline segments, caption toggle and Chromium smoke for action/step activation, seek, zoom toggling, playback, tracks and mobile overflow. No invented cues for unmatched time; captions describe visible focus, not speech or complete Gherkin narration. Browser smoke for the new viewer is pending. Static framework publications and core replay remain unchanged.

## Core replay integration

CI 46016263083 verified experimental Focus Replay browser smoke, Starlight, Fumadocs, six focus candidates in a third independent recording and all five workflows. Extend the existing case v1 video focus segments with optional visual_candidates_unvalidated timing quality, step sequence and label. Reference producer attaches only observed normalized intervals to the guided manifest; old point cues remain unchanged. Ruby Report validates these fields and rejects mixing observed intervals with point cues. Core Replay uses existing zoom, action chapter buttons, focus captions and step seek/activation only inside observed intervals. Recorded outline remains baked into the video; avoid double outline. Add CI smoke using actual Ruby Report export. Experimental viewer retained during migration; native text tracks remain in reference viewer and VTT sidecars, not yet wired into core. CI pending for core integration.

## BATCH-012 integration review (2026-11-27)

CI [46043769891](https://github.com/sergii/domstride/actions/runs/46043769891) on head 81299b8 verified all 12 Petstore acceptance scenarios / 111 steps, six observed actions, experimental and core Replay browser smoke, both static frameworks, and legacy reference. 18 of 19 workflows passed; [Fizzy discovery](https://github.com/sergii/domstride/actions/runs/46043769783) failed in lightbox, navigation and create_card (missing ResizeObserver and ElementInternals.setValidity among errors). Keep PR draft and do not merge until regression disposition is explicit. Added native caption/chapter TextTracks to core, reused and cleared on media changes, while custom captions remain outside zoomed viewport. Recorded outline cannot be switched off; disable the redundant overlay control in observed mode. Added validation for malformed focus intervals and legacy exports, and browser checks for track lifecycle. New CI pending. Preserve experimental reference for now as a regression fixture; removal, production timing calibration, universal producer, native mobile adapters, storage publication, and generic plugin packaging are outside this milestone. No hosting or release performed.

## Replay entry-point UX

User reported the downloaded core report opening a negative example without recorded evidence. Root cause: case directory ordering by random attempt ID selected an arbitrary first case, while only the @replay positive scenario had video. Prefer a video-bearing case on initial load (DOM recording fallback), keep explicit selections on filtering, label evidence availability in selector, and show results-only empty state with a shortcut to a recorded case instead of a misleading blank DOM preview. No new recording or fake evidence for negative cases. Add smoke coverage for actual initial selection and return from results-only case. Previous native track/protocol CI 46052047925 passed; latest UX CI pending.

## Replay UI polish

User feedback: restore semantic and recorded action icons, distinguish form fill/select/click/submit, visually de-emphasize measured duration and status, align zoom controls, and make navigation after submit understandable. Core Viewer now renders local SVG icons, readable step cards with action chips, muted metadata, compact controls and a short hourglass/page transition annotation. Reference producer marks navigation only when the confirmed publish result has a different URL. The overlay is a 650 ms editorial playback cue after visible click focus, not a measured server wait or altered recording. Fast and Execution remain unchanged. Preserve the legacy evidence selector for video-only cases (previous UX change caused browser contract timeout in CI 46053814257). Latest CI pending; Fizzy remains separate unresolved compatibility issue.

## Neutral blue product palette

User requested a universal enterprise blue/gray/white palette rather than emerald. Keep current layouts, sizes, spacing and icon paths. Use blue #2563eb for active states, outlines and controls, light blue #eff6ff for selected surfaces, slate neutrals for text/borders, and green/red only for semantic success/failure. Align core Replay, experimental reference player and Domstride-owned documentation themes. Do not recolor the application under test or alter historical recordings. New guided focus annotations are blue and declare outline_color; visual detector supports explicit blue and defaults to historic green when the field is absent. CI must reconfirm all six media intervals and actual browser UI. No new layout redesign or merge.

## Replay refinement: icons, evidence styling and summary

Replaced hand-drawn icons with vendored Lucide 0.456.0 SVG geometry and embedded license, introduced consistent native select controls, default subtle hatch for missing replay evidence with toggle, concise evidence labels and six summary pills. Added Chromium assertions for UI and icon mapping. Full step highlighting beyond observed focus intervals requires independent calibrated step intervals; documented [design and acceptance](../replay-ui-refinement.md) instead of inventing timing from durations. No new capture work in this commit. CI pending.

## Replay refinement CI fixes

CI 46058398023 confirmed the new icon/shading/summary assertions until a higher-specificity obsolete select rule overrode the shared padding (9 px vs 30 px). Remove that redundant rule. CI 46058397983 failed on the old single-line summary expectation; assert all six distinct pill values instead, and explicitly verify results-only/no-match empty states. Preserve filtering and recording selection tests. Fizzy remains unresolved. New CI pending.

## Header and shape preferences

Default Rounded controls (7 px) and tags (5 px), optional Pill (999 px) via a live Shape selector. Only small controls and badges change; step cards, panels and video stay unchanged. In suite header, actual selected-case metadata renders as compact labeled tags near summary pills. Search comes first and filters the adjacent native test dropdown; status stays separate. Keep native selects for keyboard/accessibility and regression compatibility rather than introducing a custom combobox in this iteration. Remove duplicated producer metadata from case labels. Hide the DOM recording selector if no DOM recording exists; retain the video recording selector and legacy DOM navigation. Preference is per open report, no persistence or second exported HTML. Add Chromium regression checks. CI pending.

## Minimal inspector and rounded-only controls

User chose Rounded only; remove shape preference and Pill. Native checkbox semantics with custom compact 16 px blue/white appearance, visible focus and disabled state. Add default-off Inspect elements checkbox. Tooltip uses text-only recorded tag/id/name/data-testid/type/aria-label; omit missing fields and do not collect values, HTML snippets, selectors or recommendations. Snapshot metadata stays in an internal lookup, never copies IDs or arbitrary attributes into live DOM; preview remains inert. Video inspection limited to existing observed focus interval and normalized geometry, including zoom transform; no full element map, no screenshot inspection, no new fast/execution capture. Reference producer captures bounded attributes only for guided targets, excluding password/hidden/file inputs; generic snapshots can already contain application metadata and must be sanitized before sharing. No claim of universal redaction. Schema/report validation reject unexpected metadata fields. Add browser and malformed protocol tests. Full step timeline remains separate. CI pending.

## Inspector CI follow-up

CI 46062414711 passed DOM inspector and legacy recording tests. CI 46062414761 passed until the video hover assertion: tooltip stayed hidden. Raw mouse coordinates may be outside the scrolled playback panel. Stabilize paused media time and zoom before locator-relative hover; re-evaluate tooltip on scroll rather than losing the pointer and reject hits outside the visible preview. Root cause not yet confirmed by a passing rerun. New CI pending; Fizzy remains separate.

## Experimental full-step timeline

Verified inspector CI 46063078874 (18/19 overall; Fizzy unrelated compatibility still failing). Reference Guided capture now emits brief 32x32 visual landmarks in bottom-right at each complete step boundary (160 ms holds). Authentication stays outside recording. Landmarks are intentionally visible diagnostic annotations in the raw guided recording, not application UI or server latency; no new landmarks in Fast or Execution. Decoder matches actual frame PTS using sync rows and binary code, requires contiguous detections and rejects overlap. Core protocol separates step_intervals from focus geometry; step highlight/seek uses matched full intervals, action chips and zoom remain tied to actual focus. CI requires every complete recorded reference step to resolve; missing boundaries must not become invented cues. Legacy media unaffected. Experimental approach requires CI and visual review; production clean-media clock mapping remains open.

## Action chip interaction and inspector discoverability

User reported that clicking Description then Category did not seek: chips were decorative spans inside the parent step button. Use separate native buttons in a single visual card, each seeking its own observed start timestamp and exposing aria-pressed. Browser smoke now clicks each sidebar chip directly rather than testing only chapter buttons. Move Element inspector into the evidence panel, hide when no metadata/DOM is available, show concise usage hint when enabled and pause video on enable. In CI 46064532880 the experimental full-step decoder resolved seven of eight steps: actual downloaded artifact shows submit end landmark code 8 visible for just one decoded frame. Wait for DOMContentLoaded before end markers and extend guided-only marker hold from 160 to 320 ms; keep the two-frame confidence requirement. Fix smoke gap expectation because first recorded step can begin at PTS zero. New CI pending; do not claim full-step mapping is verified. No changes to Fast or Execution.

## Submit landmark synchronization

CI 46065561540 again resolved all six focus candidates and seven of eight complete steps; submit step had no accepted end landmark, so the core browser smoke was not reached. Increasing the landmark hold alone did not resolve this. In Guided reference only, wait for the actual destination URL, listing heading and confirmation region before the submit step ends and its end landmark is inserted. A Turbo body replacement is not guaranteed to wait for DOMContentLoaded or the click promise. This is a targeted hypothesis, not a verified root cause until CI passes. Existing Then assertions remain unchanged; Fast/Execution behavior unchanged. No fabricated interval for the missing step. New CI pending.

## Full-step reference calibration passes

CI 46066744748 matched all eight complete recorded step intervals and six focus actions after waiting for the rendered Turbo destination. Prototype replay smoke and core report export succeeded. Legacy fixture then failed because it removed timing_quality but retained new step_intervals and step_timing_quality. Remove both in legacy fixture, preserving strict production validation, and add negative tests for missing quality, overlapping intervals and focus without a containing step interval. Core UI smoke not reached in this run. New CI pending; Fizzy remains unrelated unresolved failure.

## Viewer v1 feature freeze (2026-11-27)

Baseline verified in CI 46067542697 on 88d131b: eight complete recorded steps, six focus actions, independent sidebar chip seek, core and prototype Chromium smoke, twelve malformed manifest tests, legacy export, Starlight and Fumadocs. 18/19 workflows passed; Fizzy compatibility remains unresolved. Final cosmetic change: use original Lucide 0.456.0 package/hash/tag/target/text-cursor-input icons at 12 px in inspector metadata rows. Only actual recorded attributes are displayed; no new data capture. Final cosmetic CI pending.

Frozen v1 scope: offline self-contained report; rounded blue/slate/white controls; summary, provenance, test search/filter/selection; video and inert DOM replay; recorded step and action highlighting/seek; smart zoom; captions/chapters; transition annotation; optional hatch; minimal default-off element inspector. Keep setup outside recording and unknown evidence explicit. No Pill theme, locator generation, advanced explorer, analytics or new capture modes.

Known limitations and backlog: full-step visual landmarks are reference Guided capture only, visible in the raw recording and not general production clock calibration; inspector in video is limited to recorded targets; screenshots are documentation evidence rather than full interactive element maps; native mobile adapters, clean-media calibration, S3/CDN publishing and generalized producer integration remain separate. Do not imply merge/release while Fizzy and final verification remain open. Further viewer work is bug fixes or accessibility regressions only unless explicitly requested.
