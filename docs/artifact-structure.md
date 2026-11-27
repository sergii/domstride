# Living Documentation artifact structure

Target extension, backwards-compatible with [Protocol v1](protocol.md). Existing case folders, exporters and legacy domstride-recording-* remain valid. Add optional files before changing existing consumers.

```text
artifacts/
  specification.json
  run.json
  messages.ndjson
  domstride-case-001/
    case.json
    video-01.webm
    subtitles.vtt
    chapters.vtt
    snapshots/
      step-001-before.html
      step-001-after.html
    screenshots/
      step-001-listings.png
      step-002-listing-form.png
      step-003-details.png
      step-004-published.png
    traces/
      playwright-trace.zip
  documentation/
    index.html
    LST-001.html
    LST-001-01.html
    LST-001-02.html
```

Names above illustrate intended layout; a case directory is one execution attempt, not a stable scenario identifier. Use separate run roots and unique case IDs; do not overwrite retries or parallel runs. Finalize attachments before manifest; only list actual files. Raw messages are optional for non-Cucumber producers. Generated documentation is rebuildable, not a source of truth.

## Contracts

- specification-v1: feature/scenario IDs, titles, descriptions, actors/preconditions (structured from agreed description headings), rules, steps, tables, source locations, tags, examples, source revision/digest.
- run-v1: run ID, commit/build, source digest, environment, actual platform/driver/browser/device, locale, viewport, start/end, status and attempt links.
- case-v1 (existing): authoritative framework status and measured durations; optional feature/scenario/example/attempt references; steps, assertion_events, videos with cues and focus. Extend with optional screenshot references, source mapping, action/attachment provenance and clock quality. Do not duplicate the timeline.
- suite-v1 and documentation-v1: future grouping and publication policy, only if needed.

DOM snapshots are HTML/JSON state; screenshots are rendered pixels, not interchangeable. Evidence references must include step/action identity, capture phase, source kind, actual platform and dimensions where applicable. Keep screenshot capture timestamps separate from verified media offsets. Store VTT subtitles/chapters only from verified offsets, no guessed time alignment. Preserve case outcome when recording fails, expose evidence failure.

Retain existing bounds, schema/version checks, inert HTML and path validation; extend limits deliberately for images and traces. Never follow untrusted paths, symlinks or external media URLs. Synthetic fixture data only for public docs; raw logs, NDJSON, screenshots, snapshots, video and traces are sensitive. Redact before persistence, not merely in UI. Publication is opt-in with a safe allowlist, retention and access controls.

## Multiple video profiles and publication (proposed)

Each video reference has a role (execution or guided), actual attempt ID, source asset identity, media duration distinct from test duration, recording platform, clock quality, and optional role-specific cues/chapters/subtitles. Separate executions belong to separate case attempts; a derived guided edit retains original evidence and an explicit edit/time mapping. No false execution timings. Keep existing video-01.webm compatible. Publication manifest maps selected approved media to relative paths or authorized object-store/CDN references and checksums. Never publish raw Messages, snapshots, logs, traces or private recordings by default. See [documentation publishing](documentation-publishing.md).
