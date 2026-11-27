# Suite reports (BATCH-009, first slice)

Explicitly capture each test with Domstride::Report.capture(directory: "tmp/domstride-suite", name: "Create expense", html: true) { ... }. Default html false. Sessions created inside that fiber-local scope use its private case directory and HTML policy, taking precedence over recording environment or explicit recording options. Existing sessions are not reassigned. Close/reset sessions inside the block. Case status comes from the block completing or raising; explicit status= supports skipped/pending/unknown. For frameworks that consume exceptions internally, set the actual framework status yourself. Automatic RSpec and Minitest adapters are available below; the manual block remains supported. An exception is re-raised without serializing its message. Case names and raw HTML can contain sensitive information; export locally only.

Run bundle exec domstride report tmp/domstride-suite to create report.html (0600, no overwrite). Select a case by name/status, select its recording, navigate snapshots with existing before/after and reversible layout. Multiple recording workers per case are supported. No recordings is a valid case. Command success is not test success. Case directory and file symlinks rejected. Limits: 100 cases, 200 recordings, 32 MiB aggregate unescaped trace JSON, existing per-recording bounds. Report export does not scan arbitrary directories recursively or execute application code. Suite-level browser UI tests passed (45921278517). Automatic assertion-to-operation mapping and Cucumber lifecycle remain follow-up.

## Framework integration (009.2)

RSpec (spec_helper.rb):

```ruby
require "domstride/reporting/rspec"
Domstride::Reporting::RSpec.install!(directory: "tmp/domstride-suite", html: true)
```

Minitest (test_helper.rb):

```ruby
require "domstride/reporting/minitest"
Domstride::Reporting::Minitest.install!(directory: "tmp/domstride-suite", html: true)
```

Install once before the suite. HTML is opt-in (default false). RSpec uses final reporter notifications including skipped, pending, fixed-pending, setup and teardown results. Minitest wraps Test#run and reads the returned Result status and assertion count. Assertion counts are not inferred for RSpec. Frameworks are optional dependencies; requiring an adapter needs the corresponding gem. Existing sessions outside the case are not reassigned; use normal per-test Capybara reset or close sessions. Fiber-local scope is not propagated to app/server threads. Use a fresh suite directory each run; report export stays explicit and preserves failure exit codes. Only individual examples/tests are represented, not failures outside example execution or automatic Gherkin step mapping. Process-level parallel workers can write separate case directories on shared storage; framework-specific parallel runners remain unverified.

## Gherkin step mapping (009.3)

Cucumber: in features/support/reporting.rb, `require "domstride/reporting/cucumber"` then `InstallPlugin { |config, _registry| Domstride::Reporting::Cucumber.install!(config, directory: "tmp/domstride-suite", step_text: true) }`. Turnip uses the existing RSpec adapter with `step_text: true`; it subscribes to Turnip custom step events. Step text defaults off, keywords/status/duration still recorded. Scenario names may themselves contain parameter values, notably Turnip full descriptions. Only actual framework events are mapped; not-run Turnip steps may be absent, hooks are excluded, undefined/ambiguous step states retained when emitted. Step sequences override manual BDD wrapper sequence within the active framework step; operations outside a step remain separately recorded. Explicit assertion wrappers may produce no DOM operation; do not fabricate snapshots for such steps. Select a Gherkin step to jump to its first mapped interaction across worker recordings. Step limits 100 per case. Test report remains local and inert; no doc strings/data tables/error messages captured by step adapter. Existing report cases without steps still load. Framework adapters verified before this change (45921849166); this change pending CI.
