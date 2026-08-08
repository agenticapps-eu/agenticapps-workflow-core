# Session Handoff — 2026-08-08 (twenty-second session)

Two PRs. **#90 merged** — the 23 commits the last session left unpushed. **#91
open** on `feat/migration-acts-only-on-names`, 2 commits, gate green on the
head, CodeRabbit's one finding folded in. `openspec validate --all` 14/14, all
14 suites in `tools/` green.

`one-enforcement-floor` is now 54/100, `fleet-carries-only-current` 14/46.

## Accomplished

- **PR #90 merged.** Last session's branch was 18 commits ahead of a remote that
  already existed and had no PR. Pushed, opened, merged as `b095985`.
- **9.4a built**, and with it 9.4b–9.4h and 2.9 — those name what this code owes
  rather than separate work. `bind-global-floor.sh` grew a named-repository
  migration: preflight → one acceptance → publish → bind → enrol/sweep/verify/
  remove per repository.
- **28 new cases** in `tools/global-floor-bind.test.sh` (76 total, **0 pass**
  under `GLOBAL_FLOOR_BIND_BIN=/usr/bin/true`).
- **A delete that escaped the named repository**, found by the security pass on
  the diff and reproduced before the guard.

## Decisions

- **The named set is positional arguments**, and `install.sh` passes none. The
  delta says "the names it was given" without saying how; this shape makes "acts
  only on repositories the operator names" true of the unattended path by
  construction rather than by a flag defaulting correctly. **The cost: nothing
  routes names through the installer**, so 3.1 means running the binder
  directly. Donald was asked and did not overrule it.
- **A name that does not resolve stops the whole run**, rather than being
  skipped. A set that cannot be stated correctly cannot be accepted correctly
  either, and the delta's "rejected before any repository is modified" reads as
  the stronger thing.
- **The machine binds even when a named repository fails.** The failure is local
  to a repository; refusing to bind a machine over one wrong path is the larger
  act taken for the smaller reason.
- **The enrolment is not rolled back when verification fails** — only the swept
  binding is restored. Enrolment is inert while the local binding stands, so
  unwinding it would undo something that is doing nothing.
- **2.9 reports the mutation set, not the impact set.** Decision 7 changed what
  that task means: enumerating every repository the binding governs needs the
  search Decision 7 removed, and would be false the first time anyone ran
  `init-project.sh`.
- **No test seam in the binder.** A production script carrying a branch that
  exists only for its tests has a branch that can be wrong in production. The
  interruption comes from a `git` earlier on PATH that passes the call through
  and kills the **process group** — not `$PPID`, because bash may fork a
  subshell for `x="$(git …)"` and killing that one lets the binder continue with
  an empty value.

## Files modified

- `reference-implementations/global-floor/bind-global-floor.sh` — the migration:
  resolution and classification, the preflight and its single acceptance
  (`GLOBAL_FLOOR_ACCEPT_PLAN`), and the per-repository sequence. `same_dir`
  moved to the top because resolution needs it before anything is published
- `tools/global-floor-bind.test.sh` — 28 cases; `run_binder_with`,
  `run_binder_cut`, `run_binder_answering`, `gated_repo`, `plant_gate`,
  `commit_refused`
- `.../one-enforcement-floor/specs/workflow-installation/spec.md` — "what is
  removed SHALL be what the report named", plus a scenario for the symlinked
  hooks directory
- `.../one-enforcement-floor/tasks.md` — 9.4a–9.4h and 2.9 closed, each with
  what was built and what was demonstrated

## Next session: start here

**Stage 2 on PR #91, in a cleared session** — §07 wants independence, so it is
`/clear` and read the diff, never a subagent and never this session. The diff is
two commits on `feat/migration-acts-only-on-names`; the thing worth attacking is
whether the enrol → sweep → verify → remove sequence really leaves an active
surface at *every* instant, not only at the three points the suite cuts. After
that, merge #91 and the next task is **3.1 / 3b.1 / 3b.4: actually running the
migration** against `agents-task-viewer`, `callbot` and `fx-signal-agent` —
which is the first time this code touches a repository that is not a fixture.
Run it as `bind-global-floor.sh <three paths>` and read the preflight before
accepting. **`install.sh` still must not be run**: line 346 binds the floor
unconditionally and nothing is enrolled. Recovery: `git config --global --unset
core.hooksPath`.

## Open questions

1. **Stage 2 has read none of §10, Decision 7, or the 9.4 implementation.**
2. **Nothing routes named repositories through `install.sh`.** Deliberate, but
   3.1 is the task that will feel it.
3. **The census inconsistencies CodeRabbit found on #90 are unfixed**:
   `fleet-carries-only-current/proposal.md:71` says ten repositories and six
   where it is eleven and seven (`callbot`), `planning-removal-inventory.md`
   heads at 48 files / 6 tracked against 50 / 4 enumerated, and the GSD tree
   counts in `proposal.md:27` and `tasks.md:206` disagree with the files they
   list. Three inventory docs also want ```` ```text ```` fences (MD040).
4. **`--check`'s half of 9.10 is still open**, and so are 9.5, 9.7, 9.8, 9.9,
   9.12.
5. **2.6a is still open**: `.planning/` was one name doing two jobs; the name is
   gone and the split is unrecorded in the spec.
6. **`fx-signal-agent` has no `packageManager` pin.**
7. **Six `~/.claude/projects/*/memory/*gsd*` files** left alone — records about
   GSD, not GSD.
8. **The four host repos still carry `.planning/`** by 1.2, pending Phase 5b.
9. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Operator action, still outstanding.
10. **`claude-workflow` cannot be deleted safely** — 11 commits on no remote,
    `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
11. **`fleet-carries-only-current` task 0.1 is breached**: gated on
    `projects-bind-not-copy` being archived, which has not happened, yet §1 and
    §2 were worked.
12. **Spec drift on `main`**: `openspec/specs/project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.

## Mistakes worth not repeating

- **A negative assertion is satisfied by a binder that does nothing.** Nine of
  the new cases passed on first run before the implementation existed. Every one
  of them now carries a clause that can only be true if the run acted.
- **An interruption harness can stop interrupting.** CodeRabbit caught it: the
  cut couples to an exact git invocation, and if the pattern stops matching the
  binder runs to completion — and a *completed* run satisfies all three cut
  assertions, because enrolled-swept-and-gated is also where success ends. The
  shim now records that it fired.
- **The ownership marker answers "who wrote this file", not "is it in the
  repository the operator named".** A `.git` file or a symlinked hooks directory
  points wherever it likes. Reproduced: the file outside the repository was
  deleted and the run exited 0.
