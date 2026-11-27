# Domstride 0.0.1 developer preview readiness

Status: release candidate preparation, not published. Evidence is tied to the commits below; rerun checks on the final candidate.

## Measured performance

Combined benchmark run [45910757069](https://github.com/sergii/domstride/actions/runs/45910757069), commit 11531ed. Ubuntu 24.04, Ruby 4.0.10, Node 22.23.5, one worker, YJIT off, five samples of ten warm stateful Rails scenarios with persisted-record checks. Chromium shared between browser references. Values are medians in seconds, not per scenario.

| Engine | Native baseline | Native candidate | Capybara baseline | Capybara candidate |
|---|---:|---:|---:|---:|
| jsdom 26 | 1.940914 | 0.703118 | 2.154388 | 1.582872 |
| jsdom 31 | 1.773633 | 0.688577 | 1.967181 | 1.583565 |
| Happy DOM | 0.649950 | 0.490976 | 0.590486 | 0.598233 |

References: rails-jsdom 0.2.1 (1.128220 s), Playwright Chromium (5.649855 s), Cuprite Chromium (11.417922 s). Happy DOM Capybara baseline is 19.3x faster than Cuprite in this scenario; optimized jsdom Capybara is about 7.2x. Native DSLs have different semantics and cannot be interpreted as a same-driver benchmark. Fixed order, warm sessions, fixture bundles and stateful database growth are limitations. Candidate jsdom native uses virtual clock/compiled bundle/tracked settling/observer; candidate jsdom Capybara uses compiled bundle/query prefetch, real clock. Happy DOM native candidate uses observer; its Capybara candidate is a control. These settings are not synonymous with all named profiles. No real-app speedup established. See combined benchmark script for exact configurations and artifact for samples.

## Evidence and gates

- [x] Core HTTP, JavaScript, form and Capybara subset tested on Node/jsdom 26, jsdom 31 and Happy DOM with documented engine exceptions (7173a05).
- [x] Real Action Cable loopback and Turbo stream-source tests pass on both jsdom engines (29781da).
- [x] Rails generator, explicit Cuprite browser selection, isolated gem install, runtime setup, named profiles and JSON doctor passed in [product readiness 45910757066](https://github.com/sergii/domstride/actions/runs/45910757066).
- [x] Combined benchmark completed; evidence above.
- [ ] Final candidate workflows pass, with no supported-engine failures.
- [ ] Review real-application discovery outcomes; document remaining blockers and avoid compatibility certification.
- [ ] Review dependency/runtime install reproducibility (runtime npm install does not yet use a retained lockfile), licenses and trusted-code security model.
- [ ] Review package contents and README against final version; choose version and release notes.
- [ ] Maintainer approval to merge, tag and publish. No automatic publishing.

## Supported scope

See compatibility.md for exact limitations. No rendering/screenshots/video, full browser semantics, complete Capybara suite, arbitrary network endpoints or sandbox. Bun is experimental. Use a real browser for unsupported cases, explicitly selected before test execution. Application code and fixture files must be trusted. DOM snapshots may include sensitive test data and are opt-in. No claim of production-ready replacement or complete 37signals application support.

## Follow-up candidates

Real app host/asset and authenticated Action Cable compatibility; general navigation/form submission and history; further upstream Capybara coverage; reproducible runtime lockfile; Cucumber/Turnip integration; semantic event recording and HTML replay versus actual rendered browser video. These are not part of the current release scope.

See [ordered roadmap](roadmap.md) for current follow-up priorities.

## Known developer-preview limitation (2026-11-27)

Maintainer accepted Fizzy as an explicit known limitation for the consolidation review, not as a passing check or a supported-app certification. Baseline CI 46068831277: join_account passed; create_card, lightbox and navigation failed. Recorded errors include missing ResizeObserver and ElementInternals.setValidity. Keep the original functional workflow and assertions unchanged; do not suppress failures. The consolidated candidate must still pass all other applicable workflows, and any changed Fizzy failure must be investigated. Final merge, tag and publication require separate maintainer approval.
