# Batch 014 - Locator Compatibility & Semantic Target Identity

Tracking: [#21](https://github.com/sergii/specdrive/issues/21). Phase 1 initial differential suite; results pending. No changes to production execution, protocol or Viewer.

## Phase 1: shared contract

Run the same synthetic pet adoption fixture with Capybara 3.40 on jsdom, jsdom31, Happy DOM, Selenium and Cuprite. Ruby 3.4.13 in CI. Each example uses a fresh session, per-session configuration and verifies the actual selected field or changed DOM state. No global configuration in the gem. The test process opts into Capybara thread-safe session settings; production defaults are untouched. The browser drivers are only test dependencies in the example Gemfile.

`aria-labelledby` and competing native/ARIA labels are exploratory probes, logged as LOCATOR_PROBE. A passing probe is not proof of full accessible-name computation. Native button and explicit CSS role queries are distinct from a role-based accessible-name API. Happy DOM XPath compatibility is previously unestablished; the initial matrix intentionally records real failures rather than skipping them. A failed experimental job is visible and will need a reviewed capability decision, not a hidden green result.

From the checkout root:

```sh
export BUNDLE_GEMFILE=examples/locator_compatibility/Gemfile
bundle install
npm install --no-audit --no-fund
LOCATOR_ENGINE=jsdom bundle exec rspec -Ilib examples/locator_compatibility/locator_spec.rb
```

Select jsdom31, happy-dom, selenium or cuprite with LOCATOR_ENGINE. Browser variants require Chrome (optionally CHROME_PATH). CI uploads the RSpec JSON and contract log per engine. The dedicated workflow runs on this draft feature branch, manual dispatch and full/release PRs.

## Follow-ups

Record actual per-engine capability results and versions; investigate failing supported contracts. Add explicit duplicate HTML IDs, stale raw handle semantics and real Turbo replacement cases after initial results. Do not claim full accessibility tree, accessible name or role parity. Phase 2 (optional observed target identity and Viewer display) requires separate protocol and privacy review. No new capture in fast mode; controlled performance audit before merging implementation changes. 
