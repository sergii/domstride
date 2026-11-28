# SpecDrive product separation and rebranding

Decision: two products, not four. SpecDrive is the testing engine and evidence producer. The independent Viewer (final name TBD) consumes test artifacts and renders replay, reports and living documentation. It can later expand into test management, but that is not an engine responsibility.

## Phase 1: additive public entrypoints

Expose require "specdrive", SpecDrive::Session, require "specdrive/capybara", the :specdrive driver and specdrive CLI. All share the original implementation and class identity. The existing gem is still named domstride, existing APIs and command names remain valid. No change to default environment variables, runtime cache, producer IDs, artifact wire formats or test execution. Do not rewrite historical artifacts. No new dependencies. Installed-gem and checkout tests cover both names.

## Phase 2: independent consumer boundary

Extract the existing Ruby Report/Replay consumer (report.rb, replay.rb, replay.html, video reader and necessary protocol/error definitions) without loading execution sessions or producer hooks. Split Report.capture from consumer code while keeping the compatibility facade. Audit dependencies, preserve offline security constraints and all existing visual behavior, add independent artifact-only fixtures and packaging tests. Documentation model/export may share the artifact contract; do not require SpecDrive to consume results from other frameworks. Choose Viewer name separately before public package or repository creation.

## Phase 3: canonical package and repository naming

Evaluate gem availability and ownership at release time. Switch canonical gem name to specdrive only after Bundler, installed runtime setup, generators, adapter paths and CLI regression checks. Avoid ambiguous multiple top-level gemspecs during development. Decide on legacy distribution/deprecation policy and namespaced ENV aliases with explicit precedence; do not rename cache keys or wire format merely for branding. Existing artifacts remain readable. Repository rename, external URLs and release tags require a deliberate transition. No public publish as part of this phase.

## Phase 4: independently versioned protocol and distribution

Define producer/consumer compatibility matrix; use existing v1 domstride.* identifiers as legacy wire contract; change only via explicitly versioned migration and fixtures. Decide independent distribution (Ruby CLI and/or Node/browser consumer) after the extracted consumer passes real offline playback and security tests. Preserve source history; no duplicated implementations.

## Phase 5: developer preview

Audit security and redaction scope, release notes, dependency reproducibility, package names/ownership, build artifacts and rollback. Run supported engine regressions, controlled performance comparison and consumer compatibility. Known Fizzy and experimental Bun/Happy DOM limitations remain visible. Require maintainer approval for merge, repository rename and publication.

## Current status

Base: merged PR #19 (cb8222e). Pre-merge reviewed CI 19/20, accepted Fizzy failure. The available commit workflow listing is PR-triggered only, so it does not establish post-merge CI. Phase 1 verified on df4ba26: 19/20 workflows passed; Fizzy remains the accepted failure. No repository rename, new gem publication, independent Viewer distribution or protocol migration yet.

## Phase 2 implementation candidate

The artifact-only API is `require "domstride/consumer"`, then `Domstride::Consumer::Report.export` or `Domstride::Consumer::Replay.export`. The actual report parser, replay reader/renderer and WebM reader now live under lib/domstride/consumer. Legacy Report.capture and Video.attach remain in the producer-facing compatibility files; legacy export/read methods delegate to the same consumer implementation. Existing shared protocol/errors and the original replay.html stay at their paths; template bytes and v1 wire formats are unchanged. No public Viewer brand or package chosen. The isolated CI stages only the consumer allowlist plus a test CLI, invokes Ruby without Bundler (standard Ruby distribution libraries may be gems), tests external framework results, video import and symlink/no-overwrite rejection, and reuses existing offline browser contract tests with no engine present. This is an internal extraction boundary, not a separately published product. Living Documentation exporter separation, real video playback through the staged consumer and independent package versioning are follow-up verification gates. CI pending.