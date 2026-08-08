# Session Handoff — 2026-08-08 (twentieth session)

Six commits on `feat/floor-establishes-cores-binding`, **still no PR**. Tree
clean, `openspec validate --all` 14/14. Two PRs opened in other repos.

9.4a was blocked and is now unblocked. Then the residue sweep found the retired
tool still installed, and 4.7G of orphaned worktrees behind it.

## Accomplished

- **Decision 7 closes 9.10's migration half and 3b.5.** The migration set is
  named, never discovered. Measured first: 61 repositories under `~/Sourcecode`,
  seven carrying a gate hook, **none enrolled**.
- **Plan review round 2** — gemini and codex, both REQUEST-CHANGES, nine
  findings, **all accepted, none ignored**. Recorded in `REVIEWS.md`.
- **GSD removed from the two live repositories** — `.pi/gsd/` 1.30.0, 348 files,
  3.6M, untracked. cparx PR #129, callbot PR #102 for the tracked commands.
- **4.7G of orphaned agent worktrees deleted from cparx**, after proving no work
  was in them.
- **Global `~/.claude/CLAUDE.md` corrected** — every figure in its residue
  paragraph was stale.

## Decisions

- **Discovery is unnecessary, not deferred.** The floor governs only enrolled
  repositories and enrolment is an act, so enrolment *is* the consent and the
  binding owes none separately. The preflight reports what this run will **newly
  enrol** — the set it was handed.
- **The mutation set is not the impact set**, and the first draft of Decision 7
  conflated them. `init-project.sh` is an independent enrolment source, so a
  repository enrolled earlier becomes governed unnamed and unreported. Retracted
  in the decision as a correction rather than rewritten. Enumerating the impact
  set belongs to `--check` — 9.10's other half, deliberately still open.
- **The order is enrol → sweep → verify → remove.** The draft said sweep first;
  both reviewers independently found that sweeping an unenrolled repository
  hands it to a dispatcher that exits 0 for want of the marker — a window with a
  hook file, a global binding and no enforcement. Enrolment is inert until the
  sweep because the local hook predates the predicate.
- **The decline guarantee is scoped, not absolute.** `install.sh` publishes
  before reaching the binder, so "leaves the machine untouched" is unkeepable.
  Moving the preflight above every mutation was rejected as the larger and worse
  change.
- **Operator input is not evidence about the disk** — names canonicalised and
  deduped by `--git-common-dir`, linked worktrees reported, and a `pre-commit`
  recognised from the file before removal. 10.7's finding one level down.
- **`callbot/setup.md` is not GSD's** and was struck from task 2.1. Zero GSD
  mentions against `gsd-plan.md`'s ten — it provisions Twilio and Cloudflare.
  The row was built from filenames. `backend-foundation.md` checked and kept,
  which closed 2.2.
- **`pi-agentic-apps-workflow` stays untouched** — `archived=true` on the forge,
  confirming task 1.2. The family instruction file still lists it as active.

## Files modified

- `openspec/changes/one-enforcement-floor/design.md` — Decision 7, with its own
  correction recorded inline
- `.../one-enforcement-floor/specs/workflow-installation/spec.md` — new
  requirement "The migration acts only on repositories the operator names" (9
  scenarios); `No repository is left with neither surface` amended for the sweep
  step, the interruption-inside-a-repository case and the restore-on-failure case
- `.../one-enforcement-floor/tasks.md` — 3b.5 closed, 9.10 half-closed, 9.4a
  unblocked, 9.4c–9.4h added
- `.../one-enforcement-floor/REVIEWS.md` — round 2 appended before the trailer
- `.../fleet-carries-only-current/{tasks,proposal}.md` — 1.3, 1.3b, 2.1, 2.1a,
  2.2 closed; 1.3a and 2.1b added; `.planning/` table corrected for callbot
- `.../fleet-carries-only-current/gsd-1.30.0-removal-inventory.md` — **new**, the
  361-line pre-deletion listing
- `~/.claude/CLAUDE.md` — residue paragraph re-measured
- Deleted: `cparx/.pi/gsd`, `open-design/.pi/gsd`, `cparx/.claude/worktrees/`

## Next session: start here

**Implement 9.4a** — it is now unblocked and the delta specifies it fully. The
work is `reference-implementations/global-floor/bind-global-floor.sh`: fold the
existing hooks-directory inventory and a new named-repository migration into
**one report under one acceptance**, then per repository enrol → sweep → verify
→ remove. RED first, and 9.4d is the case that matters — stop the binder
immediately after the sweep and assert the commit is still gated, which fails
under the rejected order and passes under this one. Tests go in
`tools/global-floor-bind.test.sh` (48 cases today), per-case `HOME`, per-case
global *and* local git config. **`install.sh` still must not be run**: line 346
binds the floor unconditionally and nothing is enrolled, so the floor would
govern nothing. Recovery if it is:
`git config --global --unset core.hooksPath`.

## Open questions

1. **No PR for this branch**, now six commits.
2. **Stage 2 has read none of §10 or Decision 7.** Per §07 it runs in a cleared
   session with no implementation context.
3. **gemini's reviewer model is unresolved** — CLI 0.28.2 printed no model line,
   so round 2 satisfies the two-vendor rule but not the provenance rule. Fix on
   the next round.
4. **Seven §9 findings still open** — 9.4a, 9.4b, 9.5, 9.7, 9.8, 9.9, 9.12, plus
   9.10's `--check` half.
5. **The newer-marked-`pre-commit` refusal still has no scenario** in the delta.
6. **`.planning/` is eleven repositories, not ten**, and `fleet-carries-only-current`
   task 2.6 still says six in scope. Seven.
7. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Operator action, still outstanding.
8. **`claude-workflow` cannot be deleted safely** — 11 commits on no remote,
   `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
9. **`fleet-carries-only-current` is gated on `projects-bind-not-copy` archiving**
   (its task 0.1), which has not happened. §1 and §2 have been worked anyway,
   which is worth reconciling rather than leaving as a silent precondition
   breach.
10. **Spec drift on `main`**: `openspec/specs/project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.
11. **CodeRabbit still has not reviewed anything here.**
