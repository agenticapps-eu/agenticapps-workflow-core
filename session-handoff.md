# Session Handoff — 2026-08-08 (twenty-third session)

**PR #91 merged** as `6fe5a56`, but not before stage 2 found a real window and
closed it. `openspec validate --all` 14/14, all 14 suites in `tools/` green,
`tools/global-floor-bind.test.sh` now 79 cases.

Branch `feat/migration-acts-only-on-names` is deleted. **This file is
uncommitted on `main`** — it needs to ride the next feature branch, because
nothing is ever committed to `main` directly.

## Accomplished

- **Stage 2 on #91, in this cleared session**, per §07. It found the thing the
  last handoff pointed at: whether the sequence leaves an active surface at
  *every* instant, not only at the three points the suite cuts. It does not.
- **The window, reproduced before the fix.** All three interruption cuts were
  taken against `gated_repo r1 redundant ours` — a repository whose local
  `core.hooksPath` is what displaces its own hook. A repository with **no** local
  binding is displaced by something else entirely: setting `core.hooksPath`
  globally stops `.git/hooks/` being consulted everywhere at once. Cut the run at
  the binding and a commit succeeded in a repository whose gate hook was still on
  disk, enrolled by nothing.
- **Fixed**: the enrolment is now its own pass, immediately before the global
  binding and after every refusal the binder makes.
- **Three cases added** (79 total). Two of them fail against the previous binder
  and pass against this one; the third is coverage, not a guard.
- **#91 merged** with a merge commit, matching #90.

## Decisions

- **Enrolment moved out of the per-repository loop, not just re-ordered inside
  it.** The loop's order was chosen to close a window that the binding reopens
  one step earlier and for every named repository at once. Fixing it inside the
  loop would have been fixing it in the wrong place.
- **Placed after every refusal, not before the publish.** A foreign global
  binding, or a foreign local one in core, still exits with nothing written into
  a named repository. Enrolling earlier would have been simpler and would have
  left marks in repositories on a run that refused.
- **A repository that cannot be enrolled is dropped, not fatal.** Same posture
  every later step already takes toward the repository it fails on: its hook is
  untouched and still gates it, `$PLAN/skip.$i` carries that to the loop.
- **Merged with CodeRabbit rate-limited.** Its check is green and means nothing
  ("Review rate limited"). One real CodeRabbit round happened earlier on this
  PR and its finding was folded in; the new commit is stage-2 work, reviewed by
  the pass that produced it.
- **The third new case is not a regression guard and says so.** A *completed*
  run reaches the same end state under both orders — the same trap the
  interruption harness fell into last session.

## Files modified

- `reference-implementations/global-floor/bind-global-floor.sh` — the enrolment
  pass before `── The global binding ──`; the migration loop is now sweep →
  verify → remove and skips `$PLAN/skip.$i`; header and section comments say
  which displacement each step answers
- `tools/global-floor-bind.test.sh` — three cases: cut at the global binding,
  cut at the enrolment, and the completed run, all against `gated_repo r1 none
  ours`. Note the cut pattern must be **one word** — `'*--global?core.hooksPath?*'`,
  never a pattern with spaces, which is a syntax error inside the injected shim
  and takes the run down somewhere unrelated
- `.../one-enforcement-floor/specs/workflow-installation/spec.md` — "every named
  repository SHALL be enrolled before the global binding is set", the
  interruption scenario widened to the binding, and a scenario for the
  repository with no local binding at all
- `.../one-enforcement-floor/tasks.md` — 9.4b and 9.4d carry the correction

## Next session: start here

**3.1 / 3b.1 / 3b.4 — actually running the migration** against
`agents-task-viewer`, `callbot` and `fx-signal-agent`. This is the first time
this code touches a repository that is not a fixture, and one of the three is
the no-local-binding shape the fix above exists for. Run it as
`reference-implementations/global-floor/bind-global-floor.sh <three paths>` from
inside core's checkout, **read the preflight before answering y**, and expect it
to name any linked worktrees. `install.sh` still must not be run: line 346 binds
the floor unconditionally and nothing is enrolled. Recovery for a bad bind:
`git config --global --unset core.hooksPath`.

Before that, take this file onto a feature branch and commit it.

## Open questions

1. **The census inconsistencies CodeRabbit found on #90 are still unfixed**:
   `fleet-carries-only-current/proposal.md:71` says ten repositories and six
   where it is eleven and seven (`callbot`), `planning-removal-inventory.md`
   heads at 48 files / 6 tracked against 50 / 4 enumerated, and the GSD tree
   counts in `proposal.md:27` and `tasks.md:206` disagree with the files they
   list. Three inventory docs also want ```` ```text ```` fences (MD040).
2. **`--check`'s half of 9.10 is still open**, and so are 9.5, 9.7, 9.8, 9.9,
   9.12.
3. **2.6a is still open**: `.planning/` was one name doing two jobs; the name is
   gone and the split is unrecorded in the spec.
4. **`fx-signal-agent` has no `packageManager` pin** — it is in the migration
   set, so this lands next session.
5. **Six `~/.claude/projects/*/memory/*gsd*` files** left alone — records about
   GSD, not GSD.
6. **The four host repos still carry `.planning/`** by 1.2, pending Phase 5b.
7. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Operator action, still outstanding.
8. **`claude-workflow` cannot be deleted safely** — 11 commits on no remote,
   `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
9. **`fleet-carries-only-current` task 0.1 is breached**: gated on
   `projects-bind-not-copy` being archived, which has not happened, yet §1 and
   §2 were worked.
10. **Spec drift on `main`**: `openspec/specs/project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.
11. **Nothing routes named repositories through `install.sh`.** Deliberate, but
    3.1 is the task that will feel it.

## Mistakes worth not repeating

- **A fixture can be the whole blind spot.** Every one of the three interruption
  cuts was correct, well-argued and taken against the same repository shape, and
  that shape was the one where the sweep is the displacer. The suite grew teeth
  in one direction and had none in the other. When a case turns on *what
  displaces the hook*, vary the thing that displaces it, not the moment.
- **The file already contained the argument it needed.** The core-repair step
  says setting the global binding IS the moment core's own hook stops being
  preferred — and then the same instant went unanswered for the repositories the
  operator named. An argument made for one subject is worth checking against
  every other subject in the same file.
- **A case pattern is one word.** `run_binder_cut 'config --global core.hooksPath*'`
  is a syntax error inside the shim, which then fails every git call, and the
  harness reports "never matched" — which reads as "the run took a different
  path" and is not.
