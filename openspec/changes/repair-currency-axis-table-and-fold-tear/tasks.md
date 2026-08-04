## 1. Review before any edit

- [ ] 1.1 Confirm `openspec validate --all` is green with the delta in place
- [ ] 1.2 Run `~/.agenticapps/bin/run-plan-review.sh
      repair-currency-axis-table-and-fold-tear --implementing-host claude` and land
      `REVIEWS.md` with two or more independent other-vendor reviewers. The runner
      is **not** on the repo PATH and exits without `--implementing-host`.
- [ ] 1.3 Read the reviewers on one question specifically: is narrowing the table
      the right side of the contradiction to fix, or does the majority-plus-code
      argument hide a reason the table was right?

## 2. Land the guard, RED

The canonical spec is repaired by the archive fold in §4, not by hand here.
`tools/spec-placement.test.sh` reads `openspec/specs/`, so it is **expected RED
from this point until 4.2 folds the delta**. That is the RED half of the pair,
not a broken build — CI on this branch is red by design until the fold.

- [ ] 2.1 Commit `tools/spec-placement.test.sh` and confirm it is RED against the
      unrepaired spec, failing on all three symptoms: the stranded opener at 927,
      the severed tail at 861, and the unscoped `stale` clause
- [ ] 2.2 Confirm each symptom fails for its own reason — in particular that the
      severed-tail signature fires on 861 on its own, rather than the run going
      RED only because the stranded-opener signature caught 927
- [ ] 2.3 Wire it into `.github/workflows/openspec-gate.yml` beside the other
      conformance tests, so the next fold is guarded rather than this one only
- [ ] 2.4 Confirm the four other specs already pass, so the glob adds a guard
      rather than a backlog

## 3. Independent code review

- [ ] 3.1 Request an independent code review in a **cleared session** — the
      Stage-3 execute gate, the second of the two reviews. Distinct from §1,
      which reviewed the plan before code existed. `openspec validate` is a
      spec check and does not discharge it.
- [ ] 3.2 Confirm `tools/provisioning-check.sh` is unchanged — the code is this
      change's evidence, not its target

## 4. Archive, which is what repairs the spec

- [ ] 4.1 Re-confirm `openspec validate --all` is green immediately before the fold
- [ ] 4.2 `openspec archive repair-currency-axis-table-and-fold-tear -y` — this is
      the step that folds both repairs into
      `openspec/specs/project-hook-binding/spec.md`
- [ ] 4.3 Diff the folded spec against `main` and enumerate exactly these three
      hunks, by name rather than by count:
      (a) the Currency cell, `a declared artifact` → `a declared, present artifact`;
      (b) +3 lines rejoining the torn sentence in *A machine's provisioning is a triple*;
      (c) −3 lines and one blank removing the orphan from *Currency is judged
      against an authority checkout*
- [ ] 4.4 Confirm the fold left correct blank-line separation between the second
      modified requirement and the requirement that follows it — the delta
      rstrips trailing blanks, and separator loss would silently merge headings

## 5. Verify GREEN after the fold, then ship

The fold is the operation that caused the defect being repaired. Verifying only
before it would check the wrong moment.

- [ ] 5.1 Run `bash tools/spec-placement.test.sh` **after** the archive fold and
      confirm GREEN across all five specs
- [ ] 5.2 Confirm the restored sentence is contiguous *and* inside *A machine's
      provisioning is a triple* in the folded canonical spec — placement, not
      survival
- [ ] 5.3 Open the PR, linking the change directory, `REVIEW-RESPONSE.md`, and the
      before/after placement evidence
