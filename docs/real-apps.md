# QA-003: real application discovery

Pinned source revisions:

| App | Repository | Revision | Ruby |
|---|---|---|---|
| Campfire | basecamp/once-campfire | 945c22f141795e910e2822d386a94c5686bf7bdc | 4.0.10 |
| Fizzy | basecamp/fizzy | 071062ca9193c416ec07a3225a7c5bae8da0db64 | 4.0.10 |
| Writebook | basecamp/writebook | f14775fc932457050554083be589f5ab89fdeed3 | 3.4.13 |

## Findings from source inspection

All three use Importmap, Turbo, Stimulus, Propshaft and real-browser system tests. Campfire includes Action Cable and Lexxy; its test helper waits for connected cable streams and rich-text input. Fizzy uses account-prefixed routes and session-transfer sign-in, Turbo offline, Lexxy and a Trusted Types CDP instrumentation helper. Writebook uses House editor and execute_script helper. Campfire and Writebook use SQLite and Redis-backed jobs; Fizzy supports configurable database adapters and Solid services.

These features exceed the current fixture. Missing external/module script loading, redirects, real WebSocket transport, general execute_script and browser-only helpers are known or likely blockers, not observed test failures until executed.

## Discovery protocol

Clone the pinned public upstream repository in an isolated CI job, install original dependencies plus Domstride as a local gem, and use the app's Ruby version. Select one existing authentication-related system test file by name if present, otherwise the first sorted file. Run the original test file on its original browser driver; require a nonempty successful run without skips before attempting Domstride. Reset the test database before the candidate run. Append only the driver override and screenshot support to the base test class, retaining original tests and helpers. Restore the helper afterward. Record exit codes, elapsed process time, test counts, source-level capability inventory and logs. The source inventory counts files containing patterns, not test coverage. No app sources are vendored.

Discovery outcome can be setup_blocked, browser_baseline_blocked, database_reset_blocked, candidate_blocked_or_different, or selected_file_passed. A green discovery workflow means evidence collection ran, not app compatibility. No speedup claim without equivalent successful cases; timings include Rails boot and are single runs. Follow-up requires full baseline, targeted feature fixes, repeated comparable benchmarks and a broader original-test subset.

## Observed discovery evidence and retry protocol

At commit 11531ed, Writebook and Fizzy completed their selected browser assertions (12 and 3 respectively) but errored during Capybara ChromeDriver#reset! with Chrome 158 rejecting wildcard CDP origin. Earlier Fizzy run 45908717577 reached Domstride and failed on current_window_handle before executing assertions. BATCH-005 adds single-window identity; this is not evidence the original Fizzy test now passes. Earlier Writebook run 45907772873 passed the selected browser file (2 runs, 12 assertions) but database reset was blocked. No real-app compatibility or speedup claim.

Discovery now retains the unmodified browser baseline and, only for the observed Chrome teardown incompatibility, resets the test database and retries with a discovery-only shim that quits the Chrome session instead of clearing wildcard-origin storage. No assertion or test body is modified. Reports retain the original and retry phases and label the baseline mode. Candidate driver uses the logical Rack host and experimental asset mode. Retry timings include fresh browser startup and must not be used for performance claims. A failed retry remains a blocked baseline. A selected file passing is not suite-wide compatibility.
