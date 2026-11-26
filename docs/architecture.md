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

## ADR-006: upstream benchmark

Compare upstream's public interaction API against the same Capybara-based Domstride scenario on one VM, with equal warm-session repetitions and database persistence checks. Pin upstream commit and JS versions. Upstream uses a separate Rails root for importmap and node_modules and its real settling/clock; the shared controller is identical, but JS boot, jsdom versions and assertion implementations differ. Turbo core is aliased for this fixture; no Action Cable or full upstream compatibility claims. Record errors rather than extrapolating failed runs.

## ADR-007: JavaScript errors

Capture window error/unhandledrejection events, jsdom error events, Node unhandled rejections, and Error objects passed to console.error (including Stimulus). Surface a typed Ruby JavaScriptError with source and message/stack. Check before commands, after one event-loop turn, inside polling waits and after each synchronous batch step. Plain console.error strings remain diagnostic. This is bounded checkpoint detection, not full deterministic settling, virtual time, or proof of absence of errors after the final command. Worker-level rejection attribution and Happy DOM behavior are experimental. Tests cover inline scripts, click handlers, rejected promises, timers, batching and Stimulus actions.

## ADR-008: profile before optimizing

Opt-in wall-time measurements distinguish command counts, protocol bytes, Ruby command wall time, worker command wall time and Rack request wall time. These durations overlap; do not add them or label the residual pure IPC latency. Profile the same stateful workflow with native DSL vs Capybara, jsdom 26 vs 31 vs Happy DOM, and native polling vs MutationObserver. Observer waits have a hard deadline and error callbacks; they do not implement deterministic settling or virtual time. Benchmarks include instrumentation overhead, fixed order, warm sessions and real persistence checks. No payload logging.

## ADR-009: opt-in bundle cache

Separate transport deduplication (source mode) from compiled script reuse (jsdom only). Cache exactly one explicitly marked final classic script per worker, validate SHA-256 and cap source size at 8 MiB. Source mode restores the original HTML before parse; compiled mode executes a cached vm.Script in a new document context after parse, so it cannot preserve parser-time/currentScript semantics and is experimental. Do not cache dynamic HTML, CSRF tokens or session state. Default off. Benchmark cold fresh workers and 50 warm stateful scenarios per configuration with persistence and cache-hit checks, memory and traffic. Fixed-order measurements, not a generic asset pipeline or disk cache.

## ADR-010: Capybara query metadata coalescing

Use Capybara 3.40's existing initial_cache and uses_visibility query hint, without monkeypatching query classes. Prefetch tag name and initial visibility with handles; never cache mutable attributes or visible text for later reads. Visibility is an initial snapshot, not an ongoing truth; Capybara handles filters and retries. Preserve hidden/all visibility, exact text, regexp and custom filters. No speculative text pruning, layout or remote predicate translation. Benchmark same Capybara scenario with prefetch off/on for each engine, bundle cache off, profiling enabled, fixed order. Experimental default off.

## ADR-011: bounded settling and document-local virtual time

Track bridged fetch lifetime from invocation through response creation, DOM mutation activity, due virtual timers and quiet event-loop turns. Bound settling by monotonic real deadline and callback count. Virtual clock uses a document-local timer queue with deterministic due-time/id ordering, explicit advance, Date and requestAnimationFrame shims; remount discards state. No automatic future timer drain after normal actions; wait_for_text advances only within its virtual deadline. Ruby time, performance.now, engine-internal tasks and arbitrary unresolved promises are not virtualized. No claims of full deterministic browser or Rails semantics. Compare real vs virtual timer workload separately from real stateful Rails scenario. Default modes unchanged.

## ADR-012: parallel process scaling and YJIT

Use process isolation rather than Ruby threads for Rails reference scaling: one Rails app, SQLite database, Rack cookie jar and JS worker per Ruby process. Verify distinct DB paths/process IDs, anonymous initial session and exact persisted records after each sample. Fixed total work (32 scenarios) across 1/2/4/8 workers, five repeats, three warmup scenarios per worker; barrier synchronization and parent monotonic wall time include scheduling overhead and persistence checks. Report separate startup/warmup, CPU core equivalents via Linux process CPU counters, and sampled concurrent sum of RSS, not PSS or exact peak. Explicitly verify YJIT enabled state. Each engine on a separate CI VM; compare pairs within engine, alternate YJIT order, fixed worker order. Baseline real clock, observer waits, checkpoint settling, no bundle cache/profile. No general test scheduling API, shared database scalability or production memory claim.

## ADR-013: combined performance profiles

Compare 12 Domstride profiles and three external driver references on the same Linux runner, sequentially, with the same stateful fixture and persistence checks (including exact record values). Disable instrumentation, YJIT and parallelism in measured configurations. Use one warmup then five samples of ten; startup excluded from warm timing. Candidates are engine/DSL-specific; do not enable virtual clock for Capybara until its retry integration is designed. Happy DOM Capybara candidate is a control, not an additional optimization. Browser references share pinned Playwright Chromium executable. Upstream pinned rails-jsdom uses separate importmap boot. Timing comparisons are end-to-end fixture results, not isolated transport/engine performance, and order is not fully randomized. Report incomplete or failed configurations explicitly; no default profile changes without further compatibility evidence.

## ADR-014: explicit performance profiles and distribution preview

Keep legacy defaults, with precedence explicit keyword > environment > named profile > defaults. Use performance_profile instead of overloading profiling boolean. Reject deterministic Capybara profile with virtual clock because retry integration is incomplete. Rails system tests use normal driven_by registration and opt-in screenshot suppression; no Rails monkeypatch. Gem includes runtime scripts and CLI; setup copies them to a content-addressed cache, locks installation, stages npm install and marks successful installs before reuse. Explicit setup only, no network at test runtime; direct npm pins without transitive lock are a preview limitation. CI verifies the installed gem outside checkout and native/system test profiles. No publishing or full Capybara conformance claim.

## ADR-015: packaging isolation and capability contract

Install the preview gem into an empty GEM_HOME with normal RubyGems dependency resolution, verify loaded gem location, check missing runtime diagnostics, then setup/doctor and a Rack-backed Capybara smoke test outside checkout. Do not ignore dependencies or depend on Bundler's private gem cache. Expand Capybara regression coverage with checkbox/radio native activation, field state, visibility, asynchronous queries and explicit unsupported operations. Scope raw node identities to the driver worker generation, including scoped queries and equality, to avoid handle reuse after reset. Six engine/prefetch CI combinations; known Happy DOM XPath pending. No claim of full upstream conformance or real app support.

## ADR-016: real application discovery before optimization claims

Pin upstream source revisions, use each app's required Ruby version and original test helper, run a browser baseline before switching only the driver. Use disposable test databases, one worker, fixed seed and timeouts. Record failures and prerequisite blockers separately; discovery jobs are not conformance gates. Do not vendor upstream source or modify upstream repositories. One original test file per app is an initial probe; do not extrapolate performance or support.

## ADR-017: bounded same-origin HTTP redirects

Follow redirects inside the Rack session, not via external network. Preserve final URL, cookie jar and redirect flag. Rewrite POST to GET for 301/302/303, preserve for 307/308, drop body headers on rewrite. Validate each target, reject credentials and cross-origin URLs, limit to ten hops and reject repeated method/URL pairs. Count each actual Rack request in profiling. Fetch error mode rejects; manual opaque response unsupported. Does not implement DOM navigation/history, other request methods, or importmap assets.

## ADR-018: grouped HTTP and asset compatibility foundation

Add HEAD, PUT, PATCH, DELETE and JSON mutation bodies without opening external network. Correct redirect regression fixture for Rack versions where bodyless requests omit rack.input. Opt-in Node/jsdom asset loader parses HTML inertly, resolves only same-origin Rack resources, inlines synchronous classic scripts and uses esbuild with an explicit importmap resolver to bundle static modules into an IIFE evaluated after mount. Bound asset count and total bytes. Reject unsupported cases rather than claim browser-equivalent script loading. No native ESM scheduling, dynamic import graph guarantee, CSP/integrity emulation or WebSocket support. Cache disabled for this mode. Packaged runtime includes esbuild and asset loader. Keep baseline profiles unchanged.

## ADR-019: grouped JavaScript compatibility

Use Acorn AST positions to transform computed import expressions into a bounded dispatch function over exact controller importmap pins; preserve literal dynamic imports for esbuild. Controller modules are fetched during bundle construction and initialized lazily by esbuild, not fetched on demand as in browsers. Reject unmapped computed specifiers, preserve importmap script for Stimulus loading and keep asset boot opt-in. Support synchronous script execution with JSON arguments/results and top-level Capybara element arguments validated against driver generation. Reject unsupported result types/thenables, no browser CDP or evaluate_async_script. Add real Stimulus package integration and native/Capybara script regression tests. Discovery logs failed phase tail and retries database reset with Rails db:reset; enable experimental assets only for candidate. Original tests remain unchanged.

## ADR-020: grouped form and keyboard compatibility

Implement option selection, multi-select values and change events; support explicit basic text editing and named keyboard events while rejecting chords and unsupported input types. File attachment on jsdom reads only explicitly supplied fixture paths with an 8 MiB aggregate per-operation cap and sends base64 bytes to worker-created DOM File objects; FileList-like array and FormData wrapper are approximations. Use Node FormData and FileReader to serialize bridged fetch multipart; carry multipart as bounded base64 and decode before Rack dispatch, preserving binary contents and redirect semantics. Do not claim native browser file picker, form navigation, reset or keyboard defaults. Add regression coverage for select, keyboard cancellation and binary multipart through Rack parser. No new dependencies beyond existing Capybara MiniMime and Node APIs.

### ADR-020 follow-up

Declare base64 and mini_mime as direct Ruby dependencies: base64 is not bundled as a default gem on Ruby 3.4+. Derive Capybara multiple-select values from live option.selected flags instead of Happy DOM's potentially stale selectedOptions collection. Verify both flags after unselecting. This does not patch the engine's native selectedOptions implementation.

## ADR-021: explicit loopback Action Cable transport

Keep normal HTTP in Rack. Opt-in real WebSocket transport via jsdom's native WebSocket to one explicitly configured loopback endpoint, mapping the matching logical cable path. Block other Rack-page sockets, cap active sockets, close on remount and session termination, expose socket state. Node/jsdom real clock only; no virtual-time or shared cookie authentication. Exercise real Rails Action Cable server hosted by Puma with async pubsub, Rails-shipped browser client, two independent consumers and Turbo connectStreamSource. Verify server subscription readiness before publishing, client-to-server perform, both DOM updates, disconnect, remount and cleanup. This is a hybrid transport and not a fully in-process or authenticated Action Cable implementation. No benchmark comparison yet.
