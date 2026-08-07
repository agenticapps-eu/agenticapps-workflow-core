# Session Handoff — 2026-08-07 (fifteenth session)

**Plan repaired, two decisions closed, and the first code on
`one-enforcement-floor` landed.** Three commits on `feat/projects-bind-not-copy`
(PR #89). Working tree clean, `openspec validate --all` 14/14.

| Change | State |
|---|---|
| `fresh-clone-needs-nothing` | §3, §4, §9 built and installed. §1, §2, §5, §6 open |
| `one-enforcement-floor` | **§0, §1 done; the dispatcher is built and GREEN. §2's publish/bind is next** |
| `projects-bind-not-copy` | reviewed ×2, no code |
| `diagram-is-the-surface` | reviewed ×2, no code |
| `fleet-carries-only-current` | **never reviewed**, six sessions old |

## Accomplished

- `f29e018` — re-review folded in, measurements recorded, two decisions closed.
- `87c45f0` — handoff.
- `e33051f` — **GREEN: `reference-implementations/global-floor/pre-commit`** plus
  `tools/global-floor.test.sh`, 13/13. Closes 2.5, 2.6, 2.7, 2.8a, 6.9, 6.9a,
  6.10. shellcheck clean, `install.test.sh` 52/0.
- **8.2b re-review ran.** gemini APPROVE, codex REQUEST-CHANGES ×10, opencode
  timed out at 180s. Three findings verified empirically; all three real.
- **gitnexus fully removed from the machine** — package, 22 skills, npx caches,
  hooks, logs, 4 stale memories. ~3.2 GB. It was *not* removed on 2026-07-28.
- Removed the stray `agenticapps-dashboard-add-agent-board` worktree and
  `.claude/skills/gitnexus`.

## Decisions

- **3.2 supersede, not retarget.** The floor binder takes `COREHOOKS`'s variable
  and call site one-for-one: 217 → 217, no budget raise claimed. The real reason
  was not the budget — installing a *per-repository* hook from the
  *machine-level* installer wrote into whichever repo the shell sat in.
- **2.8 an explicit opt-in marker**, `agenticapps.workflow.enrolled`. Enrolment
  is an act, not an inference from a directory's shape. Both rejected
  alternatives fail silently for the person hit by them.
- **`init-project.sh` owns enrolment**, which amends its "writes exactly two
  things" header contract — amend it in the same diff (2.8b).
- **1.2 resolved as accepted exceptions.** The durable requirement is about the
  operator's interface ("no host argument"); it says nothing about host names in
  the source. 1.2 was testing its own stricter gloss, and the three sites are
  transitional machinery Phase 5b deletes.
- **Declined the privacy finding** — redaction would remove the evidence that
  makes the measurements checkable.

## Files modified

- `reference-implementations/global-floor/pre-commit` — new, the dispatcher
- `tools/global-floor.test.sh` — new, 13 cases
- `openspec/changes/one-enforcement-floor/tasks.md` — 0.2, 0.4, 1.2, 2.5–2.8a,
  3b.2, 6.9/6.9a/6.10, 8.2b closed; 3.2/5.7/6.13/7.2/3b.1/3.5 corrected; 2.8a–c,
  2.9, 3b.5, 4.1a added
- `.../design.md` — Decision 4, the scope-predicate decision, two risk rows, a
  falsified skill-resolution claim corrected
- `.../specs/workflow-installation/spec.md` — three dropped scenarios restored,
  new requirement "The floor governs only repositories that enrolled in it",
  budget blockquote rewritten
- `.../specs/core-self-enforcement/spec.md` — the "outside the working tree"
  scenario narrowed to inside the git common directory
- Machine: gitnexus gone, dashboard worktree gone

## Next session: start here

**Tasks 2.1–2.4 — publish and bind — and that is where Decision 4 gets tested
rather than asserted.** Build `reference-implementations/global-floor/`'s binder,
then in `install.sh` swap `COREHOOKS` (line 26) and its call site (lines 345–346)
for the floor binder, one variable for one variable, one call for one call. The
budget assertion in `tools/install.test.sh:437` is `-le 217` and the file is at
exactly 217, so **if the swap is not line-for-line the suite fails immediately** —
that is the intended alarm, not a surprise. RED before GREEN.

2.8b (`init-project.sh` enrolment + its header contract + version bump) is
independent and can go either side.

Do **not** run 2.2 for real until 2.8c and 2.9 exist: binding globally without
the preflight is the machine-wide act the reviewers objected to.

## Open questions

1. **`fleet-carries-only-current` still never reviewed** — six sessions old, and
   the gate flags it at every commit. The cheapest useful review left.
2. **§18's version number** — still blocking a task in `diagram-is-the-surface`.
3. **Machine-level *commands* unconfirmed.** Machine-level *skills* are confirmed
   (`openspec-propose` et al. loaded with no local copy this session), but this
   repo carries `.claude/commands/opsx/`, which shadows the global one. Test in a
   repo with no `.claude/`.
4. **9.7 is measured and structural.** Sweeps test `[ -L ]` first, so copied
   *directories* are invisible; `LEGACY_DIRS` names exactly one. That is how 22
   gitnexus skills survived a "complete" removal for ten days. Saved as a memory.
5. **Task 3.5 has no owner** — nothing establishes core's local `core.hooksPath`
   now that `install.sh` stops calling the hook installer. A reviewer pushed back
   on leaving it open; it needs a named artifact.
6. **pi's opsx commands unreachable by symlink** — needs a pi package.
7. **The review is stale again.** These commits changed `tasks.md` and both spec
   deltas after the reviewers read them, so the `tasks-digest` no longer matches
   and the gate says so at every commit. Judged not worth a third round: the
   edits were the reviewers' own findings applied, and the three substantive ones
   were verified rather than argued. Revisit if §2's publish/bind changes shape.
8. **opencode timed out** at 180s and was not counted. Raise `REVIEW_TIMEOUT` for
   a third opinion.
9. **CodeRabbit still has not reviewed anything here.**
10. Three cparx `tool-results` transcripts still mention gitnexus — left as
    session history, not residue.
