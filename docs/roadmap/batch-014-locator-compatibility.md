# Batch 014 - Locator Compatibility & Semantic Target Identity

Tracking: [#21](https://github.com/sergii/specdrive/issues/21). Phase 1 integrated in main at 04b6515; Phase 2 bounded target metadata candidate below. Final integration CI remains pending.

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

## Isolated XPath experiment (candidate 1)

Evaluate Wicked Good XPath 1.3.0 ([upstream](https://github.com/google/wicked-good-xpath)) first because it exposes DOM Level 3 XPath on HTML documents. Its age and maintenance/security status require review before any production use. Alternative candidates include xpath (XPath 1.0, XML-oriented DOM compatibility to check) and FontoXPath (XPath 3.1, XPath 1.0 compatibility mode off). No dependency is approved for production.

The lab installs the candidate only under examples/xpath_lab. A direct Node probe tests node identity, mutations, scopes, axes, union ordering, label relations and invalid/scalar results against explicit expectations and jsdom. A separate staged runtime cache copies the existing runtime and patches only the absent-evaluate branch in the copy; then runs the unchanged 23-example Capybara contract against Happy DOM. The normal worker, gem inventory, root/runtime package manifests and existing compatibility matrix are untouched. The experimental candidate is never loaded in normal execution. CI publishes raw dependency resolution, logs and RSpec results. A failed experiment is not ignored.

The small query microbenchmark is descriptive, not an end-to-end speed claim. Broader XPath/browser differential coverage, compiled expression performance, memory/worker reuse and security/licensing review are required before considering any opt-in production integration.

### Candidate 1 installation result

[Run 46097570762](https://github.com/sergii/specdrive/actions/runs/46097570762), c65706b: dependency installation and isolated cache staging passed; direct probe failed because document.evaluate remained undefined after installation; 18 standard locator examples failed with UNSUPPORTED_XPATH and all five CSS examples passed. No benchmark samples were emitted. This is an installation failure, not yet evidence of XPath expression correctness.

The upstream [installer](https://github.com/google/wicked-good-xpath/blob/master/src/wgxpath.js) prefers the exported Document.prototype if present; otherwise it uses the supplied document. The next iteration explicitly supplies a document-only target to install on the actual live document, shared by the direct probe and staged worker. This is a hypothesis-driven lab fix; no global prototype patch or production dependency. Verify the installer postcondition before evaluation. Existing assertions and original matrix remain unchanged.

### Candidate 1 direct document result

[Run 46097818239](https://github.com/sergii/specdrive/actions/runs/46097818239), e6cbaa5: direct live DOM probe passed. Happy DOM with Wicked Good XPath passed 11/23 examples (including 5/5 CSS-only); 12 failures included false ambiguity and missing fields/buttons on real Capybara expressions. Do not promote this candidate. Native jsdom samples (ms/1000 queries): 304.859725, 287.344322, 291.280892, 284.088321, 283.057145. Happy DOM candidate: 14.177736, 11.905499, 7.902534, 8.671475, 4.439527. Medians 287.344 and 8.671 ms, about 33.1x for this single simple query on this runner only. No end-to-end speed claim; correctness is incomplete.

### Candidate 2 and query evidence

Compare pinned xpath 0.0.34 with wgxpath using the same fixture, probe and unmodified Capybara suite in separate jobs. The xpath adapter supports only ordered node snapshots with no namespace resolver for the experiment. It uses parsed expression selection with explicit HTML mode on the original context node; namespace behavior needs broader verification. No general document.evaluate API compatibility is claimed. Upstream API: https://github.com/goto100/xpath/blob/master/docs/XPathEvaluator.md. Log each distinct XPath expression and returned tag/id once per synthetic document during RSpec only; capture neither values nor text, and do not enable tracing for microbenchmarks. Keep failure evidence and both candidates isolated from production. Results pending.

### Candidate 2 result and end-to-end gate

[Run 46098171178](https://github.com/sergii/specdrive/actions/runs/46098171178), 813efa1: xpath 0.0.34 direct probe and unchanged Capybara suite passed (23/23). Both native and ARIA labels match; aria-labelledby probe remains false. Wicked Good XPath again passed 11/23. Its Pet name query returned ten nodes before Capybara filtering, versus exactly pet-name with xpath. Do not promote wgxpath.

For xpath, the same-runner native jsdom median was 377.171680 ms/1000 queries and Happy DOM + xpath was 144.836505 ms (2.60x for this query). The wgxpath comparison ran on a separate runner; do not compare its absolute times across jobs. Neither result measures a whole Rails scenario.

The new isolated end-to-end workflow exercises the existing Rails expense reference with standard Capybara field labels and button text replacing CSS for form actions; retains Turbo/Stimulus, validation, authentication, CSRF and persistence checks. Same runner, same dependencies, staged worker for all three engines, three cyclic order rounds, fresh Ruby process/worker/database per run, one warmup then three batches of five measured scenarios. 45 measured scenarios per engine, 135 total. Trace disabled; no production changes. GNU time maximum RSS (KiB) is a process high-water measure, not a simultaneous aggregate Ruby+Node memory measurement. Raw process wall time and stderr are retained; any correctness failure prevents a complete comparison. These are experimental results pending CI. Wider semantics, memory attribution, licensing/advisories, and opt-in production design remain open.

### Production integration candidate

[Run 46098343571](https://github.com/sergii/specdrive/actions/runs/46098343571): all 135 measured Rails scenarios passed (45 each). Median seconds per five scenarios: jsdom 1.264162865, jsdom31 1.198239129, Happy DOM + xpath 0.436499758. Median GNU time maximum RSS KiB: 230140, 241056, 155140. Same-runner balanced rounds, no trace, fresh processes per round, persistence checked. The isolated candidate was about 2.90x faster than jsdom and 2.75x faster than jsdom31 on this fixture, not a general Testbench speed guarantee.

Maintainer approved gem integration. Pin xpath 0.0.34 in checkout and installed-runtime manifests, include happy_xpath.cjs in the runtime cache digest/manifest, check dependency availability in setup, and lazy-load it only for Happy DOM XPath queries when native evaluate is absent. No application document patch, expression cache, serialization, global Capybara configuration or default engine change. Only element-node results are supported; namespace behavior is experimental. Existing jsdom and CSS paths stay unchanged. Remove obsolete Happy DOM XPath skips from the Rails reference suite and add installed gem smoke coverage. The end-to-end workflow now exercises the actual runtime directly. The rejected wgxpath lab remains manually dispatchable, not a required PR check. Full security/advisory and broad namespace conformance review remain open. Integration CI pending.

## Phase 2.1 - Bounded semantic target metadata

Optional additive recording v1 frame field target_identity (extension version 1). Captured only for existing recorded node mutations and native click/fill, from the existing live target before and after the action. basis distinguishes resolved_handle from selector_match; neither claims successful action or computed accessible name. A detached target has no after identity. No locator arguments, selector strings, label text, attribute values, input values, accessible names or custom test ID values are collected. tag/input_type are fixed enums; hints are attribute presence flags, with native_label nullable if the DOM API is unavailable. test_id specifically means data-testid presence, not arbitrary Capybara test_id configuration. No cross-document identity claim. Do not infer role/name from presence flags. Existing recording opt-in is the boundary; raw HTML snapshots remain sensitive and are not redacted by this extension.

Producer and consumer validate the fixed shape; malformed/unknown optional identities are discarded, legacy recordings still work. Viewer displays metadata for the selected phase in DOM mode only, with textContent. No changes to case format, video cues, Gherkin steps, existing highlight or fast-path command arguments. No additional query or capture when record_event is absent. Tests cover privacy, detached nodes, Capybara handles, old artifacts, malformed extension and offline Viewer phase switching. CI and same-dependency A/B performance verification pending. Requested human locator text and richer semantic labels require a separate explicit privacy policy; not implemented. 

### Phase 2.1 initial verification

Draft PR #27, a70d487: [Core CI 46098944303](https://github.com/sergii/specdrive/actions/runs/46098944303) passed 90 tests, 477 assertions, zero failures/errors/skips, production XPath contract and gem build. Full recording/Viewer and performance audit not yet verified. Enable the existing recording, isolated Viewer and developer preview A/B workflows specifically on this draft branch, leaving other release gates unchanged. This reuses the existing frozen shared-dependency A/B methodology for jsdom/jsdom31 (800 measured scenarios); it does not establish a Happy DOM fast-path benchmark. Add a separate same-runner Happy DOM comparison before claiming its performance parity.

### Phase 2.1 recording and Viewer verification

At 36f9ec2: [recording matrix 46099146460](https://github.com/sergii/specdrive/actions/runs/46099146460) passed for all three engines. Each ran 13 Ruby tests and 143 assertions, zero failures/errors/skips. jsdom31 additionally passed all three browser replay/video tests. [Independent Viewer 46099146160](https://github.com/sergii/specdrive/actions/runs/46099146160) passed both offline Chromium tests and staged distribution checks. Core and Studio protocol succeeded. Extend the existing developer preview A/B run on this feature branch to include Happy DOM, with the same locked dependencies, CSS-based Rails scenario and persistence checks, four alternating paired rounds per engine, 400 measured scenarios per engine (1200 total). Explicitly unset recording environment variables. No universal performance SLA, and no claim about the semantic XPath-specific workload or recording-enabled overhead. Other release audits retain their existing default engine pair. Final A/B results pending.

### Phase 2.1 A/B results and baseline synchronization

[Audit 46099525556](https://github.com/sergii/specdrive/actions/runs/46099525556) passed on 4aa9eba against 04b6515, all 1200 measured scenarios. Median paired head/base ratios: jsdom 0.9925409755 (-0.75%), jsdom31 1.0161009913 (+1.61%), Happy DOM 0.9800552079 (-1.99%). No material slowdown observed on this CSS-based fixture, no formal SLA. Core, recording, independent Viewer, Studio protocol and integrated Rails XPath workflows all passed on that head.

Main advanced to 18e9d675 (PR #26 automatic persistent Node worker reuse). Compared both branches against 04b6515: main changed README.md, lib/domstride/capybara.rb, and test/capybara_worker_lifecycle_test.rb; none overlap PR #27 changes. Preserve both histories in a merge commit on the feature branch with all three main files copied exactly from main. Re-run targeted CI and A/B against the current main baseline; in particular validate recording isolation after the lifecycle change. No change to the target metadata implementation. Do not treat the earlier A/B as proof for the combined revision.

### Combined persistent-worker audit and multipart baseline

[Audit 46099959932](https://github.com/sergii/specdrive/actions/runs/46099959932) passed on fed67e8 against 18e9d675. All 1200 measured scenarios; paired median ratios jsdom 0.9861397097 (-1.39%), jsdom31 1.0005903713 (+0.06%), Happy DOM 0.9942735443 (-0.57%). All six focused workflows succeeded. Main subsequently merged PR #25 at 0eb37b1; three changed files (Capybara adapter, forms runtime, multipart contract) do not overlap the semantic-target diff. Merge current main into the feature branch preserving both parents and copy those three files exactly. Revalidate the combined revision; prior audits are workload-specific evidence, not a guarantee of zero overhead. No new feature changes.
