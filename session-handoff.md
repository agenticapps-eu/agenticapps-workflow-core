# Session Handoff — 2026-08-08 (twenty-fourth session)

The floor is bound and the fleet's per-project copies are gone. The session
started by trying to run a migration, found the tool could not act on a single
repository it was built for, and ended up removing the duplicated workflow from
five projects — which was the actual job all along.

## The machine now

| | |
|---|---|
| `core.hooksPath` (global) | `~/.agenticapps/git-hooks` — hook version 1.1.0 |
| enrolled + verified gating | `agents-task-viewer`, `callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`, core |
| core | local `core.hooksPath` → own `.git/hooks`, `agenticapps.hooksbinding=declared` (ADR-0028) |

Verified by probing with a stand-in gate: all six invoke it and propagate its
exit, and an unenrolled repository does not. That pair is the only test that
distinguishes "gated" from "quiet" — a bare exit 0 looks identical for gated,
unenrolled and failing-open.

Undo the bind: `git config --global --unset core.hooksPath`. **Only valid while
no hook has been removed** — after removal it takes away the only surface the
migrated repositories have.

Side effect, accepted: the global binding stops git reading `.git/hooks/`
everywhere, so `codex-workflow` and `opencode-workflow` are now quiet. Both are
archived, pending deletion.

## Open PRs

| Repo | PR | What |
|---|---|---|
| core | **#93** | `init-project.sh` enrols — task 2.8b, 50 → 55 cases |
| cparx | **#130** | drop vendored copies + one instruction file, 433 → 282 lines |
| fx-signal-agent | **#132** | drop vendored copies + instruction file collapse |
| callbot | #101 (existing) | commits ride the open cleanup branch |
| agents-task-viewer | #19 (existing) | same |

Core PR **#92 is closed** — the adoption predicate built earlier in the session
for a one-time act on one machine. Its one real finding is recorded below.

## Decisions

- **`init-project.sh` writes a third thing: the enrolment key.** The other two
  writes are inert without it — the dispatcher exits 0 for want of
  `agenticapps.workflow.enrolled`, so a project with `openspec/` and an
  instruction file and no key is ungated while looking identical on disk to one
  that is gated. Five repositories had live OpenSpec changes and none was
  enrolled. `--local` never `--global`; warns rather than fails.
- **The projects carried a fork of the workflow, not just of the hook.** Each of
  the five had three fleet hooks and seven vendored skills, and all four factiv
  copies of `agentic-apps-workflow` had **diverged from core's 4.0.0** — with
  fbc-platform's diverged differently from the other three. Two independent
  forks nothing reported.
- **`normalize-claude-md` had been dead the whole time.** The shim resolves
  `~/.agenticapps/bin/normalize-claude-md.sh`, which does not exist and has no
  reference implementation in core. It was failing open on every edit. This is
  the "spec drift on main" open question, now with a measured consequence.
- **cparx's two instruction files were reconciled by hand**, because
  `init-project.sh` correctly refuses to pick which of two rule-sets survives.
  `AGENTS.md` was a vendored copy of core **0.4.0** §11; `CLAUDE.md` restated
  the workflow and linked to deleted files. Kept every cParX-specific section,
  dropped what the skill owns.
- **`workflow-config.md` deleted everywhere.** cparx's budget window closed in
  May; callbot's only real content, the Conventional Commits rule with the
  custom `compliance:` prefix, is already in its `AGENTS.md:340`.

## Next session: start here

**1. fbc-platform is unfinished and it is the interesting one.** Its `.claude/`
deletions were reverted mid-session, and the cause is **two Claude Code sessions
on one working tree** — another session was mid-ticket on AGE-507, committing at
20:28, 21:06 and 21:36 and editing files at 21:10–21:25. A `git stash`/`git
restore` inside its diff-review loop undid the deletions and left no reflog
entry, because neither moves HEAD. I backed out rather than fight it; the
back-out itself was sandbox-blocked, so **first check
`git -C ~/Sourcecode/factiv/fbc-platform status` and clear any stray `.claude`
deletions before that session commits them into an AGE-507 commit.** Then redo
the cleanup when nothing else is running there.

**2. Publish `init-project.sh` 1.1.0.** `~/.agenticapps/bin/` still has 1.0.0,
so anyone running the published copy gets an unenrolled project.

**3. Delete the transitional binder.** `reference-implementations/global-floor/`
and `tools/global-floor-bind.test.sh` exist to perform a migration that has
happened and cannot happen again on this machine — the memory note says convert,
then delete. Its one finding worth keeping first: **a repository refused at the
preflight is never enrolled, so binding the floor silences the hook the refusal
said it was keeping.** Reproduced with a failing test; the fix is on the closed
branch `feat/run-the-global-floor-migration`.

## Open

1. **fbc-platform lost husky.** Unsetting its local `core.hooksPath` brought it
   under the floor and stopped `pnpm lint-staged` and `pnpm typecheck` running
   on commit. Real checks, currently unowned — CI, a pre-push, or chaining.
2. **`projects-bind-not-copy` is specified and unimplemented.** It is the change
   that removes `database-sentinel` from projects; the spec said it was dead
   while the machine ran it in five repos. `fleet-carries-only-current` task 0.1
   is still breached waiting on it being archived.
3. **Tasks 3.1 / 3b.1 / 3b.4 are satisfied in fact but unticked**, and
   3.0a–3.0g describe a mechanism with no reason to exist. Reconcile before
   archiving `one-enforcement-floor`.
4. `--check`'s half of 9.10 — now the only surface that would report a
   repository the floor does not reach. 9.5, 9.7, 9.8, 9.9, 9.12 open.
5. **callbot and fx-signal-agent instruction files are collapsed but not
   thinned.** Both are ~24k and likely restate the workflow the way cparx's did.
   Same editorial pass, one repo at a time.
6. Stale `.clone/worktrees/agent-*` stubs in callbot and cparx — untracked
   leftovers, safe to delete, sandbox blocked me.
7. **2.6a**: `.planning/` was one name doing two jobs; the split is unrecorded.
8. `fx-signal-agent` has no `packageManager` pin.
9. Census inconsistencies CodeRabbit found on #90 — `proposal.md:71` ten/six vs
   eleven/seven, `planning-removal-inventory.md` 48/6 vs 50/4, GSD tree counts
   in `proposal.md:27` and `tasks.md:206`. MD040 fences in three docs.
10. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
    held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
11. `claude-workflow` cannot be deleted safely — 11 commits on no remote,
    `plan/28-split-01` 9 ahead, 1 stash. It is also the provenance of every hook
    removed today, and of the templates that seeded the forks.
12. Spec drift on `main`: `project-hook-binding/spec.md` names
    `normalize-claude-md` as a live shim in seven places; the implementation is
    gone. Planned in `diagram-is-the-surface`, 0/46.

## Mistakes worth not repeating

- **Ten commands became a spec round.** The binder refused the migration set on
  a correct ownership check; the right answer was to delete three files by hand.
  Instead the session produced an adoption predicate, a spec delta, a design
  decision, a vendor review round and 15 test cases — generality for a one-time
  act on the only machine that has this workflow. The memory note
  `workflow-runs-on-one-machine` already said so and was in context.
- **A measurement can be precise and about the wrong property.** Task 0.3a
  recorded nine hook sizes to the byte and never checked the ownership marker
  the removal code branches on.
- **My own first check reproduced the bug it was hunting.** `git rev-parse
  --git-common-dir` returns a *relative* `.git`, so three greps read core's own
  hook and agreed with the stale census. Resolve paths absolutely before
  asserting about another repository's files.
- **I checked hooks and enrolment and called it a machine-wide sweep**, having
  never looked in `.claude/`. The operator asked "did you check all repos?" and
  the answer was no. The thing that was still running — database-sentinel in
  five repos — was one directory away from where I was looking.
- **Deleting files in a repository another agent is working in.** No mechanism
  was at fault in fbc-platform; two sessions shared one working tree. Check for
  live sessions before mutating a repo that is not the one you are in.
