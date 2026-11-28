# Capybara compatibility contract (experimental)

Maintained subset, not the complete upstream Capybara spec suite. Evidence: BATCH-003 corrective commit 7173a05, BATCH-004 commit 29781da, and BATCH-005 product readiness at 11531ed. Node runtime only for supported configurations; Bun is experimental and has known failures.

| Capability | jsdom 26/31 | Happy DOM |
|---|---|---|
| CSS/scoped selectors, text/count filters | Contract tested | Contract tested |
| Visibility (DOM/CSS approximation, not layout) | Contract tested | Contract tested |
| Text fields, textarea, checkbox/radio | Contract tested | Contract tested |
| XPath field locators | Contract tested | Experimental XPath 1.0 adapter; integration verification pending |
| Async query retry, refresh, reset, stale handles | Contract tested | Contract tested |
| GET/HEAD/POST/PUT/PATCH/DELETE; JSON and URL-encoded bodies; same-origin redirects | Contract tested | Contract tested |
| Single/multiple select and basic text keyboard events | Contract tested | Contract tested (driver live option values) |
| Synchronous execute/evaluate with JSON and element arguments | Contract tested | Contract tested |
| Same-origin classic/static modules and bounded controller imports | Experimental opt-in, tested | Unsupported |
| Explicit fixture attachment and binary multipart fetch | Experimental opt-in usage, tested | Attachment unsupported |
| Loopback Action Cable/Turbo source | Experimental opt-in, tested | Unsupported |
| Scoped Capybara accept/dismiss confirm (optional string text) | Experimental; no interactive dialog | Experimental; no interactive dialog |
| Single-window identity | Contract tested | Contract tested |
| Immediate window scroll to origin (Rack bridge only) | Narrow compatibility shim; no layout or scroll events | Not changed by shim |
| Layout, geometry, screenshots, hit testing, multiple windows | Unsupported | Unsupported |
| Browser form navigation/history, native module semantics, arbitrary dynamic imports, full Web APIs | Unsupported | Unsupported |

The jsdom Rack bridge accepts immediate `window.scrollTo(0, 0)` / `window.scroll(0, 0)` and equivalent zero-coordinate options for Turbo navigation. Nonzero positions and smooth scrolling raise `UNSUPPORTED_SCROLL`; scroll restoration, element scrolling, geometry and scroll events are not provided by this shim. JavaScript error reporting remains enabled.

Confirmation is a synchronous pre-armed decision within a Capybara block, not a rendered modal. String text is matched by substring before acceptance; mismatch returns false and raises ModalNotFound on the Ruby side. Missing dialogs time out; unexpected or repeated confirms report JavaScript errors and are not accepted. Regex, alert, prompt and interactive modal timing are unsupported. A decision cannot undo side effects already performed by the application. Regression tests are pending execution.

Real Action Cable integration does not cover cookie-authenticated connections or full turbo-rails custom element behavior. Virtual clock and sockets cannot be combined. File upload is a FileList approximation with 8 MiB cap. Keyboard modifiers, IME, automatic keyboard submit and native focus traversal are not implemented. Use explicitly selected real-browser driver for these scenarios, never automatic retry after failure.

See [real application discovery](real-apps.md) for pinned revisions and blockers. No Campfire, Fizzy or Writebook compatibility certification. Tests and code must be trusted; DOM workers are not a sandbox.
