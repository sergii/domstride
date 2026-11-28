# CI execution policy

## Tiers

- Fast: core Node/jsdom test suite and gem build in ci.yml, plus independent Studio protocol. Runs on every PR commit.
- Full integration: all functional integration workflows (Rails reference, BDD, browser capture, real apps, Fizzy, installed consumer, isolated Viewer and other contracts). Runs on non-draft PRs or draft PRs labeled ci:full or ci:release.
- Release/performance: dedicated benchmarks, developer preview audit and experimental matrix steps in ci.yml. Runs on PRs labeled ci:release or manual dispatch; existing main-push triggers remain enabled. Use ci:release for final review of release PRs.

Labels are explicit opt-in switches; ci:release includes full integration. Relevant label additions/removals, ready-for-review, and conversion to draft re-evaluate the policy. Unrelated label events do not cancel real jobs. Workflows intentionally run without path filters so a labeled final PR gets the whole matrix, including when the last edit is documentation only.

Each workflow has a concurrency group scoped by workflow and ref. PR updates cancel older runs in the same group; main-push and manual runs are not force-cancelled by this policy. Runs started before this configuration did not have these groups and may need manual cancellation. No global cap or runner provisioning is configured.

GitHub may show skipped jobs as successful checks. Skipped, cancelled, missing or stale jobs are NOT evidence of verification. Before merging a release PR, require ci:release and actual completed jobs on the reviewed head, with only documented accepted failures. No branch protection, automatic merge or publish changes. Manual audit dispatch can optionally provide a full baseline SHA; without it, only package inspection runs.

## Performance lockfile policy

Resolve baseline Ruby and npm dependencies once on the same runner. Normalize only the local Ruby root gem rename (domstride to specdrive), copy the baseline lock to the candidate, install with BUNDLE_FROZEN=true and npm ci, then compare lockfile bytes. Any dependency change stops the controlled benchmark; do not compare unlike resolutions or silently relax the check. Upload baseline and candidate lockfiles and failure evidence for review. This is a benchmark reproducibility measure, not a committed production runtime lockfile.

## Transition

PR #20 has ci:release, so it retains all release and integration checks even while draft. Audit run 46092313336 failed at comparison of independently resolved lockfiles (byte 7126, line 286); no engine regression was established. The new policy and corrected audit need CI verification.

Audit 46092871140 passed package inspection but Bundler 4 rejected the missing renamed CHECKSUMS entry in frozen mode. The normalization now renames the digest-free local checksum entry and keeps all external checksums unchanged, with fixtures for old/new names, legacy lockfiles and unexpected local digests. Frozen installation remains mandatory; A/B still pending.

Audit 46093245571 passed package inspection and checksum migration fixtures but frozen Bundler still requested a lockfile rewrite. The candidate is now serialized by Bundler itself using bundle lock --local from the seeded baseline; full lockfile comparison tolerates only ordering of flat DEPENDENCIES/CHECKSUMS/PLATFORMS sections. Sources, dependency edges, versions, checksums and Bundler version remain checked. Freeze and compare actual bytes after the local serialization. Any semantic drift stops the benchmark and uploads comparison files. New CI required.
