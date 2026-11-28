# Batch 013.6 - verified event replay links

Stacked on #31. Isolated coverage CLI passed on Ruby 3.3 and 4.0 (46101824778). For the synthetic Rails fixture only, explicit attribution-enabled export now retains HTML snapshots and the completed recording in fixed relative directories recording-1, recording-2. Mapping adds optional recording_ref with directory, digest of sorted file inventory and event_sequence. This digest is an integrity binding, not authentication. No default capture or production changes.

The independent coverage-bundle command validates references, file names, symlinks, bounded file sizes, digest, complete recording, unique sequence, successful click and exact before target_path. Require actual before HTML. Generate local event-only replay documents using the existing renderer (no modification to replay UI), with links only for verified observations. Existing coverage command remains metadata-only. Test actual Rails export through isolated Viewer plus rejected digest/traversal/wrong target/overwrite. CI pending. Full suite/scenario navigation and full-timeline deep links are separate future work; no inferred Gherkin or assertion linkage. Raw synthetic snapshots are sensitive in real apps; no publication or generic untrusted-artifact claim.

## Checkout import correction

[Run 46101957691](https://github.com/sergii/specdrive/actions/runs/46101957691) failed at require_relative before Rails attribution ran: the source checkout keeps the Replay consumer under root lib/, while the built Viewer stages it beside coverage_bundle.rb. Use the standard load-path require, resolved by Bundler for the local gem or by the independent CLI's staged lib path. All other focused workflows on 9870a4d passed. No changes to integrity assertions or production code. Revalidation pending.

## Isolated process path correction

[Run 46103135246](https://github.com/sergii/specdrive/actions/runs/46103135246), job 140849882341, passed Rails attribution and coverage export, then failed before bundle verification: the smoke test passed a checkout-relative input path to a child process whose cwd is an independent temporary directory. Normalize both command arguments to absolute paths before changing cwd. Keep the independent cwd and all recording integrity/no-overwrite checks. No producer or consumer behavior changes. Revalidation pending.
