# Capybara compatibility contract (experimental)

This is a maintained subset, not the complete upstream Capybara spec suite.

| Capability | jsdom 26/31 | Happy DOM |
|---|---|---|
| CSS/scoped selectors, text/count filters | Contract tested | Contract tested |
| Visibility (DOM/CSS approximation, not layout) | Contract tested | Contract tested |
| Text inputs and textarea | Contract tested | Contract tested |
| Checkbox/radio native activation | Contract tested | Contract tested |
| Standard XPath field locators | Contract tested | Pending |
| Async query retry | Contract tested | Contract tested |
| Refresh and reset | Contract tested | Contract tested |
| Stale handles across reset/detachment | Contract tested | Contract tested |
| Layout, geometry, screenshots | Unsupported | Unsupported |
| File upload, select options, keyboard modifiers | Unsupported | Unsupported |
| Redirects, history, external asset pipeline | Unsupported | Unsupported |

"Contract tested" identifies intended CI coverage, not a guarantee of a successful run or browser equivalence. See the compatibility workflow artifact for observed results.

## Real application adoption gates

Before claiming support for Campfire, Fizzy or Writebook, pin an accessible upstream revision and reproduce its normal asset boot and test setup. Inventory importmap/module scripts, external assets, Turbo navigation/redirects, Action Cable, file uploads, browser storage and test helper assumptions. Run the application's original browser tests first, then a supported subset unchanged where possible. Record unsupported cases separately, never silently skip failures and never retry mutations automatically in a real browser.

Current fixture supports inline classic JS and same-origin GET/URL-encoded POST. Real-app compatibility and performance are not yet established.
