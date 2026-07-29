## 1. Establish the tracked source

- [ ] 1.1 Create `reference-implementations/run-plan-review/` and seed `run-plan-review.sh` byte-identically from `~/.agenticapps/bin/run-plan-review.sh` (227 lines, marker 1.0.0)
- [ ] 1.2 Verify the seeded copy is byte-identical to the installed one before any edit, so the baseline is provably the running implementation
- [ ] 1.3 Write the README covering purpose, the install contract, the version-marker rule, and the relationship to `reviewer-cli.sh`
- [ ] 1.4 Confirm the directory layout matches the sibling artifacts (`openspec-change-gate/`, `reviewer-cli/`, `shared-install/`)

## 2. Conform the floor

- [ ] 2.1 `tdd="true"` — write a failing test: one reviewer returns, two time out, and `REVIEWS.md` must be written with the one review
- [ ] 2.2 `tdd="true"` — change the `MIN_REVIEWERS` default from 2 to 1 and make the test pass
- [ ] 2.3 Add a test that an explicitly set higher floor is still honoured
- [ ] 2.4 Add a test that zero successful reviewers still writes nothing and exits non-zero
- [ ] 2.5 Confirm the sanitiser, `## Reviewer:` forge guard, and 3/4/5 exit-code reporting are unmodified by diffing against the 1.2 baseline

## 3. Report partial results

- [ ] 3.1 `tdd="true"` — write a failing test that a run meeting the floor names each vendor that failed, with its reason
- [ ] 3.2 `tdd="true"` — implement the reporting change and make the test pass
- [ ] 3.3 Verify a fully successful run's output is unchanged

## 4. Publish

- [ ] 4.1 Bump the version marker to 1.1.0 with a changelog note in the file header, following the existing marker convention
- [ ] 4.2 Publish to `~/.agenticapps/bin/` via the existing install path
- [ ] 4.3 Verify the installed copy reports 1.1.0 and that the arbiter refuses a simulated older-version overwrite
- [ ] 4.4 Reproduce the 2026-07-29 failure end-to-end: request three vendors with a short timeout, confirm a single survivor now yields a written `REVIEWS.md`

## 5. Retire the ancestor

- [ ] 5.1 Confirm nothing references `gate/run-plan-review.sh` — grep core, the four hosts, and the seven projects
- [ ] 5.2 Delete `gate/run-plan-review.sh`
- [ ] 5.3 Record in the handoff that `gate/`'s remaining contents are still unclassified, so the open question is not silently closed

## 6. Verify and record

- [ ] 6.1 Run `openspec validate --all` green
- [ ] 6.2 Run `openspec-change-gate.sh --ci` green
- [ ] 6.3 Stage-2 independent code review per §07
- [ ] 6.4 Write the ADR covering why the installed copy was promoted over the in-repo ancestor, and the floor-vs-preference distinction
