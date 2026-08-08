# Session Handoff — 2026-08-08 (twenty-fourth session)

**The migration is done.** The floor is bound, the three per-repository hooks are
gone, and all four repositories were verified to gate. It was done by hand, in
about ten commands, after most of a session was wasted building a mechanism to
do it that will now never run.

**PR #92 is closed** and `feat/run-the-global-floor-migration` should be deleted.

## What the machine looks like now

| | |
|---|---|
| `core.hooksPath` (global) | `~/.agenticapps/git-hooks` |
| published hook | `global-floor-version: 1.1.0`, 10k — replaced the stale 2270-byte opencode copy from 25 Jul |
| `agents-task-viewer`, `callbot`, `fx-signal-agent` | `agenticapps.workflow.enrolled=true`, local `core.hooksPath` unset, own `pre-commit` deleted |
| core | local `core.hooksPath` → its own `.git/hooks`, `agenticapps.hooksbinding=declared` (ADR-0028) |

Verified by probing with `OPENSPEC_GATE=<fake>`: all four run the gate and
propagate its exit. An unenrolled repository does not — which is the pair that
distinguishes "gated" from "silently quiet", and exit 0 alone cannot.

Undo: `git config --global --unset core.hooksPath`.

**Side effect, accepted:** the global binding stops git reading `.git/hooks/`
everywhere. `codex-workflow` and `opencode-workflow` still have hooks there and
are now quiet. Both are archived and pending deletion.

## What went wrong this session, because it will otherwise recur

The binder refused all three repositories: their `pre-commit` carried no
`# managed-by:` line, because claude-workflow's installer wrote them, not core's.
That refusal was correct — it is a guard against deleting a file the tool cannot
prove it wrote.

**The right response was to delete three files by hand.** Instead the session
produced a digest-based adoption predicate, a spec delta, a design decision, a
vendor review round and 15 test cases — generality for a one-time act on the only
machine that has this workflow. The operator called it what it was.

`~/.claude/projects/.../memory/workflow-runs-on-one-machine.md` already says
this: convert this machine, then delete the transitional code. It was in context
and was not applied.

**Also worth keeping: the first measurement was wrong and agreed with the
existing record, which is what made it convincing.** A marker check used
`git rev-parse --git-common-dir`, which returns a *relative* `.git`, so three
greps read core's own hook and reported the marker present three times. Resolve
paths absolutely before asserting about files in another repository.

## Next session: start here

**Delete the transitional code.** `reference-implementations/global-floor/` and
`tools/global-floor-bind.test.sh` exist to perform a migration that has now
happened and cannot happen again on this machine. Decide whether the binder is
kept as a published artifact for a machine that does not exist, or removed. The
memory note says removed. That decision wants recording in the change, then
`one-enforcement-floor` can move toward archive.

The one real finding from the wasted work, if any of it is kept: **a repository
refused at the binder's preflight is never enrolled**, so binding the floor
silences its own hook while the run reports it as keeping it. Reproduced with a
failing test before it was fixed. It is a ten-line fix, and it is on the closed
branch `feat/run-the-global-floor-migration` if wanted.

## Open

1. **Tasks 3.1 / 3b.1 / 3b.4 / 3.0h are satisfied in fact but unticked** in
   `openspec/changes/one-enforcement-floor/tasks.md`, and 3.0a–3.0g describe a
   mechanism that no longer has a reason to exist. Reconcile before archiving.
2. `--check`'s half of 9.10 is open — it is now the only surface that would
   report a repository the floor does not reach. 9.5, 9.7, 9.8, 9.9, 9.12 open.
3. **2.6a**: `.planning/` was one name doing two jobs; the split is unrecorded.
4. `fx-signal-agent` has no `packageManager` pin.
5. Census inconsistencies CodeRabbit found on #90 unfixed —
   `fleet-carries-only-current/proposal.md:71` ten/six against eleven/seven,
   `planning-removal-inventory.md` 48/6 against 50/4, GSD tree counts in
   `proposal.md:27` and `tasks.md:206`. Three inventory docs want ` ```text `
   fences (MD040).
6. Six `~/.claude/projects/*/memory/*gsd*` files left alone — records about GSD.
7. The four host repos still carry `.planning/` by 1.2, pending Phase 5b.
8. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Operator action, outstanding.
9. `claude-workflow` cannot be deleted safely — 11 commits on no remote,
   `plan/28-split-01` 9 ahead of `origin/main`, 1 stash. It is also where every
   hook removed today came from.
10. `fleet-carries-only-current` task 0.1 is breached: gated on
    `projects-bind-not-copy` being archived, which has not happened.
11. Spec drift on `main`: `openspec/specs/project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.
