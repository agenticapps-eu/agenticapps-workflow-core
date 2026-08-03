## 1. Author the delta

- [x] 1.1 Capture a pre-change baseline before touching anything. Recorded: 116
  normative sentences, 67 scenarios, 15 requirements; spec md5
  `914aa34739d5cfd9fd4006f1bd2d0ac0`.
- [x] 1.2 Build the delta by **slicing exact line ranges** from the current spec,
  never by retyping.
- [x] 1.3 Establish the encoding empirically by probing `openspec archive` and
  resetting. Three constraints found: `MODIFIED` cannot shed scenarios; a
  requirement may not be in both `ADDED` and `REMOVED` (so the rename is forced);
  `ADDED` requirements are appended at end-of-file.
- [x] 1.4 Re-encode as `REMOVED` + three `ADDED` + one `MODIFIED`.
- [x] 1.5 `openspec validate ... --type change` — green.

## 2. Prove the delta is content-preserving

- [x] 2.1 Line-level multiset diff, region 605–1124 vs delta. **Lines lost MUST
  be empty.** Result: empty. (Region ends at 1124, not 1085, because the
  per-machine requirement is also modified — see design.)
- [x] 2.2 Lines gained MUST be exactly 26: 3 delta section headers + 3 new
  requirement headings + 1 lead-in + 19 lines of REMOVED `Reason`/`Migration`
  metadata that never enters the spec. Result: 26.
- [x] 2.3 Scenario inventory identical. Result: 18 = 18, `diff` clean.
- [x] 2.4 All three axes-table rows present verbatim. Result: 3.
- [x] 2.5 Defect found and fixed by 2.1: the first build sliced the last currency
  scenario to 1084 instead of 1085, dropping one line.
- [x] 2.6 Every requirement has ≥1 scenario (6 / 2 / 8 / 2); no malformed
  3-hashtag scenarios; the nested `Currency is judged over ... PRESENT` block
  kept its two-space indentation, which a trimmed-line diff cannot see.

## 3. Review before code

- [x] 3.1 `run-plan-review.sh place-provisioning-requirements --implementing-host
  claude` — 3 other-vendor reviewers (gemini APPROVE, codex REQUEST-CHANGES,
  opencode REQUEST-CHANGES). `claude` excluded as implementing host.
- [x] 3.2 Every objection dispositioned in `REVIEW-RESPONSE.md`: 9 accepted and
  fixed, 2 rejected on verified grounds, 1 partially accepted.

## 4. Apply and reorder

- [ ] 4.1 `openspec archive place-provisioning-requirements -y` to fold the delta.
- [ ] 4.2 Run `tools/reorder-requirements.py` on the applied spec — moves whole
  blocks by heading name, refuses if the line multiset changes, idempotent.
- [ ] 4.3 `tools/reorder-requirements.py --check` confirms the final order.
- [ ] 4.4 Verify **all three** cross-boundary references, not just the first:
  - `"per the state table above"` — cited in (4), table in (2). Must be upward.
  - `"per the `stale` invariant below"` — cited in (2), invariant in (3). Downward.
  - `"contradicting the `stale` invariant above"` — cited in the last
    requirement, invariant in (3). Upward.

## 5. Prove the applied spec is content-preserving

- [ ] 5.1 Re-run the line-level multiset diff against the **reordered spec**. A
  reorder that drops a line fails exactly like a move that does.
- [ ] 5.2 Whole-file counts: 116 normative sentences, 67 scenarios, **17**
  requirements, three axes rows.
- [ ] 5.3 **Per-requirement** check, because totals cannot detect content filed
  under the wrong heading: scenario inventory per requirement is 6 / 2 / 8 / 2,
  and each requirement contains its defining marker — the axes table ONLY under
  the triple, the `complete`+`attested`+`current` licence ONLY under currency,
  the non-blocking exit-code rule ONLY under the shim requirement.
- [ ] 5.4 `openspec validate --all` green.
- [ ] 5.5 `git diff --stat` shows exactly one file changed under `openspec/specs/`.

## 6. Verify nothing outside the spec moved

- [ ] 6.1 Project-hook suites still green (243 assertions at last run).
- [ ] 6.2 `project-hook-conformance.sh` still passes.
- [ ] 6.3 `bash ~/.agenticapps/bin/openspec-change-gate.sh --ci` clean.
- [ ] 6.4 Confirm no **executable** consumer references the removed requirement
  name. `session-handoff.md` and the archived `check-implementation-currency`
  change do cite it and are deliberately left alone as historical records — this
  task asserts the absence of a *dangling* reference, not of every mention.

## 7. Independent review, then ship

- [ ] 7.1 `superpowers:requesting-code-review` in an independent context.
- [ ] 7.2 `superpowers:finishing-a-development-branch` — PR.
