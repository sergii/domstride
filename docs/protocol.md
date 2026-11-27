# Domstride Protocol v1

One product and repository, separate execution and evidence boundaries. Studio consumes files, never needs a running Domstride worker or Rails app. The Ruby exporter remains a packaging implementation detail, not a requirement for evidence producers. Existing report directories remain compatible.

## Local case bundle

A suite is a directory of independent domstride-case-* directories. Each directory owns one test execution (not a global test definition). Its case.json manifest uses format "domstride.case" and schema_version 1. Older manifests without format are supported. A producer must write the manifest only after its attachments are finalized. Unknown major versions and unknown explicit formats are rejected.

Required: name, status (passed/failed/skipped/pending/unknown), duration_ms (nonnegative milliseconds, measured by the producer). Optional metadata: producer, framework, runner, platform, language (arbitrary bounded names, not an engine whitelist), assertions (framework total, if known). Framework outcome is authoritative; action status cannot imply test status. Missing evidence is valid.

Optional steps and assertion_events use ordered one-based sequences and duration_ms. Assertion step_sequence references an existing step or null. No requirement for DOM evidence. Videos are local WebM files video-01.webm through video-04.webm, referenced in the ordered videos array with label. Existing optional domstride-recording-* directories contain version-1 events.jsonl and named before/after HTML snapshots; see recording implementation for the legacy trace subformat. No remote URLs or path traversal in attachment references. All inputs are untrusted data; HTML is inert. No automatic uploads.

See protocol/case-v1.schema.json. The schema describes structural constraints; the exporter additionally enforces UTF-8 byte limits, contiguous sequences, reference integrity, filename order, file bounds and symlink restrictions. Schema is intentionally extensible; unknown fields are ignored for rendering except existing trace subformat. Current implementation limits 100 cases, 200 recordings, 32 MiB combined trace/video evidence, 256 KiB metadata per case, 8 MiB per video. No cross-run test identity, unified clock or external HTTP/mobile evidence format yet.

## Independent producer

examples/protocol/write_case.cjs writes a case using Node standard library, independent of Ruby, Capybara or Domstride Runner. Chromium video reference produces its case through this writer and renders it with the standalone Ruby report entrypoint. Other languages can implement the same contract. For source checkout: ruby -Ilib exe/domstride report CASE_DIRECTORY. No bundle install or npm install needed for rendering alone. Browser needed only to view the exported HTML. Installed gem still carries runner dependencies until a later packaging decision.

## Architectural direction

Runner: execute browserless interactions. Studio: inspect artifacts produced by any runner. Protocol: versioned artifact boundary. Keep a single product and repo for now; separate package distribution, actual Playwright Test reporter, Selenium/Cuprite recording adapters, mobile evidence and richer suite identities are subsequent work, not implemented claims.

The native [Playwright Test reporter](playwright-reporter.md) is a source-checkout adapter using adapters/protocol/write_case.cjs; CI pending.

## Video cues (optional v1 extension)

Each video attachment can include cues: [{kind: "step" or "assertion", sequence: existing case step/assertion sequence, time_ms: nonnegative playback offset}]. At most one cue per kind/sequence per video, 300 total. Producer owns timestamp evidence; viewer never estimates offsets from duration. Older videos have no cues. Seek after metadata load, keep video selection and display unavailable cues honestly. X11 adapter derives offsets from actual showinfo first-frame epoch PTS, normalized output PTS, paired wall/monotonic clock sample and ffprobe duration; drop out-of-range cues or clock drift >50 ms. Step cues mark start, assertion cues mark completion. Approximate frame-level correlation, not exact browser event time. Playwright video origin is not exposed in current reporter; no automatic offsets there. Browser contract tests use explicit synthetic offsets to verify seeking separately from X11 producer verification.

Playback updates active steps and assertion highlights from the selected video's cue offsets on timeupdate/seeking/seeked/play/pause/ended. Latest step-start cue stays highlighted until the next mapped step; assertion completion highlights clear when entering a later step. Unmapped events are not guessed. Reference navigation uses actual loopback HTTP pages, not setContent/about:blank. Video-only cases show video playback rather than incomplete DOM recording notice.

## Video focus (optional v1 extension)

A video may declare `focus` segments (max 300): kind fill/click/select/assert, status passed/failed/unknown, start_ms/end_ms on that video clock, and normalized x/y/width/height in the entire encoded frame. Segments are sorted, non-overlapping and bounded within the frame. Viewer applies a reversible CSS transform, capped by selected zoom intensity and target fit, with optional green/red outline. Gaps return to full frame. Custom playback controls remain outside the transformed frame. Reduced motion is respected. Producer supplies measured geometry and verified video clock; no invented coordinates for uninstrumented recordings. `adapters/playwright/viewport_target.cjs` provides explicit bounding-box normalization for matching viewport-only video dimensions, not automatic reporter capture or a clock anchor. Reference browser test uses measured boxes and explicit synthetic cue intervals to test presentation. X11 full-display coordinate calibration, automatic interaction hooks and higher quality presets remain follow-up; no claim of their implementation.

## Optional observed focus intervals

A video can declare `timing_quality: visual_candidates_unvalidated` with normalized `focus` intervals. Each observed interval must identify an existing `step_sequence` and a bounded plain-text `label`; do not mix with point `cues`. Intervals are ordered, non-overlapping and have positive duration. These observations describe visible focus in the encoded media, not exact action boundaries; uncovered time has no active step or caption. The Core Replay creates reusable native caption/chapter tracks and displays captions outside the zoomed viewport. The recorded outline is baked into the media. Legacy videos without this timing quality keep their original point cue and overlay behavior. Reference-only visual detection is not a general clock calibration guarantee.
