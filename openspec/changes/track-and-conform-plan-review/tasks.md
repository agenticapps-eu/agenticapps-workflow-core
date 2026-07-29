## 1. Repair §18's contradiction

- [ ] 1.1 Correct `spec/18-retargeted-change-gate.md` line 146 ("the ≥2-reviewer requirement") to the one-reviewer floor
- [ ] 1.2 Correct line 174 ("`REVIEWS.md` ≥ 2 reviewers for edits under an active change") to ≥ 1
- [ ] 1.3 Add to §18: a reviewer section counts only if it carries a parseable verdict
- [ ] 1.4 Add to §18: the host's own vendor never counts toward the floor, and duplicate vendors count once
- [ ] 1.5 Grep §18 and the other 18 spec sections for any remaining ≥2 reviewer claim, so no third copy survives
- [ ] 1.6 Bump the spec version and record the change in `CHANGELOG.md`

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

- [ ] 7.1 Document in the README and capability what is transmitted, to which vendors, and that invocation is consent
- [ ] 7.2 `tdd="true"` — failing test: the review prompt must not appear in the process table
- [ ] 7.3 `tdd="true"` — pass the prompt by file rather than process argument; make the test pass
- [ ] 7.4 Record the deferred secret/PII screening as a named follow-up so the gap stays visible

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

## 10. Verify and record

- [ ] 10.1 Run `openspec validate --all` green
- [ ] 10.2 Run `openspec-change-gate.sh --ci` green
- [ ] 10.3 Stage-2 independent code review per §07
- [ ] 10.4 Write the ADR: why the installed copy was promoted over the in-repo ancestor, the floor-vs-preference distinction, and why the spec edit belonged in this change
