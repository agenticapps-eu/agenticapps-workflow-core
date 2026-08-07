# Session Handoff — 2026-08-07 (fifteenth session)

**No code. Plan repair, two decisions, and a machine cleanup that mattered more
than it looked.** `one-enforcement-floor` is now re-reviewed and its largest
risk is closed by decision. Still on `feat/projects-bind-not-copy` (PR #89).

| Change | State |
|---|---|
| `fresh-clone-needs-nothing` | §3, §4, §9 built and installed. §1, §2, §5, §6 open |
| `one-enforcement-floor` | **re-reviewed, findings folded, scope predicate decided — ready for code** |
| `projects-bind-not-copy` | reviewed ×2, no code |
| `diagram-is-the-surface` | reviewed ×2, no code |
| `fleet-carries-only-current` | **never reviewed**, six sessions old |

## Accomplished

- **Tasks 0.2, 0.4, 1.2, 3b.2 measured and recorded.** Installer is at
  **217/217 — zero headroom**, not the 212-with-5-spare the task claimed.
- **Task 3.2 decided: supersede.** The floor binder takes `COREHOOKS`'s variable
  and call site one-for-one, so the arithmetic is 217 → 217 and **no budget
  raise is claimed**. Design Decision 4.
- **Task 2.8 decided: explicit opt-in marker** — `agenticapps.workflow.enrolled`,
  a local git config key, checked ahead of the gate. Prototyped and proven.
- **8.2b re-review ran.** gemini APPROVE, codex REQUEST-CHANGES ×10, opencode
  timed out. Three findings verified empirically; all three were real. Five more
  accepted into tasks; one declined with a reason.
- **gitnexus fully removed** — package, 22 skills, npx caches, hooks, logs,
  4 stale memories. ~3.2 GB. It was *not* removed on 2026-07-28 as recorded.
- Removed the stray `agenticapps-dashboard-add-agent-board` worktree and
  `.claude/skills/gitnexus` from this repo.

## Decisions

- **Supersede, not retarget** (3.2) — installing a per-repository hook from the
  machine-level installer was always a category error; it wrote into whichever
  repo the shell sat in. Budget was the cheaper argument, not the reason.
- **Opt-in marker over shape-inference or a declared list** (2.8) — enrolment is
  an act, not a guess. Both rejected alternatives fail silently for the person
  hit by them.
- **`init-project.sh` owns enrolment**, which amends its "writes exactly two
  things" header contract. Amend it in the same diff (2.8b).
- **Declined the privacy finding** — redacting paths would remove the evidence
  that makes the measurements checkable.

## Files modified

- `openspec/changes/one-enforcement-floor/tasks.md` — 0.2, 0.4, 1.2, 3b.2, 8.2b
  closed; 3.2/5.7/6.13/7.2/3b.1/3.5 corrected; 2.8, 2.8a–c, 2.9, 3.5, 3b.5,
  4.1a, 6.9a added
- `.../design.md` — Decision 4, the scope-predicate decision, two risk rows, and
  a falsified skill-resolution claim corrected
- `.../specs/workflow-installation/spec.md` — three dropped scenarios restored;
  new requirement "The floor governs only repositories that enrolled in it";
  budget blockquote rewritten
- `.../specs/core-self-enforcement/spec.md` — the "outside the working tree"
  scenario narrowed to inside the git common directory
- `REVIEWS.md` — round two
- Machine: gitnexus gone; dashboard worktree gone

## Next session: start here

**Task 1.2 is the thing to look at first, because it says the change's premise is
false.** Three sites in `install.sh` carry host-named code outside `HOSTS` and
`--check` — `ARCHIVED` (line 54), `neutral_of()`'s `codex-`/`opencode-` prefix
stripping (160–161), and a hard-coded `~/.claude/skills` (166). All inherited,
none introduced here. Task 7.2 expects the after-measurement to be clean and it
cannot be. Decide: accept them as recorded inherited exceptions, or open a
separate change. Do not restate the old expectation and pass against it.

Then code, in this order: **2.8a** (enrolment predicate in the published hook —
already prototyped), **2.8b/2.8c**, then section 2 proper. TDD, RED before GREEN.

## Open questions

1. **`fleet-carries-only-current` still never reviewed** — six sessions old.
2. **§18's version number** — still blocking a task in `diagram-is-the-surface`.
3. **Machine-level *commands* still unconfirmed.** Machine-level *skills* are
   confirmed (`openspec-propose` et al. loaded this session with no local copy),
   but this repo carries `.claude/commands/opsx/`, which shadows the global one.
   Test in a repo with no `.claude/`.
4. **9.7 is now measured, and it is structural.** Sweeps test `[ -L ]` first, so
   copied *directories* are invisible to them — that is how 22 gitnexus skills
   survived a "complete" removal for ten days. `LEGACY_DIRS` names exactly one
   directory. Saved as a memory.
5. **pi's opsx commands unreachable by symlink** — needs a pi package.
6. **Task 3.5 has no owner yet** — nothing establishes core's local
   `core.hooksPath` now that `install.sh` stops calling the hook installer.
7. **opencode timed out** at 180s in the review and was not counted. Raise
   `REVIEW_TIMEOUT` if a third opinion is wanted.
8. **CodeRabbit still has not reviewed anything here.**
9. Three cparx `tool-results` transcripts still mention gitnexus; left as
   session history, not residue.
