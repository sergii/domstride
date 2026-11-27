# Screenshot and snapshot policy

Target design. Screenshots capture actual rendered pixels from a real browser/device; DOM snapshots capture logical state for replay/debugging/AI, not guaranteed CSS fidelity. Browserless Domstride cannot claim browser screenshots without a rendering adapter.

Strategies: none, every_step, every_action, on_change, checkpoints, on_failure, final. Documentation defaults to selected checkpoints plus final; avoid dozens of duplicate screenshots. Fast defaults to none. Debug may use failure screenshots and snapshots. Capture after the action and meaningful app state is ready, not after arbitrary sleeps. Use final actual result before teardown. Allow viewport or element-only capture, keep target context if cropped. Captions and links derive from associated Gherkin source, not generated invented instructions.

Record step/action identity, before/after phase, actual URL (redacted), capture time, dimensions, coordinate space and optional bounds. Keep original pixels distinct from optional presentation overlays. Green outline for passed active target (#10b981); failures may use red. Viewer focus works only with measured geometry and verified video offsets; account for viewport, DPR, letterboxing, crop, iframe and scroll. No double highlighting if baked into media.

Example policy (illustrative, not implemented config):
```yaml
documentation:
  enabled: true
  audience: [seller, product_manager, qa]
  layout: [overview, business_value, actors, preconditions, business_rules, walkthrough, expected_results, video, related_scenarios]
  screenshots:
    strategy: checkpoints
    format: png
    placement: inline
    include_final: true
    highlight_target: true
  video:
    enabled: true
    placement: bottom
    subtitles: true
    chapters: true
    smart_zoom: true
  technical_details:
    collapsible: true
    default_expanded: false
```

Choose checkpoints via source/step IDs and explicit annotations in sidecar or adapters, never by duplicating business logic. Do not expose production customer data, private attachments, credentials or tokens. For reference use synthetic data only. Missing screenshot is not a failed business test; show missing evidence and don't publish unverified pages as current.
