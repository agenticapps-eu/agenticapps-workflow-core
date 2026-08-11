# Session Handoff — 2026-08-11 (twenty-ninth session)

`floor-check-mode` is **implemented, reviewed, verified and shipped as PR #112**
(branch `floor-check-mode`, gate CI green). It is **not archived** — that is the
first action next session, after the PR merges.

## Accomplished

- **`--check` on `bind-global-floor.sh`**, the requirement `one-enforcement-floor`
  specified and never built. Reports the machine, core, and one section per named
  repository; writes nothing; exits 0 whatever it finds.
- **Grammar: `--check [repository ...]`**, no repository meaning the cwd's. No
  scan, no declared root, no walk.
- **Suite 79 → 139**, GREEN twice, every new assertion observed RED first.
  `shellcheck -S warning` clean on everything added.
- **Step 2b run properly**: gemini and codex, both REQUEST-CHANGES, both finding
  the same HIGH independently. Step 4: codex on the diff, REQUEST-CHANGES, six
  findings. `REVIEWS.md` carries both rounds and every resolution.
- **`--project` dropped** from the two places in `docs/HOW-IT-FITS-TOGETHER.md`
  that named it — and they contradicted each other.
- **The fleet re-measured with the mode itself.**

## Decisions

- **Positional repositories, not a scan.** Both plan reviewers wanted a census
  mechanism (a `--scan` root, a declared root). Neither was taken: the binder's
  own text says the migration set is *named, never discovered*, and a mode that
  only inspects has no better claim to walk the machine than the mode that
  mutates.
- **The mode goes before the `mkdir -p`.** Measured, not assumed: the old binder
  created `~/.agenticapps/git-hooks` on its way to refusing `--check`.
- **`FLOOR_VOUCHED` is separate from `FLOOR_ACTIVE`.** A hand-edited dispatcher
  is perfectly runnable, so "git runs the floor" and "the floor is this
  checkout's gate" are two claims. Collapsing them would have dragged `ahead`
  in — the false alarm the plan review warned about.
- **The review trailer is NOT forged.** Its digest asserts which artifacts the
  reviewers saw; both reviews are of the pre-resolution delta. `trailer-absent`
  is the honest state. Recorded as a skill/gate divergence instead.
- **Not archived in the implementation PR**, matching `#107 → #108`: archiving
  first would put the requirements into the live spec while `main` has no
  implementation.
- **Task 4.3 inverted.** It said to bump `global-floor-version` and publish; that
  marker is on the *dispatcher* (1.1.0, byte-unchanged), the binder carries no
  marker and is not published. Bumping it would have told every machine its
  correct dispatcher was stale.

## Files modified

`reference-implementations/global-floor/bind-global-floor.sh` (+393, the whole
`--check` block, inserted before the mkdir) · `tools/global-floor-bind.test.sh`
(+826, 60 new assertions) · `openspec/changes/floor-check-mode/specs/*` (both
deltas rewritten after review) · `openspec/changes/floor-check-mode/tasks.md`
(all 4.x closed, 2.10–2.13 added) · `openspec/changes/floor-check-mode/REVIEWS.md`
(new) · `docs/HOW-IT-FITS-TOGETHER.md` (`--project` removed, two places).

## Next session: start here

**Merge #112, then archive.** `openspec archive floor-check-mode` folds both
deltas into `openspec/specs/`. The `core-self-enforcement` delta is a MODIFIED
block that **restates the live requirement verbatim and appends** — verified as a
pure superset (3 original scenarios preserved, 4 added), so the archive should
not refuse the way `two-real-instruction-files` did three times. Archive in its
own PR, as `#108` was. Nothing needs publishing: the binder runs from the
checkout and carries no version marker.

**Then decide what to do about the two ungated repositories the mode found.**
`codex-workflow` and `opencode-workflow` each carry a `.git/hooks/pre-commit`
(5.8K and 2.3K, 25 July) that the global binding displaced, and neither is
enrolled — so both are completely ungated: hook on disk, nothing running it, no
marker. They are host repositories scheduled for deletion, so this was recorded
and not repaired. If deletion slips, they are the two repositories on the machine
with no enforcement at all.

## Open questions

1. **The `openspec-change-review` skill and the gate disagree about REVIEWS.md.**
   The skill documents YAML frontmatter; the gate parses an
   `<!-- openspec-review-trailer -->` block only `run-plan-review.sh` emits. Every
   hand-written REVIEWS.md is therefore `trailer-absent`. Worth reconciling in
   the skill, not worked around per change.
2. **`GLOBAL_FLOOR_BIND_BIN=/usr/bin/true` no longer reaches the end of the
   suite** and has not since `run_binder_cut` was added — the helper hard-exits
   when its pattern does not match, long before the `--check` section. Not a
   regression from this change (reproduced on `HEAD`), but the documented teeth
   check now covers only the first third of the file.
3. **The gate override is resolved once, against the checker's cwd**, so a
   relative or slashless `OPENSPEC_GATE` would be reported wrongly. Declined
   deliberately — every realistic value is absolute — and recorded in
   `REVIEWS.md` rather than built.
4. **`workflow-installation` still says a reporting surface "is owed".** True
   when written; after the archive, `--check` is that surface and is specified in
   the same capability. Left alone rather than opening a MODIFIED block to change
   a tense.
5. Carried over: AGE-510, AGE-509, no interception of destructive SQL,
   `normalize-claude-md` has no implementation, `claude-workflow` has 11 commits
   on no remote, the installer has no retired-artifact sweep.
