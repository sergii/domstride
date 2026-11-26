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

The initial milestone exercises real JavaScript DOM events via a persistent JSON-lines worker. No Rails, Turbo, Stimulus, navigation or browser parity is claimed yet. Benchmarks compare identical synthetic counter interactions, not Rails system tests. See docs/architecture.md.

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

Ruby 4.0.10 / Rails 8.1.4.1, real Stimulus and Turbo, experimental read-only Rack bridge.

    npm run build:reference
    bundle exec ruby examples/rails_reference/test.rb
    bundle exec ruby examples/rails_reference/benchmark.rb

Reference scenario: Stimulus expense total, Turbo Frame GET, Turbo Stream GET. The DOM worker uses same-origin Rack requests; Chromium uses a local Puma HTTP server. No database, mutation endpoint, CSRF, cookies, redirects, or general browser parity is claimed. Only trusted fixture code.

## Stateful Rails reference

The reference now uses ActiveRecord and a temporary SQLite database, a fixture login, cookie-backed sessions, Rails CSRF checks, URL-encoded POST forms, validation errors, and Turbo Stream responses. The scenario revisits the page and reads the persisted expense. RSpec example: `bundle exec rspec examples/rails_reference/reference_spec.rb`.

The Rack bridge supports only same-origin GET and URL-encoded POST; cookies are held in a session-local Rack::Test jar. No production authentication, multipart, redirects, JavaScript cookie access, or full browser semantics are promised.

## Experimental Capybara driver

    require "domstride/capybara"
    page = Capybara::Session.new(:domstride, Rails.application)

CSS lookup, scoped elements, basic text fields, click, async query retry and session reset are supported experimentally. XPath depends on the engine. Layout, screenshots, actionability, modifiers, select inputs and navigation history are not implemented. See `examples/rails_reference/capybara_spec.rb` and `capybara_benchmark.rb`. Use trusted fixtures only.

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
