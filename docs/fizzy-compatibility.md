# BATCH-007.1: Fizzy functional compatibility

Pinned Fizzy revision 071062ca9193c416ec07a3225a7c5bae8da0db64. Previous discovery run 45911587513 demonstrated ActivityPaginationTest browser baseline (1 run, 3 assertions) and a Domstride setup error before the first assertion. That test requires scroll position, IntersectionObserver and asynchronous script callbacks.

## Test selection before candidate execution

| Group | Original file | Expected cases | Reason |
|---|---|---:|---|
| navigation | back_link_navigation_test.rb | 5 | Links, URLs, filters |
| create_card | smoke_test.rb | 1 | Form, editor |
| join_account | smoke_test.rb | 1 | Magic-link flow, keyboard |
| lightbox | smoke_test.rb | 1 | Dialog and attachment alt text |

Selection is intentional coverage exploration, not a representative random sample. Original test bodies and assertions remain unchanged. Exact case counts, no skips, successful exit, and equal assertion counts are required for functional_subset_passed.

## Browser-only checks

- TrustedTypesViolationsTestHelper is report-only Chromium CDP and sessionStorage inventory. Keep it on browser baseline; omit only its include in the temporary candidate helper and label candidate inventory not_measured. Never fake CDP or report zero violations.
- Activity pagination, board scrolling/hover/geometry, keyboard focus dependent on scrolling, responsive diagrams and CSS layout require a browser.
- OAuth consent tests depend on browser CSP, Origin and cross-origin navigation; do not convert them to browserless security tests.
- Broadcast refresh, additional attachments and editor interactions require further review.

## Isolation and evidence

Each group receives a separate pinned checkout and test database. The browser baseline uses the documented discovery-only fresh Chrome reset shim. Candidate uses original test selection, compatible profile, experimental asset bundling, logical Rack host and database reset. Restore helper in ensure and verify test file digest. Preserve logs, browser Trusted Types inventory if present and candidate results. No speed comparison: fresh browser sessions and changed instrumentation make timings incomparable.

The dedicated workflow fails unless selected functional cases pass. The broader discovery workflow only collects evidence. Product runtime is unchanged by this batch. No full application certification.

## Observed result at a5a9e7c

[Fizzy functional run 45912190145](https://github.com/sergii/domstride/actions/runs/45912190145): all 8 original Chrome cases passed (24 assertions). All 8 Domstride candidates errored before any assertion with esbuild direct eval warnings promoted to errors by the asset loader. This is the next concrete asset compatibility blocker, not a business assertion failure. Retain the strict gate; investigate warning policy and direct eval semantics separately from recording.

## Follow-up: direct eval warning policy

The original 8-case baseline passed, while the candidate stopped at esbuild direct-eval warnings. The default remains strict. Only an explicit DOMSTRIDE_ASSET_WARNINGS=direct-eval permits esbuild's exact direct-eval warning ID; each permitted warning reports its source location to stderr without the source line. All other warnings, build errors and runtime JavaScript exceptions remain fatal. The candidate records this policy and retains original tests, counts and assertion-parity gates. A passing synthetic lexical-scope regression is not proof of arbitrary eval or module semantic equivalence. No success claim until original cases pass.

## Follow-up: static media environment

Run 45915924240 at 467ef6d: all 8 original Chrome cases passed (24 assertions). The asset loader passed the two direct-eval warnings in Active Storage; all 8 candidates then errored on Turbo's window.matchMedia (7 candidate assertions total). This is real progress beyond asset boot, not passed tests. Core regression fixture failed because its inline script lacked an explicit ES module export; corrected fixture uses an exported function and lexical eval.

The candidate now opts into DOMSTRIDE_MEDIA_PROFILE=static-desktop: static 1200x1000 media-query evaluation, light color scheme and reduced motion, not an actual viewport or Chrome preference parity. Simple width/height px, orientation, screen/all/print and the two preference queries are supported; unsupported expressions fail explicitly. Listener registration uses EventTarget but there are no automatic changes or resize events. No CSS rendering, computed layout or geometry support. Default off. Preserve real browser coverage of responsive behavior and all original functional assertions.

## Follow-up: logical DOM API subset

Run 45916895482 at 8867ebe: all 8 Chrome cases passed (24 assertions); candidates reached 8 assertions total but all 8 errored. matchMedia blocker gone. Observed next errors: Element.checkVisibility, HTMLDialogElement.close, Window.scrollTo and unconfigured WebSocket. All 16 other workflows passed.

DOMSTRIDE_DOM_PROFILE=logical is a separate opt-in Node/jsdom profile. Visibility evaluates connectedness, CSS display/hidden ancestry, content-visibility hidden ancestors and optional opacity/visibility properties, not box geometry or occlusion. Dialog methods track open/returnValue and emit close events; modal focus management, top-layer/inertness, Escape and form method=dialog are not implemented. Window scrolling tracks requested nonnegative offsets and dispatches scroll events; no layout-based bounds, element scrolling, smooth animation or intersections. Unsupported smooth scrolling and contentVisibilityAuto fail explicitly. WebSocket is unchanged and remains an independent blocker. Original tests and strict parity gate retained.
