# Domstride Living Documentation

Status: accepted product direction, implementation tracked in [BATCH-012](roadmap/batch-012-living-documentation.md).

**Write once. Test continuously. Document automatically.**

Documentation as verified behavior: a single executable Gherkin feature is the source of expected business behavior. Step definitions and adapters execute it; actual run artifacts supply evidence. No manual duplication of user guides or video scripts. A passing test verifies only the behavior and platform tested, not the entire product.

## Three views in Studio

- Test Report: case outcomes, assertions, failures, durations and performance for QA/CI.
- Replay Viewer: DOM snapshots, browser video, step/action timeline, seek, active step, target outline and smart zoom for debugging.
- Living Documentation (Domstride Docs): human-readable, illustrated product behavior for end users, product managers, support, QA and AI agents.

## Documentation page

1. Feature title, stable ID, domain, supported/applicable platforms and verification provenance.
2. Overview, business value, actors and preconditions.
3. Business rules and scenario description.
4. Numbered walkthrough, optionally grouped into readable blocks; retain original Gherkin steps and data tables in expandable details. Insert selected actual screenshots inline immediately after their related steps, with captions. Hide setup by default, allow inspection.
5. Expected results; distinguish actual verification and expected text. Failed or missing evidence must not be presented as passed.
6. Video walkthrough at the bottom, with optional captions, chapters and a link to Replay Viewer. If no video exists, say so.
7. Related scenarios, negative cases and Examples; no claim that all platforms passed based on tags.

Text-only reading, illustrated reading, video and interactive replay all come from the same specification and execution evidence. Do not invent screenshots, results, timestamps or procedural steps. Static documentation can be generated without running the application and is labeled unverified. Group examples without mixing attempts.

## Architecture

- Runner: browserless execution remains performance-first.
- Specification: standard Gherkin AST plus stable identity and optional publication policy.
- Protocol: portable artifact contract. Reuse case-v1 steps, assertions, cues and focus; no competing timeline format.
- Studio: Test Report, Replay and Docs consume artifacts independently of the application or runner.
- Docs: static HTML generation and machine-readable export; logical component, no separate repo/package yet.

Future outputs include business rule catalog, use-case catalog, acceptance criteria, tutorials, cross-platform parity, Jira traceability, release documentation and AI knowledge. A source change or a failed/latest missing run makes evidence stale or unverified; historical recordings stay attributable to their commit/platform. Never label old passing evidence as current.

See [specification standard](specification-standard.md), [artifact structure](artifact-structure.md), [screenshot policy](screenshot-policy.md), [execution modes](execution-modes.md) and [reference example](../examples/petstore/README.md).

Public examples use only public reference applications and synthetic data. No private product names, code, business fixtures or recordings may be copied into the public gem. Keep project structure agnostic; acceptance tests remain in their native location. See [specification organization](specification-organization.md).
