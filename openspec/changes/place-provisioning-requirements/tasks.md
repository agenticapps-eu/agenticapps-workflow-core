## 1. Author the delta

- [x] 1.1 Capture a pre-change baseline before touching anything: normative
  sentences, scenario inventory, axes-table rows, spec md5. Recorded: 116
  normative sentences, 67 scenarios, 15 requirements across the capability;
  md5 `914aa34739d5cfd9fd4006f1bd2d0ac0`.
- [x] 1.2 Build `specs/project-hook-binding/spec.md` by **slicing exact line
  ranges** from the current spec, never by retyping. Four requirement blocks:
  two MODIFIED (shim, per-machine), two ADDED (triple, currency).
- [x] 1.3 `openspec validate place-provisioning-requirements --type change` — green.

## 2. Prove the move is content-preserving

- [x] 2.1 Line-level multiset diff, original region (605–1124) vs delta.
  **Lines lost MUST be empty.** Result: empty.
- [x] 2.2 Lines gained MUST be exactly five: `## MODIFIED Requirements`,
  `## ADDED Requirements`, the two new `### Requirement:` headings, and the
  non-normative lead-in `Invariants on the currency axis:`. Result: exactly those five.
- [x] 2.3 Scenario inventory identical before and after. Result: 18 = 18, `diff` clean.
- [x] 2.4 All three axes-table rows present verbatim in the delta. Result: 3.
- [x] 2.5 Defect found and fixed by 2.1: the first build sliced the last currency
  scenario to 1084 instead of 1085, dropping one line. Re-verified after fix.

## 3. Checks that the sentence-level diff cannot make

- [ ] 3.1 Confirm the new requirement order places the state-model requirement
  **above** "Provisioning is checked per machine", so its existing phrase
  *"computed observationally per the state table above"* stays true.
- [ ] 3.2 Confirm no requirement ended up with zero scenarios (OpenSpec fails
  silently on 3-hashtag scenarios; count per requirement, do not eyeball).
- [ ] 3.3 Confirm the moved `**Currency is judged over the declared artifacts
  that are PRESENT.**` block kept its nesting under the `unknown` bullet —
  indentation is semantic here and a multiset diff of trimmed lines cannot see it.

## 4. Review before code

- [ ] 4.1 `run-plan-review.sh place-provisioning-requirements` — two or more
  independent other-vendor reviewers, writing `REVIEWS.md`. Not enforced by the
  gate since 2.0.0; run it anyway.
- [ ] 4.2 Address or record a reason against every objection raised.

## 5. Apply

- [ ] 5.1 `/opsx:apply` — fold the delta into
  `openspec/specs/project-hook-binding/spec.md`.
- [ ] 5.2 Re-run the whole-file checks against the **applied spec**, not the
  delta: 116 normative sentences, 67 scenarios, 17 requirements (15 + 2), three
  axes rows.
- [ ] 5.3 `openspec validate --all` green.

## 6. Verify nothing else moved

- [ ] 6.1 `git diff --stat` shows exactly one file changed under
  `openspec/specs/`.
- [ ] 6.2 Project-hook suites still green (243 assertions at last run).
- [ ] 6.3 `bash ~/.agenticapps/bin/openspec-change-gate.sh --ci` clean.
- [ ] 6.4 `project-hook-conformance.sh` still passes — it implements the state
  model and must be unaffected by a heading move.

## 7. Independent code review, then archive and ship

- [ ] 7.1 `superpowers:requesting-code-review` in an independent context.
  `openspec validate` does not discharge this.
- [ ] 7.2 `/opsx:archive`.
- [ ] 7.3 `superpowers:finishing-a-development-branch` — PR. Archive and ship are
  two separate acts.
