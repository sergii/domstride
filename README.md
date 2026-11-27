# Domstride

Fast interactions. Real behavior.

Experimental browserless-first interaction testing for Ruby applications. Inspired by [rails-jsdom](https://github.com/jakehow/rails-jsdom). This initial prototype is independently implemented; no upstream source is copied.

## Quick start

Requires Ruby 3.3+, Node 22+ (or experimental Bun) and npm.

    bundle install
    npm install
    bundle exec rake test
    bundle exec ruby examples/counter.rb
    bundle exec ruby benchmarks/counter.rb

Set DOMSTRIDE_RUNTIME=bun to try the alternative runtime.

Domstride exercises real JavaScript DOM events via a persistent JSON-lines worker and has an experimental stateful Rails reference. It does not provide full browser parity. See docs/architecture.md.

## Experimental performance matrix

    DOMSTRIDE_ENGINE=happy-dom bundle exec rake test
    bundle exec ruby benchmarks/matrix.rb

Batching preserves synchronous command order and asserts each intermediate value:

    page.batch do |b|
      b.click("#increment")
      b.assert_text("#count", "1")
    end

Happy DOM and Bun are experimental. Only trusted fixture code is allowed. This is not an asynchronous browser emulator.

## Rails reference app

Ruby 4.0.10 / Rails 8.1.4.1, real Stimulus and Turbo, same-origin Rack bridge.

    npm run build:reference
    bundle exec ruby examples/rails_reference/test.rb
    bundle exec ruby examples/rails_reference/benchmark.rb

Reference scenario: Stimulus expense total, Turbo Frame GET, Turbo Stream GET. The DOM worker uses same-origin Rack requests; Chromium uses a local Puma HTTP server. See the stateful reference below for database, mutation and cookie coverage. General browser parity remains unsupported. Only trusted fixture code.

## Stateful Rails reference

The reference now uses ActiveRecord and a temporary SQLite database, a fixture login, cookie-backed sessions, Rails CSRF checks, URL-encoded POST forms, validation errors, and Turbo Stream responses. The scenario revisits the page and reads the persisted expense. RSpec example: `bundle exec rspec examples/rails_reference/reference_spec.rb`.

The Rack bridge uses a session-local Rack::Test cookie jar. See HTTP and form sections for supported methods, redirects and multipart limitations. No production authentication, JavaScript cookie access or full browser semantics are promised.

## Experimental Capybara driver

    require "domstride/capybara"
    page = Capybara::Session.new(:domstride, Rails.application)

CSS lookup, scoped elements, basic text fields, click, async query retry and session reset are supported experimentally. XPath depends on the engine. Layout, screenshots, actionability, modifier chords and navigation history are not implemented. See the form section for select support. See `examples/rails_reference/capybara_spec.rb` and `capybara_benchmark.rb`. Use trusted fixtures only.

## Upstream comparison

The upstream workflow pins rails-jsdom 0.2.1 at commit 66dc701a48df7038db8e56e8d44e8c36874dae78, uses the same stateful Rails fixture and shared Stimulus controller, with upstream's normal importmap boot and jsdom 31.0.0. Domstride uses its own bundle and jsdom 26.1.0 or Happy DOM. The upstream importmap aliases its Turbo Rails entry to the same npm Turbo core build used by the fixture; Action Cable is not exercised. This compares current configurations, not isolated engine or transport performance. No upstream code is copied.

## JavaScript failures

Domstride raises `Domstride::JavaScriptError` for captured JavaScript exceptions and unhandled rejections at command checkpoints. Use `page.check_javascript!` for an explicit checkpoint. This does not drain all timers or guarantee deterministic settling. Plain console.error strings remain diagnostic; Error objects logged by frameworks are treated as failures.

## Profiling and event-driven text waits

Set `DOMSTRIDE_PROFILE=1` to collect command counts, Ruby and worker wall times, Rack request counts/time and protocol byte counts. No request payloads or page contents are retained in the profile. `page.profile` returns a snapshot; `page.reset_profile!` clears counters. Worker time includes Rack waits and overlaps Ruby wall time; it is not exclusive CPU time.

`DOMSTRIDE_WAIT=observer` enables a bounded MutationObserver-based native text wait. Polling remains the default until more compatibility data is available. It observes DOM mutations and captured errors, not arbitrary pending work; Capybara query retries are unchanged. `DOMSTRIDE_ENGINE=jsdom31` selects the experimental npm alias for jsdom 31.0.0.

## Experimental bundle caching

`DOMSTRIDE_BUNDLE_CACHE=source` deduplicates explicitly marked final classic inline scripts (`<script data-domstride-cache="bundle">...</script>` immediately before the closing body/html). The worker reconstructs the original script before parsing. SHA-256 content identity and a single-entry worker cache prevent stale reuse; no general HTML or session caching. `compiled` (jsdom only) additionally reuses a vm.Script in each fresh document context after parsing. Compiled mode changes parser-time semantics, document.currentScript and script text, and is only appropriate for explicitly opted-in fixture bundles that do not depend on them. Default is off. No arbitrary asset rewriting, disk cache or browser security sandbox.

## Experimental Capybara query prefetch

`DOMSTRIDE_QUERY_PREFETCH=1` uses Capybara 3.40's initial_cache metadata to return tag name and (when requested) initial visibility with the selector result. Ruby retains filtering, regular expressions, custom blocks, counts and retry behavior. Public element visibility/text calls remain live; no persistent property cache. Default off. This is metadata coalescing, not general remote filtering or browser actionability.

## Experimental settling and virtual clock

`DOMSTRIDE_SETTLING=tracked` waits after mutating commands for tracked Rack fetches, due virtual timers, and three quiet event-loop checkpoints. `page.settle!` explicitly requests the bounded drain. `DOMSTRIDE_CLOCK=virtual` supplies document-local Date and function timers, including intervals and animation frames. `page.advance_time(500)` advances milliseconds; native text waits can advance to scheduled callbacks within their virtual timeout. Remount resets clock and timers. Defaults remain checkpoint/real. No Ruby/Rails clock synchronization, performance.now virtualization, arbitrary Promise tracking, XHR, network-idle guarantee, browser scheduling equivalence or automatic advancement of future timers during ordinary clicks. Real deadline 3s and 1000 timer callbacks per drain/advance. Trusted fixtures only.

## Parallel workers and YJIT benchmark

Run on Linux: `WORKERS=4 YJIT_MODE=on DOMSTRIDE_ENGINE=happy-dom bundle exec ruby examples/rails_reference/parallel_benchmark.rb`. Each Ruby process boots its own Rails reference app, temporary SQLite database, cookie jar and persistent Node worker. Fixed 32 measured scenarios per sample split across workers, five repeats, three warmup scenarios per worker. Reports wall time, throughput, process CPU seconds and peak sampled concurrent sum of Ruby/Node RSS (shared pages may be counted twice). Startup and warmup measured separately. This is an experiment harness, not an automatic parallel test runner or shared connection pool.

## Combined performance comparison

The combined workflow compares baseline and candidate native/Capybara configurations for each DOM engine against pinned rails-jsdom, Cuprite and Playwright on one runner. All use the same stateful scenario, one warmup and five samples of ten scenarios; exact persisted records are checked. Candidate jsdom native combines compiled bundle, observer waits, tracked settling and virtual clock; candidate jsdom Capybara uses compiled bundle and query prefetch with real clock. Happy DOM stays uncached with real clock and checkpoint settling; candidate native uses observer waits, while candidate Capybara is a control because native waits are not used by Capybara. Single worker and YJIT off to avoid conflating parallel scaling. Browser references share the Playwright-installed Chromium executable. Different DSLs, JS boot and browser execution semantics remain material. No universal performance or compatibility claim.

## Named performance profiles

`Domstride::Session.new(performance_profile: :fast)` or `DOMSTRIDE_PERFORMANCE_PROFILE=fast` selects a profile. `compatible` uses jsdom31 with real clock, `fast` uses Happy DOM with real clock, and `deterministic` uses jsdom31 compiled cache, observer waits, tracked settling and virtual clock. Explicit keyword arguments override environment settings, which override the profile. No profile preserves existing defaults (jsdom26). `profile: true` still enables instrumentation, not profile selection. The deterministic profile is native DSL only until Capybara virtual retries are supported. All profiles remain experimental; Happy DOM XPath is incomplete.

## Rails system tests

    require "domstride/rails"
    class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
      include Domstride::RailsSystemTestSupport
      driven_by :domstride
    end

The support module suppresses automatic failure screenshots for Domstride because it has no rendered browser. HTML can be saved with Capybara's save_page if explicitly requested; avoid exposing sensitive test data. Standard XPath-based selectors are supported on jsdom, not established on Happy DOM. Do not use this driver for layout or screenshot tests. No automatic browser fallback.

## Installed gem preview

Build/install the gem locally, then run `domstride setup` and `domstride doctor`. Setup explicitly installs pinned direct runtime dependencies using npm into a content-addressed user cache (default ~/.cache/domstride; override DOMSTRIDE_RUNTIME_HOME). Test execution never installs packages implicitly. Development checkout uses root node_modules when available. Node 22.23.5 is the verified runtime; npm is required for setup. Direct dependency versions are pinned; transitive npm resolution is not locked yet. No RubyGems release is published.

## Capybara contract

See [compatibility matrix](docs/compatibility.md). Checkbox/radio state changes use native DOM activation and generation-scoped handles prevent old driver nodes from aliasing new elements after reset. The CI matrix covers all three engines with prefetch off/on. Full upstream Capybara conformance and real-world Rails asset loading are not yet established.

## Real application discovery

See [QA-003](docs/real-apps.md) for pinned Campfire, Fizzy and Writebook discovery. The workflow runs an original system test file with its upstream browser driver first, then attempts it using Domstride. Blockers are recorded, not silently removed. A successful discovery job does not imply application support.

## Same-origin redirects (experimental)

Native visit and bridged fetch follow HTTP 301/302/303/307/308 within http://example.test, preserving Rack cookies and final response URL. POST becomes GET for 301/302/303; 307/308 preserve the method and body. Maximum ten redirects and loop detection; cross-origin redirects rejected. Fetch redirect:error rejects; manual redirect responses are explicitly unsupported. This is not general browser navigation, form navigation, or history support. See the HTTP methods and form compatibility sections below for additional methods.

## Experimental Rails asset boot and HTTP methods

GET, HEAD, POST, PUT, PATCH and DELETE are supported through same-origin Rack; nonempty mutation bodies must be URL-encoded or JSON. See the form compatibility section below for limited multipart support. Set `DOMSTRIDE_ASSETS=bundle` for a limited Node/jsdom asset pipeline with cache off. Classic synchronous same-origin scripts are inlined before parsing; static ES modules are bundled through esbuild using exact/prefix importmap entries and relative URLs, then evaluated after parsing. No external network, scoped importmaps, async/defer classic scripts, module redirects, integrity checks, full module timing, arbitrary dynamic imports or integrated authenticated Action Cable support. Opt-in only; do not interpret successful bundling as browser parity. All application code must be trusted.

## Script API and controller imports

Native Session and Capybara support synchronous execute_script and evaluate_script with JSON values; Capybara also accepts top-level element arguments from the same live driver. Evaluation returns JSON-shaped data only, not DOM handles or promises. In opt-in asset mode, computed import expressions resolve exact importmap controller pins ending in _controller through a bounded bundled registry. Literal dynamic imports are bundled by esbuild. This supports the Stimulus Rails controller-loading pattern, not general runtime module resolution; all registered controller code must be trusted. No native module graph, import.meta semantics, async-script callback API, arbitrary computed URLs or browser CDP.

## Experimental form compatibility

Capybara select_option/unselect_option support single/multiple select controls, with input/change events when selection changes. Text inputs and textarea support bounded basic send_keys operations (text, editing, cursor movement and named key events); not browser keyboard defaults, modifier chords, focus traversal or IME. jsdom file inputs accept explicit local fixture paths up to 8 MiB per operation; files are exposed as a FileList-like array, not a native picker. FormData(form) includes attached files and bridged fetch serializes multipart bodies through Node FormData with binary-safe base64 IPC. No external uploads, browser form navigation, drag/drop, native form reset synchronization or full file API parity. Happy DOM file attachment is unsupported. Only trusted test fixtures and explicit paths.

## Experimental Action Cable transport

Pass `websocket_url: "ws://127.0.0.1:PORT/cable"` (or DOMSTRIDE_WEBSOCKET_URL) with a test-only Action Cable endpoint. HTTP stays in-process; jsdom uses a real loopback WebSocket for the exact configured endpoint or corresponding logical same-origin path. Node/jsdom and real clock only. Session remount/close closes tracked sockets; websocket_state reports open/count. No external endpoints, shared Rack cookie authentication, arbitrary WebSocket URLs, virtual-time socket scheduling or production network access. The reference uses real Rails Action Cable server, async adapter, shipped client and Turbo connectStreamSource, not the complete turbo-rails custom element or authenticated production configuration. Reference integration passed on both jsdom engines at commit 29781da; limitations still apply.

## Rails installation and explicit browser fallback

```sh
bundle exec domstride setup
bin/rails generate domstride:install
```

The generator creates test/domstride_system_test_case.rb without replacing ApplicationSystemTestCase. Extend DomstrideSystemTestCase for selected tests. Run those tests normally, or set DOMSTRIDE_DRIVER=browser to run the same test with an already registered Capybara browser driver (default selenium_chrome_headless; override DOMSTRIDE_BROWSER_DRIVER). Install/configure your browser driver separately. Selection happens before the test, never by automatically replaying a failed mutation. Rails system tests using the existing base class are unchanged.

`bundle exec domstride doctor --json` reports runtime/version/engine and a minimal DOM check (not full application compatibility). Set DOMSTRIDE_FAILURE_DIR to explicitly save per-failure metadata in a private directory; DOMSTRIDE_FAILURE_HTML=1 additionally saves DOM HTML, which can contain sensitive test data. No automatic capture by default. Single-window identity is available; new tabs/windows remain unsupported.

## Release readiness

See [release candidate checklist](docs/release-readiness.md), [compatibility contract](docs/compatibility.md) and [real application evidence](docs/real-apps.md). This is an experimental developer preview, not a universal browser replacement. No public release is claimed by the CI-built gem artifact.

## Cucumber and Turnip

Use `require "domstride/bdd"` and explicit scenario-scoped Capybara sessions in Cucumber or Turnip/RSpec hooks. Both reference runners execute the same Gherkin feature against the stateful Rails fixture. No Cucumber or Turnip runtime dependency. Optional semantic step metadata provides a foundation for later recording; automatic step capture and replay are not implemented. See [BDD integration](docs/bdd.md) and dedicated CI.

## Interaction recording

Set `DOMSTRIDE_RECORD_DIR=tmp/domstride-recordings` for bounded metadata-only traces. Add `DOMSTRIDE_RECORD_HTML=1` for sensitive raw HTML snapshots with structural target paths. Disabled by default. See [recording contract](docs/recording.md); this is the artifact layer for a future viewer, not executable replay or rendered video.

Export one recording with `bundle exec domstride replay RECORDING_DIRECTORY`. The local preview supports before/after state, highlighted targets and switchable sidebar position. See [roadmap](docs/roadmap.md).
For controlled compatibility experiments only, `DOMSTRIDE_ASSET_WARNINGS=direct-eval` permits esbuild's exact direct-eval warning and reports its location. Strict is default. Other warnings, build errors and JavaScript exceptions remain fatal. Direct eval may change semantics when bundling; validate original tests.

`DOMSTRIDE_MEDIA_PROFILE=static-desktop` is an opt-in Node/jsdom static media-query environment (1200x1000 logical dimensions, light, reduced motion). Supports only documented simple queries and throws for others. It does not emulate geometry, responsive rendering or resizing; default off.

`DOMSTRIDE_DOM_PROFILE=logical` opts into Node/jsdom logical visibility, dialog lifecycle and window scroll offsets. Not a layout engine: no geometry, modal inertness, smooth scrolling, real intersection or element scroll. Unsupported operations remain failures. See [Fizzy compatibility](docs/fizzy-compatibility.md).

For explicit test-only authenticated Action Cable, set `DOMSTRIDE_WEBSOCKET_COOKIE_NAMES=cable_session` (comma-separated exact names) together with the loopback endpoint. This selects a bounded text-only ws transport that forwards eligible Rack cookies in the handshake, including HttpOnly cookies without exposing them to page JavaScript. No external endpoints, redirects, binary frames, automatic cookie rotation on established sockets, or complete browser WebSocket parity. Only trusted test code and trusted loopback server; use the actual app's authentication middleware.

For account-prefixed Action Cable paths, the experimental `DOMSTRIDE_WEBSOCKET_PATH_MODE=numeric-account` requires an authenticated `/cable` endpoint. Accepts only logical same-origin numeric account prefixes, forwards root-path allowlisted cookies, and preserves the path for real Rails tenant middleware. Default `exact`.

Page-level Capybara `send_keys` dispatches to the active element and supports ordinary Enter form submission; logical profile focuses filled fields and records `scrollIntoView` intent, not geometry. No arbitrary key chords, layout, resize or intersection parity.

`DOMSTRIDE_OBSERVER_PROFILE=manual` enables explicit `notify_intersection` / `notify_resize` inputs to native Session. `logical-visible` delivers initial synthetic binary intersections from DOM visibility, without physical viewport geometry or automatic resize. Both are bounded test policies, default off; browser required for layout-sensitive tests.

See [suite reports](docs/reporting.md) for explicit case capture and `bundle exec domstride report CASE_DIRECTORY`. Case results are separate from interaction results; automatic framework integration is follow-up.

Optional automatic reporting adapters: `require "domstride/reporting/rspec"` or `require "domstride/reporting/minitest"`, then `Domstride::Reporting::RSpec.install!(directory: "tmp/domstride-suite")` or corresponding `Minitest.install!`. Actual final framework status; Minitest assertion count. HTML opt-in.

Experimental browser video evidence: attach finalized local WebM to an active report case with `Domstride::Video.attach(path, label: "Chromium")` after requiring `domstride/report`. See examples/browser_video and reporting docs. No automatic browser-driver capture or video/step synchronization yet.

Domstride Studio is the runner-independent reporting direction within the same product. See [Protocol v1](docs/protocol.md) for external producers and standalone source-checkout report export without loading the execution runtime.

Native [Playwright Test reporter](docs/playwright-reporter.md): source-checkout adapter for existing tests, optional WebM and Gherkin-like test.step/expect evidence, independent of Domstride Runner.

Optional headed browser capture for Selenium/Cuprite: [Linux Xvfb video backend](docs/browser-video.md). Explicit opt-in; use an isolated display and one worker per display.
