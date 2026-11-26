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
