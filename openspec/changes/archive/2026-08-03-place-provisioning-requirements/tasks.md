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

- [x] 4.1 `openspec archive place-provisioning-requirements -y` to fold the delta.
- [x] 4.2 Run `tools/reorder-requirements.py` on the applied spec — moves whole
  blocks by heading name, refuses if the line multiset changes, idempotent.
- [x] 4.3 `tools/reorder-requirements.py --check` confirms the final order.
- [x] 4.4 Verify **all three** cross-boundary references, not just the first:
  - `"per the state table above"` — cited in (4), table in (2). Must be upward.
  - `"per the `stale` invariant below"` — cited in (2), invariant in (3). Downward.
  - `"contradicting the `stale` invariant above"` — cited in the last
    requirement, invariant in (3). Upward.

## 5. Prove the applied spec is content-preserving

- [x] 5.1 Re-run the line-level multiset diff against the **reordered spec**. A
  reorder that drops a line fails exactly like a move that does.
- [x] 5.2 Whole-file counts: 116 normative sentences, 67 scenarios, **17**
  requirements, three axes rows.
- [x] 5.3 **Per-requirement** check, because totals cannot detect content filed
  under the wrong heading: scenario inventory per requirement is 6 / 2 / 8 / 2,
  and each requirement contains its defining marker — the axes table ONLY under
  the triple, the `complete`+`attested`+`current` licence ONLY under currency,
  the non-blocking exit-code rule ONLY under the shim requirement.
- [x] 5.4 `openspec validate --all` green.
- [x] 5.5 `git diff --stat` shows exactly one file changed under `openspec/specs/`.

## 6. Verify nothing outside the spec moved

- [x] 6.1 Project-hook suites still green (243 assertions at last run).
- [x] 6.2 `project-hook-conformance.sh` still passes.
- [x] 6.3 `bash ~/.agenticapps/bin/openspec-change-gate.sh --ci` clean.
- [x] 6.4 Confirm no **executable** consumer references the removed requirement
  name. `session-handoff.md` and the archived `check-implementation-currency`
  change do cite it and are deliberately left alone as historical records — this
  task asserts the absence of a *dangling* reference, not of every mention.

## 7. Independent review, then ship

- [ ] 7.1 `superpowers:requesting-code-review` in an independent context.
- [ ] 7.2 `superpowers:finishing-a-development-branch` — PR.

## Verification results (measured, not asserted)

- **4.2/4.3** reorder applied and re-checked: `A project binds a hook through a
  shim` → `A shim that resolves no implementation…` → `A machine's provisioning
  is a triple` → `Currency is judged against an authority checkout` →
  `Provisioning is checked per machine` (lines 320 / 605 / 817 / 905 / 1087).
- **4.4** all three cross-references hold: axes table 839 cited from 1087
  (upward); `stale` invariant 957 cited from 856 (downward) and from 1613
  (upward).
- **5.1** whole-file line multiset: **1 line lost** — the old requirement heading
  — and **4 gained** — the three new headings plus the lead-in. The
  `Reason`/`Migration` metadata correctly did **not** enter the spec.
- **5.2** 116 normative sentences, 67 scenarios, 17 requirements, 3 axes rows —
  all equal to baseline except requirements 15 → 17.
- **5.3** per-requirement scenarios **6 / 2 / 8 / 2**; axes table, the licence and
  the exit-code rule each appear under exactly one requirement, the correct one.
- **6.1** 7 suites: **297 passed, 0 failed, 5 skipped** (provisioning 109, shim
  46, conformance 43, project-hooks 34, harness 36, drift 18, normalize 11).
- **6.2** conformance findings **33 before, 33 after** — measured by stashing the
  spec change and re-running, not inferred.
- **6.3** gate `--ci` exit 0. **6.4** no executable consumer cites the old name.

### A measurement bug found in the verification itself

The normative-sentence check initially reported 6 lost / 6 gained pairs whose
text was visibly identical. Cause: the files were sorted by Python (codepoint
order) but compared with `comm`, which assumes the shell locale's collation.
Mismatched orders produce spurious differences. Re-run under `LC_ALL=C`, five of
six resolved.

The sixth is a genuine limitation of that check, not a defect in the spec:
scenario bullets carry no terminating period, so the extractor glues consecutive
scenarios into one run-on string. Splitting the requirement inserts headings that
interrupt the run-on, so the currency tail becomes its own shorter string — the
"gained" text is literally a **suffix** of the "lost" text. Both scenarios exist
exactly once in the final spec.

**The line-level multiset diff is the authoritative check**; the sentence-level
one is a weaker cross-check with known join artifacts. Recorded so a later reader
does not re-derive this the hard way.
