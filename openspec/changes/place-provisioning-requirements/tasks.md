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
- [x] 1.4 Re-encode as `REMOVED` + three `ADDED` + one `MODIFIED`, with
  `Reason`/`Migration` on the removal.
- [x] 1.5 `openspec validate place-provisioning-requirements --type change` — green.

## 2. Prove the delta is content-preserving

- [x] 2.1 Line-level multiset diff, original region (605–1124) vs delta.
  **Lines lost MUST be empty.** Result: empty.
- [x] 2.2 Lines gained are structural only — delta headers, the three new
  requirement headings, the `Reason`/`Migration` metadata (which never lands in
  the spec), and the non-normative lead-in `Invariants on the currency axis:`.
- [x] 2.3 Scenario inventory identical. Result: 18 = 18, `diff` clean.
- [x] 2.4 All three axes-table rows present verbatim. Result: 3.
- [x] 2.5 Defect found and fixed by 2.1: the first build sliced the last currency
  scenario to 1084 instead of 1085, dropping one line.
- [x] 2.6 Every requirement has ≥1 scenario (6 / 2 / 2 / 8); no malformed
  3-hashtag scenarios; the nested `Currency is judged over ... PRESENT` block
  kept its two-space indentation, which a trimmed-line diff cannot see.

## 3. Review before code

- [ ] 3.1 `run-plan-review.sh place-provisioning-requirements` — two or more
  independent other-vendor reviewers, writing `REVIEWS.md`. Not enforced by the
  gate since 2.0.0; run it anyway.
- [ ] 3.2 Address every objection or record a reason against it.

## 4. Apply and reorder

- [ ] 4.1 `openspec archive place-provisioning-requirements -y` to fold the delta.
- [ ] 4.2 **Reorder by hand**: move the three new requirement blocks from
  end-of-file into positions 5–7, so the order is `A project binds a hook through
  a shim` → `A shim that resolves no implementation…` → `A machine's provisioning
  is a triple` → `Currency is judged against an authority checkout` →
  `Provisioning is checked per machine`.
- [ ] 4.3 Confirm `"computed observationally per the state table above"` is true
  of the reordered file — the table's requirement must precede the one citing it.

## 5. Prove the applied spec is content-preserving

- [ ] 5.1 Re-run the line-level multiset diff against the **reordered spec**, not
  the delta. A reorder that drops a line fails exactly like a move that does.
- [ ] 5.2 Whole-file counts: 116 normative sentences, 67 scenarios, **17**
  requirements (15 + 3 added − 1 removed), three axes rows.
- [ ] 5.3 `openspec validate --all` green.
- [ ] 5.4 `git diff --stat` shows exactly one file changed under `openspec/specs/`.

## 6. Verify nothing outside the spec moved

- [ ] 6.1 Project-hook suites still green (243 assertions at last run).
- [ ] 6.2 `project-hook-conformance.sh` still passes — it implements the state
  model and must be unaffected by a heading move.
- [ ] 6.3 `bash ~/.agenticapps/bin/openspec-change-gate.sh --ci` clean.
- [ ] 6.4 Confirm no file outside `openspec/` references the removed requirement
  name (re-run the search that justified "no consumer reads headings").

## 7. Independent review, then ship

- [ ] 7.1 `superpowers:requesting-code-review` in an independent context.
  `openspec validate` does not discharge it.
- [ ] 7.2 `superpowers:finishing-a-development-branch` — PR. Archive and ship are
  two separate acts; the archive happens at 4.1.
