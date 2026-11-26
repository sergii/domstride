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
