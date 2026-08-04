## 1. Review before any edit

- [ ] 1.1 Confirm `openspec validate --all` is green with the delta in place
- [ ] 1.2 Run `~/.agenticapps/bin/run-plan-review.sh
      repair-currency-axis-table-and-fold-tear --implementing-host claude` and land
      `REVIEWS.md` with two or more independent other-vendor reviewers. The runner
      is **not** on the repo PATH and exits without `--implementing-host`.
- [ ] 1.3 Read the reviewers on one question specifically: is narrowing the table
      the right side of the contradiction to fix, or does the majority-plus-code
      argument hide a reason the table was right?

## 2. Apply the delta to the spec slot

- [ ] 2.1 Apply the delta so the axes table's `stale` clause reads
      "a declared, present artifact"
- [ ] 2.2 Apply the delta so the torn paragraph is whole inside
      *A machine's provisioning is a triple, not a state name*
- [ ] 2.3 Apply the delta so the orphaned fragment is gone from
      *Currency is judged against an authority checkout*
- [ ] 2.4 Confirm no other line of either requirement changed — diff the applied
      spec against `main` and enumerate exactly these three hunks, by name rather
      than by count:
      (a) the Currency cell, `a declared artifact` → `a declared, present artifact`;
      (b) +3 lines rejoining the torn sentence in *A machine's provisioning is a triple*;
      (c) −3 lines and one blank removing the orphan from *Currency is judged
      against an authority checkout*

## 3. Verify placement, not survival

- [ ] 3.1 Commit `tools/spec-placement.test.sh` and confirm it is RED **before**
      the repair, failing on all three symptoms: the stranded opener at 927, the
      severed tail at 861, and the unscoped `stale` clause
- [ ] 3.2 Wire it into `.github/workflows/openspec-gate.yml` beside the other
      conformance tests, so the next fold is guarded rather than this one only
- [ ] 3.3 Confirm it is GREEN after the repair, and green across all five specs
- [ ] 3.4 Confirm the fold left correct blank-line separation between the second
      modified requirement and the requirement that follows it — the delta
      rstrips trailing blanks, and separator loss would silently merge headings
- [ ] 3.5 Confirm `tools/provisioning-check.sh` is unchanged — the code is this
      change's evidence, not its target

## 4. Review, archive, ship

- [ ] 4.1 Request an independent Stage-2 review in a cleared session
- [ ] 4.2 `openspec archive repair-currency-axis-table-and-fold-tear -y`
- [ ] 4.3 Re-run task 3.1 and 3.3 **after** the archive fold — the fold is what
      caused the defect being repaired, so verifying only before it would check
      the wrong moment
- [ ] 4.4 Open the PR, linking the change directory and the placement evidence
