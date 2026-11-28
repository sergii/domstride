# Specdrive 0.0.1 developer preview candidate

Status: preparation only, not approved for public release. PR #20, base cb8222e, phase 4 head e886227. The earlier namespace candidate 99ee2c8 passed product readiness, required Node/jsdom CI, installed-gem consumer, independent Studio protocol, isolated Viewer and Capybara/Cuprite benchmark at review time. Other workflows were still running; the phase 4 workflows were queued. No final CI claim.

## Product boundary

- Specdrive 0.0.1: Ruby engine and producers; specdrive gem and canonical Specdrive module. Legacy Domstride constant, CLI, require paths and v1 identifiers remain usable. No separate legacy gem is built.
- Independent Viewer 0.0.1: local name-neutral distribution; offline report/replay and opt-in trusted synthetic static publication. No engine, runtime or recorder files in its allowlist. Existing compatibility CLI still ships in the engine gem. Final Viewer branding and public package distribution are separate decisions.
- Protocol v1: existing case/recording/specification/run profiles; no v2 or fabricated video timing.

## Evidence and limitations

The 99ee2c8 specdrive-gem-preview CI ZIP is 88,753 bytes; PR #19 final reviewed phase-6 ZIP was 86,653 bytes. These are compressed artifact sizes, not installed footprint. No final independent Viewer package size or final A/B results were available at review. The new audit workflow builds candidates, emits raw gem size and file inventory, verifies Viewer hashes, and alternates base/head Capybara benchmarks on one runner with matched dependency resolution and persisted-record checks. Ratios require human review, not a noisy CI threshold. It measures jsdom and jsdom31 on a synthetic Rails workload, not general performance or every engine.

Ruby Replay retains the existing CSP, nonce, inert snapshot reconstruction, bounded input sizes, attachment name restrictions and no-overwrite output. This is a code review of existing safeguards, not a penetration test or general malicious-input certification. The Node documentation exporter is trusted synthetic evidence only; no production redaction or untrusted publication. Runtime executes trusted application code, not a sandbox. Explicitly inspect all evidence before sharing; screenshots, HTML, video and logs can contain secrets or personal data. No automatic upload in product; CI fixtures are synthetic.

Direct npm versions are pinned but the installed runtime still resolves transitive dependencies without a committed lockfile. Dependency license inventory and advisory review remain open. The package name specdrive was not found by public search; the exact public RubyGems page could not be verified. Availability and account ownership are not established.

## Release gates

- [ ] All final applicable workflows complete; only previously accepted Fizzy failures may remain. Compare actual error signatures.
- [ ] Review same-runner A/B output, package file inventory, size and hashes.
- [ ] Review final real application outcomes and supported Ruby/runtime matrix.
- [ ] Confirm public RubyGems name and ownership, release credentials and repository naming.
- [ ] Complete dependency/advisory/license review and decide reproducibility policy.
- [ ] Restrict publication to documented trusted developer-preview scope; no production redaction claim.
- [ ] Maintainer approval to merge, tag and publish separately. Do not automatically publish.

## Local build and rollback

```sh
gem build specdrive.gemspec
gem install ./specdrive-0.0.1.gem --no-document
specdrive setup
specdrive doctor
ruby viewer/build.rb ./dist/viewer
./dist/viewer/bin/viewer --version
```

Use an isolated GEM_HOME for evaluation. To roll back the local preview, remove that isolated installation and Viewer build directory; return to the pinned pre-rebrand commit if needed. Existing v1 evidence and runtime cache are not rewritten. If a public version is eventually published, follow RubyGems release and yank policies; never overwrite a published version. No merge, tag, rename or publish executed.

## CI policy update

See [CI execution policy](ci-policy.md). The first audit built both candidates but stopped at an independently resolved Ruby lockfile mismatch. Seed candidate from normalized baseline lock and require frozen installation rather than comparing independently resolved locks. PR #20 is labeled ci:release; all checks remain required for this review. Concurrency cancels superseded PR runs in the same group. Earlier runs without the policy may still occupy runners. No new A/B result yet.
