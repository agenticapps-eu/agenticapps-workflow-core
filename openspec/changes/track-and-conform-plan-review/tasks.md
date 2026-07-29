## 1. Repair and extend §18

- [ ] 1.1 Correct `spec/18-retargeted-change-gate.md` line 146 ("the ≥2-reviewer requirement") to the one-reviewer floor
- [ ] 1.2 Correct line 174 ("`REVIEWS.md` ≥ 2 reviewers for edits under an active change") to ≥ 1
- [ ] 1.3 Add a **verdict term to the truth table** — required before the gate may count on verdicts, since the gate's source records that blocking on a verdict is non-conformant while the table lacks one
- [ ] 1.4 Specify the verdict format exactly: line-anchored, case-insensitive, optional markdown emphasis, closed vocabulary — matching the parser `pending_rejections()` already ships
- [ ] 1.5 Add: the host's own vendor never counts, duplicates count once, and host identity is a required caller input with fail-closed behaviour when absent
- [ ] 1.6 Add: a review is bound to a digest of the artifacts reviewed, and a stale review does not count
- [ ] 1.7 Grep §18 and the other 18 spec sections for any remaining ≥2 reviewer claim, so no third copy survives
- [ ] 1.8 Bump the spec version and record the change in `CHANGELOG.md`

## 2. Establish the tracked source

- [ ] 2.1 Create `reference-implementations/run-plan-review/` and seed `run-plan-review.sh` byte-identically from `~/.agenticapps/bin/run-plan-review.sh` (227 lines, marker 1.0.0)
- [ ] 2.2 Verify byte-identity against the installed copy before any edit, so the baseline is provably the running implementation
- [ ] 2.3 Write the README: purpose, install contract, version-marker rule, relationship to `reviewer-cli.sh`, and the egress boundary
- [ ] 2.4 Confirm the layout matches the sibling artifacts (`openspec-change-gate/`, `reviewer-cli/`, `shared-install/`)

## 3. Conform the floor

- [ ] 3.1 `tdd="true"` — failing test: one reviewer returns, two time out, `REVIEWS.md` must be written with the one review
- [ ] 3.2 `tdd="true"` — change the `MIN_REVIEWERS` default from 2 to 1 and make the test pass
- [ ] 3.3 `tdd="true"` — failing test: `MIN_REVIEWERS=0` must exit with a usage error and write nothing
- [ ] 3.4 `tdd="true"` — reject 0, negatives and non-integers; make the test pass
- [ ] 3.5 Test that an explicitly set higher floor is still honoured
- [ ] 3.6 Test that zero successful reviewers still writes nothing and exits non-zero

## 4. Count only real reviews

- [ ] 4.1 `tdd="true"` — failing test: a vendor returning prose with no verdict must not count, and must be reported as failed with reason "no verdict"
- [ ] 4.2 `tdd="true"` — implement verdict parsing as the counting predicate; make the test pass
- [ ] 4.3 Test that a REQUEST-CHANGES verdict does count toward the floor
- [ ] 4.4 Regression-test the exact opencode output from this change's own review, which counted while carrying no verdict

## 5. Enforce independence structurally

- [ ] 5.1 `tdd="true"` — failing test: the running host's own vendor does not count and is recorded as excluded
- [ ] 5.2 `tdd="true"` — determine the running host by rule rather than the environment default; make the test pass
- [ ] 5.3 `tdd="true"` — failing test: the same vendor named twice contributes at most one
- [ ] 5.4 Test self-exclusion on a simulated non-`claude` host

## 6. Make REVIEWS.md self-contained

- [ ] 6.1 `tdd="true"` — failing test: `REVIEWS.md` records requested, counted, excluded and failed vendors with reasons
- [ ] 6.2 `tdd="true"` — implement the record block; make the test pass
- [ ] 6.3 Test that a failure reason distinguishes timeout, non-zero exit, and no-verdict
- [ ] 6.4 Confirm the record survives the existing stdout sanitiser and does not trip the `## Reviewer:` forge guard

## 7. Declare the egress boundary

- [ ] 7.1 Document in the README and capability what is transmitted and to which vendors
- [ ] 7.2 Confirm the producer already passes a file to the wrapper — the argv exposure is the wrapper's and is fixed in 9c, not here

## 8. Publish

- [ ] 8.1 Confirm the sanitiser, forge guard, and 3/4/5 exit-code reporting are unmodified by diffing against the 2.2 baseline
- [ ] 8.2 Bump the version marker to 1.1.0 with a header changelog note, following the existing marker convention
- [ ] 8.3 Add the `resolve-core-artifact.sh` mapping for `bin/run-plan-review.sh`
- [ ] 8.4 Point the Claude installer at core rather than its vendored 1.0.0 copy, so core is the operational source of truth
- [ ] 8.5 Publish to `~/.agenticapps/bin/`; verify it reports 1.1.0 and that the arbiter refuses a simulated older-version overwrite
- [ ] 8.6 Reproduce the 2026-07-29 failure end-to-end: three vendors, short timeout, single survivor now yields a written `REVIEWS.md`

## 9. Retire the ancestor

- [ ] 9.1 Confirm nothing references `gate/run-plan-review.sh` — grep core, the four hosts, and the seven projects
- [ ] 9.2 Delete `gate/run-plan-review.sh`
- [ ] 9.3 Record in the handoff that `gate/`'s remaining contents are still unclassified, so the open question is not silently closed

## 9b. Harden the gate (openspec-change-gate.sh 1.4.0 → 1.5.0)

- [ ] 9b.1 `tdd="true"` — failing test: a `REVIEWS.md` section with a heading and no verdict must not count toward the floor
- [ ] 9b.2 `tdd="true"` — make `reviewer_count()` use the same verdict predicate as `pending_rejections()`; make the test pass
- [ ] 9b.3 Verify both functions still skip fenced blocks and still apply self-exclusion, per the existing comments
- [ ] 9b.4 Regression-test the real opencode section from this change's own review, which counted while carrying no verdict
- [ ] 9b.5 `tdd="true"` — failing test: with no authoritative host identity supplied, the gate counts zero reviewers and blocks
- [ ] 9b.6 `tdd="true"` — remove the `claude` default; require the identity from the caller; make the test pass
- [ ] 9b.7 Update each host's gate shim to supply its own identity authoritatively
- [ ] 9b.8 `tdd="true"` — failing test: a change amended after review is detected as stale and does not count
- [ ] 9b.9 `tdd="true"` — implement digest recording and verification; make the test pass
- [ ] 9b.10 `tdd="true"` — failing test: a `REVIEWS.md` with no digest is reported unverifiable and does not count
- [ ] 9b.11 Confirm existing well-formed `REVIEWS.md` files with verdicts still count, so the change does not invalidate good evidence
- [ ] 9b.12 Bump to 1.5.0, run the 52-case change-gate harness green, and publish
- [ ] 9b.13 Re-verify this branch's own two changes under 1.5.0 — both were amended after review and MUST now read as stale

## 9c. Fix the wrapper's process-table exposure (reviewer-cli.sh 1.1.0 → 1.2.0)

- [ ] 9c.1 `tdd="true"` — failing test: the prompt must not appear in the process table for any of the four vendor arms
- [ ] 9c.2 `tdd="true"` — pass the prompt via stdin or a file path instead of `"$prompt"` as argv; make the test pass for all four arms
- [ ] 9c.3 Verify `codex exec` still works — its arm carries a pin because it hangs reading stdin (pilot friction #3); confirm the replacement does not reintroduce that hang
- [ ] 9c.4 Confirm the 3/4/5 exit-code contract and the timeout wrapper are unchanged
- [ ] 9c.5 Bump to 1.2.0, publish, and confirm the arbiter refuses an older overwrite

## 9d. Correct the egress documentation

- [ ] 9d.1 Document that vendor CLIs are agentic and can read files beyond the prompt — the boundary is the repository, not the prompt
- [ ] 9d.2 Document reviewer output as untrusted third-party input that is written to `REVIEWS.md` and read back by agents
- [ ] 9d.3 Record deferred secret/PII screening as a named follow-up change

## 10. Verify and record

- [ ] 10.1 Run `openspec validate --all` green
- [ ] 10.2 Run `openspec-change-gate.sh --ci` green
- [ ] 10.3 Stage-2 independent code review per §07
- [ ] 10.4 Write the ADR: why the installed copy was promoted over the in-repo ancestor, the floor-vs-preference distinction, and why the spec edit belonged in this change
