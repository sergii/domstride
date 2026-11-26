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
