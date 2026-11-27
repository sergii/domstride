# MVP consolidation review

Status: integration candidate; final merge not approved. Source branch heads are pinned. No existing PR has been closed or retargeted.

- Foundation #1: 6847a496b46c1d958c1024ed8d2862acac092972 (49 commits ahead of main).
- Compatibility #3/#5/#7/#9: 2709fdded30cc33a3ee6c96b51b570fc1415b520, replayed cumulative changes from 0f7efe9 onto current foundation. Retain keyboard and authenticated websocket cookie propagation while adding scoped confirmation and abort handling.
- Performance #11–15: 1a7e3b5fcd808cd389b7baa729973b636449d84a, cumulative changes from dd735a4; maintain selected jsdom parser, isolated VirtualConsole, websocket asset cookie updates, phase timing; keep reuse/cache opt-in. Reject persistent worker with report-case recording to avoid mixing cases across tests.
- #10 research: preserve full research document and link from current roadmap rather than replacing roadmap with stale version.
- #17: exact Viewer head 65ca738722147c26b62b006bc35805614929da51 included as second parent; use its tree plus 12 non-overlapping compatibility/performance files and review docs. No changes to viewer implementation or reference application behavior in consolidation.

Baseline: foundation and Viewer independently 18/19 workflows passed, known Fizzy failure. Old performance stack 16/17 passed; not proof of integrated correctness. Full CI required on the new branch; no bypass of failing tests. Petstore #1 currently pins old performance head dd735a4, #2 has Selenium Chrome startup errors in its own CI despite successful canonical acceptance reference. Keep Petstore PRs unchanged until consolidated candidate is proven, then update dependency pin and validate Selenium and Domstride against same checkout. Core Extraction & Packaging follows consolidation; not part of this review.

Final approval gates: inspect combined diff, verify all applicable CI, compare Fizzy errors against baseline, run Petstore parity and paired opt-in benchmarks on consolidated pin, confirm no new supported-engine regressions, review any unresolved privacy/protocol limitations. No release or merge to main before approval.
