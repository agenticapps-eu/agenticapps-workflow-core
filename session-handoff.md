# Session Handoff — 2026-08-08 (twenty-first session)

17 commits on `feat/floor-establishes-cores-binding`, **still no PR, not pushed**
(17 ahead of origin). Tree clean, `openspec validate --all` 14/14.
`one-enforcement-floor` 45/100, `fleet-carries-only-current` 14/46.

Two halves. 9.4a was unblocked by a decision and a plan review. Then a residue
sweep found the retired tool was never uninstalled, 11.1G of orphaned worktrees,
and two security checks that had been written off as broken and weren't.

## Accomplished

- **Decision 7 closes 9.10's migration half and 3b.5.** The migration set is
  named, never discovered. 61 repositories measured first; seven carry a gate
  hook, **none is enrolled**.
- **Plan review round 2** — gemini + codex, both REQUEST-CHANGES, **nine
  findings, all accepted**. Recorded in `REVIEWS.md`.
- **GSD actually uninstalled** — 231 paths across pi, opencode, codex, **three**
  npm installs and two update caches. Plus three project `.pi/gsd` trees.
- **11.1G of orphaned agent worktrees removed** — cparx (4.7G) and
  fx-signal-agent (6.4G), each proved empty of unique work first.
- **`.planning/` gone from all seven in-scope repos.**
- **Six PRs merged** across four repos: cparx #129, callbot #102/#103,
  fbc-platform #141, fx-signal-agent #121/#130/#131.
- **`Supply chain (REQ-SEC01)` green on `main` for the first time.**

## Decisions

- **Discovery is unnecessary, not deferred.** The floor governs only enrolled
  repositories and enrolment is an act, so **enrolment is the consent**. The
  preflight reports what this run will *newly enrol* — the set it was handed.
- **Mutation set ≠ impact set.** Decision 7's first draft claimed the binder
  holds every repository the binding will govern. `init-project.sh` makes that
  false. Retracted in the decision as a correction, not rewritten.
- **Order is enrol → sweep → verify → remove.** Both reviewers independently
  found that sweeping an unenrolled repo hands it to a dispatcher that exits 0 —
  a window with a hook, a binding and no enforcement. Enrolment is inert until
  the sweep, so enrolling first costs nothing.
- **A tool is uninstalled when its package, its per-host config dirs and its
  project copies are all gone.** `npm rm -g` alone would have left most of GSD.
  Written into `~/.claude/CLAUDE.md`.
- **A caret range is not a safety guarantee.** Resolving CVEs "within declared
  ranges" moved `@supabase/supabase-js` (no advisory against it) and broke
  `cross-tenant`. Redone as five overrides: churn +1118/-1101 → +30/-39.
- **Never regenerate a lockfile with a different pnpm major than CI.** Local 11
  vs CI 9, `packageManager` unset — would have broken every job in the repo.
- **Working security checks are fixed, not deleted.** Removing them would strip
  the only CI surface for numbered requirement REQ-SEC01.
- **`commitment-reinject.sh` keys on `openspec/`**, since `.planning/` — its old
  predicate — was deleted fleet-wide by this session's own sweep.

## Files modified

- `openspec/changes/one-enforcement-floor/design.md` — Decision 7, carrying its
  own correction inline
- `.../one-enforcement-floor/specs/workflow-installation/spec.md` — new
  requirement "The migration acts only on repositories the operator names" (9
  scenarios); `No repository is left with neither surface` amended for the sweep
  step, in-repository interruption, and restore-on-failure
- `.../one-enforcement-floor/{tasks.md,REVIEWS.md}` — 3b.5 closed, 9.10
  half-closed, 9.4a unblocked, 9.4c–9.4h added; round-2 review appended
- `.../fleet-carries-only-current/{tasks,proposal}.md` — 1.3, 1.3b, 1.3c, 1.3d,
  2.1, 2.1a, 2.2, 2.6, 2.6b, 2.9 closed; 1.3a, 2.6a, 2.8 opened
- `.../fleet-carries-only-current/*-inventory.md` — **3 new**: GSD 1.30.0 trees,
  GSD machine-level (231 paths), `.planning/` (48 files)
- `~/.claude/CLAUDE.md` — residue paragraph re-measured; every figure was stale
- `~/Sourcecode/agenticapps/CLAUDE.md` — dashboard checkout is deleted, not "in
  place"; records that `meta-observer` ran out of it
- `~/.claude/hooks/commitment-reinject.sh` — predicate `.planning` → `openspec`,
  dead `COMMITMENT.md` block removed

## Next session: start here

**Implement 9.4a.** It is unblocked and the delta specifies it fully. The work is
`reference-implementations/global-floor/bind-global-floor.sh`: fold the existing
hooks-directory inventory and a new named-repository migration into **one report
under one acceptance**, then per repository enrol → sweep → verify → remove. RED
first, and **9.4d is the case that matters** — stop the binder immediately after
the sweep and assert the commit is still gated; it fails under the rejected order
and passes under this one. Tests in `tools/global-floor-bind.test.sh` (48 cases
today), per-case `HOME`, per-case global **and** local git config. **`install.sh`
still must not be run**: line 346 binds the floor unconditionally and nothing is
enrolled. Recovery: `git config --global --unset core.hooksPath`.

## Open questions

1. **No PR for this branch, and it is not pushed** — 17 commits local only.
2. **Stage 2 has read none of §10 or Decision 7.** Per §07 it runs in a cleared
   session with no implementation context.
3. **gemini's reviewer model is unresolved** — CLI 0.28.2 prints no model line,
   so round 2 meets the two-vendor rule but not the provenance rule.
4. **Seven §9 findings open** — 9.4a, 9.4b, 9.5, 9.7, 9.8, 9.9, 9.12, plus
   9.10's `--check` half.
5. **2.6a is still open**: `.planning/` was one name doing two jobs (dead
   telemetry, live-ish config). The name is gone; the split is unrecorded in the
   spec.
6. **`fx-signal-agent` has no `packageManager` pin** — the trap that nearly broke
   every job there is still armed for the next person.
7. **Six `~/.claude/projects/*/memory/*gsd*` files** left alone — records about
   GSD, not GSD. Delete or keep is unresolved.
8. **The four host repos still carry `.planning/`** by 1.2, pending Phase 5b.
9. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Operator action, still outstanding.
10. **`claude-workflow` cannot be deleted safely** — 11 commits on no remote,
    `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
11. **`fleet-carries-only-current` task 0.1 is breached**: it is gated on
    `projects-bind-not-copy` being archived, which has not happened, yet §1 and
    §2 were worked. Reconcile rather than leave silent.
12. **Spec drift on `main`**: `openspec/specs/project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.

## Mistakes worth not repeating

- **Check `git branch` and `gh pr list` before working in someone else's repo.**
  PR #130 duplicated a commit the operator had made three days earlier on an open
  PR (#121), and the name collision caused a `checkout -b` failure that put a
  commit on `main` (caught before push, `main` restored).
- **An empty result is not a clean result.** Twice: "0 dirty, 0 unpushed" when
  git was erroring, and a lockfile comparison that grepped a pattern matching
  nothing. Both read as reassuring.
- **A `&&` chain will commit after a script aborted.** One commit message
  described edits its commit did not contain; the same bad Python anchor recurred
  later and was caught before committing.
- **Listing before removing changed the answer three times** — GSD trees, the
  worktrees, and `.planning/`. It is the rule that earned its keep.
