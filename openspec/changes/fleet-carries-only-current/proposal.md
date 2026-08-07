## Why

Three tools were removed in the last three weeks — GSD and GitNexus on
2026-07-28, `.planning/` on 2026-08-05, the wiki-builder on 2026-07-28 — and each
removal happened in core and in the global instruction files. **None of them
happened in the fleet's repositories.** The artifacts are still checked out, still
loadable, and in several cases still wired.

This is deliberately scoped as the change that comes *after*
`projects-bind-not-copy`. That one covers the two surfaces core declares — skills
core publishes, hooks `SHIMMED-HOOKS` names — and gives each a check. This one
covers everything else a repository accumulated, where no declaration exists to
compare against and so nothing has ever noticed.

Measured across the nine repositories that carry `openspec/`:

| What | Where |
|---|---|
| `setup-gstack-gsd-superpowers-workflow.md` — 133 lines offering to install GSD | `cparx` |
| `gsd-plan.md`, `setup.md`, `backend-foundation.md` | `callbot` |
| `.claude/workflow-config.md` — 101 lines of pre-OpenSpec workflow config | 7 repos |
| `.claude/claude-md/` — modular instruction fragments | 5 repos |
| `## Coding Discipline` inlined in `CLAUDE.md` (~80 lines) | 8 repos |
| `.claude/scheduled_tasks.lock` | 5 repos |
| `.planning/` | 9 repos, and **not one condition** — see below |

**`.planning/` is two different problems wearing one name.** In `cparx`,
`agenticapps-dashboard`, `fbc-platform` and `fx-signal-agent` it holds nothing
tracked or one stray `config.json` — leftovers. In **`agenticapps-roadmap` it
holds 134 tracked files**. That is a repository whose planning still lives there,
and deleting it is a migration decision, not a cleanup. Any change that treats
the two the same destroys the second while tidying the first.

## What Changes

- **BREAKING** for each repository swept: removed-tool artifacts are deleted —
  the GSD setup and plan commands, `workflow-config.md`, `scheduled_tasks.lock`,
  and untracked `.planning/` leftovers.
- **`## Coding Discipline` is removed from each `CLAUDE.md`** only where the
  trigger skill demonstrably carries the same rules. The skill absorbed §11
  precisely so the per-repo copies could go; a copy deleted before its
  replacement is verified to say the same thing is a rule deleted.
- **`agenticapps-roadmap`'s 134 tracked planning files are migrated or kept,
  never deleted as leftovers.** Which of the two is a decision this change makes
  explicitly and records.
- **A rule with a home**, so the next removal does not leave the same residue:
  a fleet repository carries no artifact of a tool the workflow has removed, and
  the removal of a tool includes the sweep.
- **The archived host repositories are out of scope.** `claude-workflow` (221
  tracked planning files), `codex-workflow` (150) and `opencode-workflow` (19)
  are deleted wholesale by Phase 5b. Cleaning a repository scheduled for deletion
  is work with a negative return.

## Capabilities

### New Capabilities

- `fleet-artifact-currency`: a fleet repository carries only artifacts of tools
  the workflow currently ships; removing a tool from core includes removing its
  artifacts from the fleet; and the two are not separated across releases. The
  general form of what `projects-bind-not-copy` establishes for the two declared
  surfaces.

### Modified Capabilities

_None._ `project-skill-binding` and `project-hook-binding` cover the declared
surfaces and are unchanged by this. Extending either to mean "and also anything
else stale" would make a precise rule vague.

## Impact

- **Nine repositories across two families**, plus a decision about a tenth
  (`agenticapps-dashboard-add-agent-board`, a worktree of a retired repo).
- **Depends on `projects-bind-not-copy`.** That change establishes the sweep
  pattern, the declared-fleet check and the both-directions pass. This one reuses
  all three rather than inventing a second mechanism, so it cannot start first.
- **`agenticapps-dashboard` is retired** and swept anyway, for the reason
  `projects-bind-not-copy` gives: a repository people are told to read is a
  repository an agent will open.
- **The `CLAUDE.md` edits are the risky part.** Deleting hook shims is
  mechanical; deleting instruction text is not, because the only evidence a rule
  still reaches an agent is that some file still says it.
