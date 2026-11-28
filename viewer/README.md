# Independent Viewer - internal preview

This is a name-neutral, independently versioned local distribution candidate, not a public package or the final Viewer product name.

Build from checkout: `ruby viewer/build.rb /absolute/new-directory`.

From the resulting directory:
- `bin/viewer --version`
- `bin/viewer report /path/to/suite /path/to/new-report.html`
- `bin/viewer replay /path/to/recording /path/to/new-replay.html`
- `bin/viewer docs export --synthetic-reference /path/to/guided-run`

Report and Replay require Ruby 3.3+ with standard distribution libraries, and a browser to view the standalone HTML. The optional static Markdown/MDX exporter also requires Node.js (no npm dependencies). No engine, Rails, browser driver or test runner is included. It reads completed local evidence; it does not run tests, record evidence or upload anything. Static publication is restricted to explicitly approved trusted synthetic paired runs. No production redaction or untrusted publication guarantee.

See protocol/compatibility-v1.json for supported artifact profiles. manifest.json lists SHA-256 and sizes of packaged files (integrity inventory, not a signature). The Viewer version is separate from the Specdrive gem version and the wire schema version. Existing gem-based report/replay commands remain supported.
