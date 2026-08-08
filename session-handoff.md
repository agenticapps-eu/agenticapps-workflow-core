# Session Handoff — 2026-08-08 (twenty-fourth session)

The floor is bound, the fleet's per-project copies are gone from all five live
repositories, and `projects-bind-not-copy` has its core-side half. The session
began by trying to run a migration, found the tool could not touch a single
repository it was built for, and ended up doing the thing the migration was for.

## The machine now

| | |
|---|---|
| `core.hooksPath` (global) | `~/.agenticapps/git-hooks` — hook 1.1.0 |
| enrolled + verified gating | `agents-task-viewer`, `callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`, core |
| core | local `core.hooksPath` → own `.git/hooks`, `agenticapps.hooksbinding=declared` (ADR-0028) |
| `SHIMMED-HOOKS` | **empty** — no project binds a fleet hook |

Verified by probing with a stand-in gate: all six invoke it and propagate its
exit; an unenrolled repository does not. That pair is the only test that
separates "gated" from "quiet" — a bare exit 0 looks the same for gated,
unenrolled and failing-open. The floor's `NOTE` output is visible on every real
commit made tonight.

Undo the bind: `git config --global --unset core.hooksPath`. **Valid only while
no hook has been removed** — after removal it takes away the only surface the
migrated repositories have.

## Open PRs

| Repo | PR | What |
|---|---|---|
| core | **#94** | `projects-bind-not-copy` core half — empty declaration + the vacuous-truth fix, 9 new cases |
| core | **#93** | `init-project.sh` enrols — task 2.8b, 50 → 55 cases |
| cparx | **#130** | vendored copies dropped + two instruction files collapsed, 433 → 282 lines |
| fx-signal-agent | **#132** | vendored copies dropped, files collapsed |
| fbc-platform | **#143** | vendored copies dropped + husky removed |
| callbot | #101 | commits ride the existing cleanup branch |
| agents-task-viewer | #19 | same |

Core PR **#92 is closed** — an adoption predicate built for a one-time act on
one machine. Its one real finding is under "start here".

## Decisions

- **`init-project.sh` writes a third thing: the enrolment key.** The other two
  writes are inert without it. Five repositories had live OpenSpec changes and
  none was enrolled, because the only thing that ever wrote the key was somebody
  remembering a git command. `--local` never `--global`; warns rather than fails.
- **`database-sentinel`'s loss is UNMITIGATED, and that is the recorded answer.**
  Task 3.9d allowed two answers and forbade a third. The replacement was to be a
  host deny rule; it is not expressible — the hook matched *content* anywhere in
  a Bash command, deny rules match a command *prefix*. Nothing intercepts
  `DROP TABLE` before it runs now, in any repository.
- **An empty declaration is not an absent one.** `check-shims.sh` read both
  through `sed 2>/dev/null`, so a deleted file and a clean fleet were the same
  empty string and both printed the conformance sentence. Distinguished before
  the read, since after it the information is gone.
- **husky removed from fbc-platform.** Its local `core.hooksPath` was what kept
  the floor out; unsetting it stops husky either way, and leaving husky
  installed-but-unbound is an executable hook that never runs. `ci.yml:24-25`
  already runs `pnpm lint` and `pnpm typecheck`, so what is lost is earliness.
  Lockfile regenerated and `--frozen-lockfile` verified, which CI depends on.
- **cparx's two instruction files reconciled by hand**, because `init-project.sh`
  correctly refuses to choose between two rule-sets. `AGENTS.md` was a copy of
  core **0.4.0** §11; `CLAUDE.md` restated the workflow and linked to deleted
  files.

## Next session: start here

**1. `ARTIFACTS` empties too, and nobody decided that.** It declares *only*
`database-sentinel`, so deleting the implementation leaves
`install-project-hooks.sh` with nothing to publish and the whole publish / shim /
check subsystem without a subject. 24 references across
`project-hook-shim.test.sh` and `install.test.sh` plus all of
`project-hooks.test.sh` are about that one artifact. **Decide whether the
subsystem is retired with it before deleting the file** — recorded on task 3.9b.
This is the largest open thread and it is a decision, not a cleanup.

**2. Publish `init-project.sh` 1.1.0.** `~/.agenticapps/bin/` still holds 1.0.0,
so anyone running the published copy gets an unenrolled project.

**3. Delete the transitional binder.** `reference-implementations/global-floor/`
and `tools/global-floor-bind.test.sh` exist for a migration that has happened and
cannot happen again here. Its one finding worth keeping first: **a repository
refused at the preflight is never enrolled, so binding the floor silences the
hook the refusal said it was keeping.** Reproduced with a failing test; the fix
is on the closed branch `feat/run-the-global-floor-migration`.

## Open

1. **Nothing intercepts destructive SQL any more.** See the decision above. If
   this matters, it needs a surface that covers more than one host — which is
   the argument that removed the old one.
2. **`.planning/` survives in cparx, fbc-platform and fx-signal-agent** (task
   6.2), untouched tonight.
3. **callbot and fx-signal-agent instruction files are collapsed but not
   thinned.** Both ~24k and likely restate the workflow the way cparx's did.
   Same editorial pass, one repo at a time.
4. **`normalize-claude-md` is specified but has no implementation anywhere** —
   `project-hook-binding/spec.md` names it as a live shim in seven places. It was
   failing open on every edit in five repos until tonight. Planned in
   `diagram-is-the-surface`, 0/46.
5. Tasks 3.1 / 3b.1 / 3b.4 of `one-enforcement-floor` are satisfied in fact but
   unticked, and 3.0a–3.0g describe a mechanism with no reason to exist.
   Reconcile before archiving.
6. `--check`'s half of 9.10 — now the only surface that would report a repository
   the floor does not reach. 9.5, 9.7, 9.8, 9.9, 9.12 open.
7. Stale `.clone/worktrees/agent-*` stubs in callbot and cparx; sandbox blocked
   the delete.
8. **2.6a**: `.planning/` was one name doing two jobs; the split is unrecorded.
9. `fx-signal-agent` has no `packageManager` pin.
10. Census inconsistencies CodeRabbit found on #90 — `proposal.md:71` ten/six vs
    eleven/seven, `planning-removal-inventory.md` 48/6 vs 50/4, GSD tree counts
    in `proposal.md:27` and `tasks.md:206`. MD040 fences in three docs.
11. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
    held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
12. `claude-workflow` cannot be deleted safely — 11 commits on no remote,
    `plan/28-split-01` 9 ahead, 1 stash. It is the provenance of every hook
    removed today and of the templates that seeded the forks.
13. `fleet-carries-only-current` task 0.1 was gated on `projects-bind-not-copy`
    being archived. It is now implemented but not archived — recheck.

## Mistakes worth not repeating

- **Ten commands became a spec round.** The binder refused the migration set on a
  correct ownership check; the right answer was to delete three files by hand.
  Instead: an adoption predicate, a spec delta, a design decision, a vendor
  review round, 15 test cases — generality for a one-time act on the only machine
  that has this workflow. The memory note `workflow-runs-on-one-machine` said so
  and was in context.
- **A measurement can be precise and about the wrong property.** Task 0.3a
  recorded nine hook sizes to the byte and never checked the ownership marker the
  removal code branches on.
- **My own first check reproduced the bug it was hunting.** `git rev-parse
  --git-common-dir` returns a *relative* `.git`, so three greps read core's own
  hook and agreed with the stale census. Resolve paths absolutely before
  asserting about another repository's files.
- **I checked hooks and enrolment and called it a machine-wide sweep**, having
  never looked in `.claude/`. The operator asked "did you check all repos?" and
  the answer was no. What was still running — database-sentinel in five repos —
  was one directory from where I was looking.
- **Two agents, one working tree.** Deletions in `fbc-platform` were silently
  undone by another Claude session mid-ticket on AGE-507; a `git stash`/`restore`
  inside its diff-review loop leaves no reflog entry, because neither moves HEAD.
  Check for live sessions before mutating a repository you are not working in.
