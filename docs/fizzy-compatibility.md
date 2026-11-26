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
