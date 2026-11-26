# Architecture and benchmark policy

ADR-001: independent implementation, one modular gem. rails-jsdom is prior art, not a copied implementation. Maintain attribution and record upstream commit/license if source is incorporated later.

Ruby Session owns a persistent subprocess; JSON-lines requests are serialized and carry correlation IDs. The worker executes synchronous DOM actions with jsdom and returns scalar results. No full HTML snapshots by default. Only trusted test fixtures are supported: jsdom script execution is not a security sandbox.

MVP exclusions: Rails requests, virtual clock, async settling, Turbo/Stimulus, forms beyond click, production-grade process timeout, packaging JS dependency installation and browser conformance. Never claim browser equivalence until tested.

Benchmark policy: run identical code with Node and Bun on the same VM, record runtime versions and CPU metadata, repeat 5 times, distinguish cold startup from warmed click/assert IPC. Report medians and all raw samples. Synthetic counter benchmark does not measure Rails or compare against upstream. Next: pinned upstream baseline, Rails fixture app and Chromium parity, then profiling and selective optimization.

## ADR-002: experimental engines and batch commands

The runtime takes an explicit DOM engine argument. Happy DOM is an experimental adapter; inline script evaluation is enabled for trusted fixtures only, with external JavaScript/CSS loading disabled. Neither engine is a security sandbox.

Batch commands preserve synchronous order, check every intermediate assertion, and stop at the first failure. No rollback or async settling is promised.

EXP-002/003/005/006: four runtime-engine combinations, five rotated-order repeats, individual vs batch with identical assertions, fresh process vs persistent worker with identical remounts, and Linux worker VmHWM (peak RSS). Report experimental failures explicitly. Lockfiles are collected as artifacts until committed. No browser or Rails parity claim.
