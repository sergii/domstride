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

## ADR-022: opt-in Rails developer experience

Generate a separate test base without replacing the application test helper or existing system test class. Select Domstride or a registered browser driver explicitly before test execution; never replay automatically after a failure. Support one stable window handle for compatibility, not multiple windows. Expose JSON doctor and optional private failure diagnostics; include HTML only on explicit opt-in, avoid page URLs and script content in metadata, preserve original failures when diagnostic capture fails. Test generator output, existing-file preservation, driver selection and diagnostics; run the same generated Rails system scenario with Domstride and real Cuprite Chromium. Keep the installed gem smoke test and add JSON doctor validation.

## ADR-023: release candidate evidence and discovery isolation

Keep the original real-browser baseline and retry only the specific observed Chrome wildcard-origin reset failure with a discovery-only fresh-browser-session shim. Preserve all original logs; do not change test assertions, suppress failure or treat retry wall time as a comparable benchmark. Candidate uses logical Rack host. Document supported subset, exact benchmark provenance and explicit release gates. No publishing or merging in this batch.

## ADR-024: framework-independent BDD scenario lifecycle

Use a separate Capybara session per tagged scenario and explicit framework hooks. No global Capybara driver mutation, framework runtime dependency, automatic database cleaning or retry. Share the same Gherkin reference feature and Ruby actions, with runner-specific bindings and isolated dependency manifests. Add opt-in, metadata-only semantic step lifecycle events through explicit wrappers as a future recording seam; no automatic step source mapping or DOM snapshots. Validate exact scenario counts with Cucumber and Turnip JSON output across all three Node engines. No performance claim for BDD until measured.

## ADR-025: explicit functional-vs-browser-security separation for Fizzy

Do not fake driver.browser or CDP. Keep Chromium Trusted Types inventory on browser baselines; remove only its report-only include in temporary candidate helper with explicit not_measured metadata. Four isolated original-test groups, exact case/assertion parity, source digest and helper restoration, retained logs, strict per-group gate. Product runtime unchanged; use observed next failures to prioritize genuine fixes.

## ADR-026: bounded opt-in interaction recording

Capture target structural paths before/after selected protocol commands and optional raw HTML snapshots in the same worker reply. No live DOM mutation or replayed application requests. Persist private per-worker JSONL metadata and bounded HTML files; do not retain selectors, arguments, URLs, exceptions or results. Explicit BDD wrapper correlation via step_sequence. No automatic Capybara assertion or Gherkin event capture. Snapshot HTML is sensitive and must be rendered inert by a future viewer. Disabled by default; no claims of screenshot fidelity.

## ADR-027: explicit direct-eval asset warning exception

Strict by default; only opt-in direct-eval warning ID may proceed with visible source-location diagnostics. No global warning suppression, source rewrites, fake browser APIs or relaxed test assertions. The Fizzy discovery candidate opts in and retains all original gates. Synthetic tests verify lexical eval behavior and error propagation, not general module equivalence.

## ADR-028: bounded static media environment

Observed Fizzy Turbo matchMedia blocker after asset boot. Provide an explicit Node/jsdom static media profile, with fixed logical dimensions and preferences, real EventTarget registration, and rejection of unsupported expressions. Do not fake scrolling or geometry or claim responsive/browser parity. Native implementation is not overridden. Keep opt-in default off and test independently of the app.

## ADR-029: explicit logical DOM API subset

Add opt-in logical visibility, dialog open/returnValue/close lifecycle, and window scroll offset state with event delivery. Preserve native visibility/dialog implementations if complete; do not override a partially implemented dialog API. No fake geometry or modal inertness, no smooth scroll or automatic intersections. Default off, Node/jsdom only. Authenticated Action Cable remains separate. Verify state transitions and unsupported behavior with regression tests; retain original Fizzy assertions.

## ADR-030: explicit authenticated loopback Action Cable transport

jsdom 26 and 31 have different native WebSocket cookie behavior. Keep existing native bridge for anonymous use. Opt into a separate text-only ws transport with explicit named Rack cookie forwarding to the single loopback endpoint. Use latest Rack HTTP cookie snapshot, validate logical path and secure/expiry eligibility, never expose cookie headers in fetch Response, document.cookie, diagnostics or recording metadata. No redirects, external endpoints or binary messages. Verify Rails signed HttpOnly cookie authentication and two isolated private channels. Existing socket credentials are fixed at handshake; reconnect after login/logout. No account-path or full browser socket parity.

## ADR-031: bounded numeric tenant cable routing

Opt-in numeric-account mode requires authenticated exact /cable loopback configuration; map only logical same-origin numeric /<id>/cable paths, no query/fragment/external URLs, root-path eligible cookies only. Run actual Fizzy Rails stack in the candidate process on ephemeral loopback Puma with async cable adapter and explicit test origin. Preserve real account extraction and authentication. No application code or original assertions changed. Reference verifies route acceptance and rejection independently of app.

## ADR-032: focused page keyboard and scroll intent

Share key encoding across Capybara node and driver. In logical profile field set focuses the input; page-level Enter dispatches cancelable keyboard event and ordinary implicit form submission through real DOM click/requestSubmit. No physical keyboard, chords or focus traversal parity. Store scrollIntoView target path and requested alignment without fabricating coordinates; reject smooth scrolling. Preliminary asset discovery uses selected jsdom and isolated console, not live CSS suppression. ResizeObserver and layout-dependent activity pagination remain unresolved.

## ADR-033: explicit observer contracts

Keep legacy behavior off by default. Node/jsdom manual profile exposes synthetic notify_intersection and notify_resize commands, deduplicates states, respects unobserve/disconnect, bounded delivery and targets. Logical-visible profile emits initial binary intersection based on DOM visibility, not viewport geometry, ignores geometric root margins/threshold distinctions, rejects rectangle access and does not simulate resize. Use only as functional fixture policy, never claim layout parity. Fizzy candidate opts into initial logical observation to investigate missing activity pagination.

## ADR-034: explicit case-level suite reporting

Fiber-local case scope groups newly created workers in private case directories. Final case status is independent of operation outcomes; no exception messages or test data automatically stored. Reuse inert replay renderer for bounded suite export, filter tests by name/status and select each worker recording. Explicit names and HTML opt-in; no auto framework status inference. Preserve reversible layout and single recording export.

## ADR-035: framework-owned final test status

Use RSpec example_started/example_finished reporter notifications and Minitest Test#run result wrapper. No guessed pass from individual DOM operations or exception strings. Capture skipped/pending/fixed-pending and setup/teardown outcomes; record Minitest assertion totals only, RSpec counts unknown. Scope is fiber-local and does not reassign existing workers. Preserve original result and exit code; explicit opt-in, optional dependencies, private case artifacts. No automatic step-level assertion mapping or outside-example suite failures yet.

## ADR-036: Gherkin step ownership

Cucumber test-case/test-step events and Turnip custom RSpec step events own step sequence and result. Active report case provides authoritative sequence at recording time; explicit manual BDD step sequences remain fallback. Keep step text opt-in, bound steps and metadata, skip hook events, retain missing DOM evidence rather than inventing it. Suite viewer selects first mapped operation across recordings and highlights the current Gherkin step. No inferred assertion outcome or physical browser geometry.

## ADR-037: bounded assertion evidence

Capture outer assertion calls via explicit framework adapter installation and native assert_text. Track assertion outcome independently of operation outcome; handle aggregated RSpec failures through expectation failure helper. Correlate operations only within active assertion scope; bounded additional read evidence and no assumed association to earlier DOM calls. No expected/actual serialization; preserve errors and exit status. RSpec private handlers version-sensitive; test against pinned reference family. No physical snapshot claims.

## ADR-038: bounded local browser video evidence

First slice uses Playwright real Chromium WebM recording and explicit case attachment. Separate media evidence from DOM interaction/assertion outcomes. No synthetic video or inferred playback timestamps. Embed bounded local WebM with blob-only media CSP, revoke URLs when switching; private copies, no remote resources, no automatic upload. Browser context finalization before import. Keep Selenium/Cuprite lifecycle integration separate.

## ADR-039: one product, independent artifact contract

Keep one Domstride repository and brand. Runner and Studio communicate through versioned case bundles, not runtime calls. Separate lightweight errors/protocol definitions and lazy CLI loading; report exporter requires no execution engine. Retain legacy manifests and trace format. External producers carry arbitrary bounded provenance; first Node writer and actual Playwright video contract. No standalone gem split yet, no claim of adapters for other languages or platforms.

## ADR-040: external Playwright Test reporter

Use native onTestEnd results and step trees; each retry is a separate attempt, no guessed logical outcome. External producer is Node-only, renderer independent of Runner. Opt-in video and step text, bounded metadata, no failure-message serialization. Preserve Playwright exit status. Standalone synthetic reference workflow verifies interoperability. Return to Selenium/Cuprite automatic recording, video synchronization, performance and deferred Webpack after this adapter.

## ADR-041: isolated display recording backend

Optional FFmpeg x11grab per framework case on dedicated Linux Xvfb display; same backend for headed Selenium/Cuprite, no driver mutation. Bounded output, nonblocking suite-local display lock, graceful signal/forced reap, private temporary files, attach before final manifest. Failures cannot change framework status. Entire display is sensitive; independent worker displays required. No claim of headless recording or exact synchronization.

## ADR-042: explicit video-local cues

Optional per-video step/assertion sequence and playback time_ms. No guessing from step duration or case start. X11 actual first-frame input PTS with normalized output timestamps, monotonic-to-wall clock sample and drift guard; omit cues outside recorded range. Step start and assertion completion semantics. Viewer selects video and seeks only on supplied cue; missing cues remain unavailable. No claim of Playwright video alignment without a clock anchor. Explicit fixture offsets test viewer seeking independently.
