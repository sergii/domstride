# Batch 014 - Locator Compatibility & Semantic Target Identity

Tracking: [#21](https://github.com/sergii/specdrive/issues/21). Phase 1 initial and CSS-only differential evidence recorded; capability decision pending. No changes to production execution, protocol or Viewer.

## Phase 1: shared contract

Run the same synthetic pet adoption fixture with Capybara 3.40 on jsdom, jsdom31, Happy DOM, Selenium and Cuprite. Ruby 3.4.13 in CI. Each example uses a fresh session, per-session configuration and verifies the actual selected field or changed DOM state. No global configuration in the gem. The test process opts into Capybara thread-safe session settings; production defaults are untouched. The browser drivers are only test dependencies in the example Gemfile.

`aria-labelledby` and competing native/ARIA labels are exploratory probes, logged as LOCATOR_PROBE. A passing probe is not proof of full accessible-name computation. Native button and explicit CSS role queries are distinct from a role-based accessible-name API. Happy DOM lacks XPath in the tested adapter configuration; the initial matrix records real failures rather than skipping them. A failed experimental job is visible and will need a reviewed capability decision, not a hidden green result.

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

## Initial CI evidence

Source: [run 46096611126](https://github.com/sergii/specdrive/actions/runs/46096611126), commit a4738f7. Core CI and independent Studio protocol passed; full/release workflows were skipped by policy.

| Engine | Examples | Passed | Failed | Evidence |
|---|---:|---:|---:|---|
| jsdom | 18 | 18 | 0 | job 140829291391 |
| jsdom31 | 18 | 18 | 0 | job 140829291611 |
| Happy DOM | 18 | 0 | 18 | job 140829291613 |
| Selenium | 18 | 18 | 0 | job 140829291814 |
| Cuprite | 18 | 18 | 0 | job 140829291599 |

All four passing drivers reported both native and ARIA names as matchable and aria-labelledby lookup as false. This is evidence about Capybara's tested locator API, not full browser accessibility support. Every Happy DOM failure was associated with UNSUPPORTED_XPATH. This is not evidence that the corresponding CSS query or DOM operation is broken.

## CSS-only differential diagnostic

Five additional examples exercise explicit CSS attribute selectors, ambiguity/scoping, visibility/disabled state, localization and dynamic replacement/insertion. The original 18 examples and their expectations are unchanged. All five engines run the additional examples in the same matrix. The Happy DOM XPath failures remain visible; the CSS result must be assessed separately. Explicit attribute lookup is not equivalent to accessible-name computation or Capybara's configured test-ID lookup. No runtime change or XPath workaround has been introduced.

## Extended matrix evidence

Source: [run 46097203769](https://github.com/sergii/specdrive/actions/runs/46097203769), commit b8f153d. Core CI and Studio protocol passed; full/release workflows were skipped.

| Engine | Original locator contract | CSS-only contract | Total passed |
|---|---:|---:|---:|
| jsdom | 18/18 | 5/5 | 23/23 |
| jsdom31 | 18/18 | 5/5 | 23/23 |
| Happy DOM | 0/18 | 5/5 | 5/23 |
| Selenium | 18/18 | 5/5 | 23/23 |
| Cuprite | 18/18 | 5/5 | 23/23 |

97/115 executions passed, including 25/25 CSS-only examples. Happy DOM's original 18 failures remain visible. The four other engines again reported both names matchable and aria-labelledby lookup unsupported.

The worker's findHandles implementation delegates CSS to root.querySelectorAll and XPath to document.evaluate with ordered-node-snapshot result type. It raises UNSUPPORTED_XPATH when evaluate is absent. The current evidence therefore isolates the observed locator-suite gap to the XPath path, not the tested CSS interactions. It does not establish complete DOM or browser parity.

### Proposed decision (not implemented)

Keep jsdom/jsdom31 as the main Capybara compatibility targets. Retain Happy DOM as experimental with documented CSS-only capabilities. Do not globally rewrite Capybara selectors or silently fall back from XPath to CSS. Evaluate an optional XPath implementation in a separate experiment on the live Happy DOM document; require original node identity, scoped queries, document order, duplicate handling, label relationships, dynamic mutation and strict error semantics. Do not serialize and reparse the DOM for ordinary queries. Require the unchanged 18-example contract, wider XPath differential tests and controlled performance/memory measurements before proposing a production dependency. No blanket continue-on-error or skipped tests added in this change. Maintainer decision on whether to pursue XPath now or defer it is open.
