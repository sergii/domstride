# Architecture and benchmark policy

ADR-001: independent implementation, one modular gem. rails-jsdom is prior art, not a copied implementation. Maintain attribution and record upstream commit/license if source is incorporated later.

Ruby Session owns a persistent subprocess; JSON-lines requests are serialized and carry correlation IDs. The worker executes synchronous DOM actions with jsdom and returns scalar results. No full HTML snapshots by default. Only trusted test fixtures are supported: jsdom script execution is not a security sandbox.

MVP exclusions: Rails requests, virtual clock, async settling, Turbo/Stimulus, forms beyond click, production-grade process timeout, packaging JS dependency installation and browser conformance. Never claim browser equivalence until tested.

Benchmark policy: run identical code with Node and Bun on the same VM, record runtime versions and CPU metadata, repeat 5 times, distinguish cold startup from warmed click/assert IPC. Report medians and all raw samples. Synthetic counter benchmark does not measure Rails or compare against upstream. Next: pinned upstream baseline, Rails fixture app and Chromium parity, then profiling and selective optimization.

## ADR-002: experimental engines and batch commands

The runtime takes an explicit DOM engine argument. Happy DOM is an experimental adapter; inline script evaluation is enabled for trusted fixtures only, with external JavaScript/CSS loading disabled. Neither engine is a security sandbox.

Batch commands preserve synchronous order, check every intermediate assertion, and stop at the first failure. No rollback or async settling is promised.

EXP-002/003/005/006: four runtime-engine combinations, five rotated-order repeats, individual vs batch with identical assertions, fresh process vs persistent worker with identical remounts, and Linux worker VmHWM (peak RSS). Report experimental failures explicitly. Lockfiles are collected as artifacts until committed. No browser or Rails parity claim.

## ADR-003: Rails reference and real Hotwire

Reference application uses Rails 8.1.4.1 and Ruby 4.0.10, a real controller and ERB rendering, real Stimulus/Turbo bundles, and a read-only same-origin GET Rack bridge. Requests from JavaScript travel back through the JSON-lines protocol. Polling wait_for_text is bounded and explicit; not a virtual clock or universal settling algorithm. IntersectionObserver is a no-op compatibility stub for this fixture only; no lazy-frame or layout parity. Chromium comparison uses HTTP/Puma and real browser auto-waiting, while Domstride uses in-process Rack and synthetic DOM; same observable outcomes, different execution layers. Report failures rather than comparing incomplete scenarios.

## ADR-004: stateful reference

Use actual ActiveRecord persistence with a temporary file-backed SQLite database, Rails cookie session middleware, CSRF protection and a fixture-only credential check. Rack::Test handles session-local cookies; Set-Cookie is not exposed to JavaScript. Same-origin URL-encoded POST and GET only, no redirects or multipart. Explicit browser-parity limitations remain. Benchmark includes invalid and valid form submission, login and persistence verification after a new page visit. RSpec smoke example uses the same public session API, not a framework adapter.

## ADR-005: Capybara adapter

Expose a limited driver using document-scoped element handles with stale detection, CSS and engine-dependent XPath, simple text input, click, DOM visibility approximation, and query retries. Unsupported geometry and interaction semantics must not silently pass. Session reset currently replaces the worker. Benchmark uses the exact same Capybara scenario and persistence checks on Domstride and Cuprite. No claim of full Capybara driver conformance.
