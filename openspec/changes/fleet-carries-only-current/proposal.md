## Why

Three tools were removed in the last three weeks — GSD and GitNexus on
2026-07-28, the wiki-builder on 2026-07-28 — and the `.planning/` directive on
2026-08-05. Each removal happened in core and in the global instruction files.
**None of them happened in the fleet's repositories.** The artifacts are still
checked out, still loadable, and in several cases still wired.

> **Correction, 2026-08-08 — the load-bearing fact was wrong.** Every earlier
> revision of this change said `.planning/` was "removed fleet-wide on
> 2026-08-05". It was not, and the change's own inventory contradicted it. What
> was removed that day was the **directive** — the instruction text telling
> agents to plan there. The directories were never touched, which is precisely
> the residue this change exists to clean up. The same false claim was carried
> in the global `~/.claude/CLAUDE.md` and was cut from it on 2026-08-08.

This is deliberately scoped as the change that comes *after*
`projects-bind-not-copy`. That one covers the two surfaces core declares — skills
core publishes, hooks `SHIMMED-HOOKS` names — and gives each a check. This one
covers everything else a repository accumulated, where no declaration exists to
compare against and so nothing has ever noticed.

Measured 2026-08-08, after both retired checkouts came off the machine:

| What | Where |
|---|---|
| `setup-gstack-gsd-superpowers-workflow.md` — 133 lines offering to install GSD | `cparx` |
| `gsd-plan.md`, `setup.md`, `backend-foundation.md` | `callbot` |
| `.claude/workflow-config.md` — 101 lines of pre-OpenSpec workflow config | up to 7 repos, re-count pending |
| `.claude/claude-md/` — modular instruction fragments | up to 5 repos, re-count pending |
| `## Coding Discipline` inlined in `CLAUDE.md` (~80 lines) | up to 8 repos, re-count pending |
| `.claude/scheduled_tasks.lock` | up to 5 repos, re-count pending |
| `.planning/` | 10 repos — see the table below |

The four "up to" rows were counted on 2026-08-07 across a fleet that still
included `agenticapps-dashboard` and `agenticapps-roadmap`. Each is an upper
bound until task 1.1 re-runs it.

## `.planning/` goes entirely

`.planning/`, measured 2026-08-08:

| Repository | tracked | untracked | gitignored |
|---|---:|---:|---:|
| `claude-workflow` | 221 | 32 | yes |
| `codex-workflow` | 150 | 5 | yes |
| `opencode-workflow` | 19 | 6 | yes |
| `pi-agentic-apps-workflow` | 0 | 9 | yes |
| `fbc-platform` | 1 | 10 | yes |
| `fx-signal-agent` | 1 | 4 | yes |
| `agenticapps-workflow-core` | 0 | 10 | yes |
| `cparx` | 0 | 6 | yes |
| `stimmung` | 0 | 7 | **no** |
| `neuroflash/mcp-server` | 0 | 5 | **no** |

The first four are host repositories, out of scope below. **In the six that
remain, `.planning/` is deleted outright — tracked and untracked alike.**
Planning lives in `openspec/` now; there is no second home for it and no reason
to keep a directory that only ever collects stale copies of what
`openspec/changes/` already holds.

An earlier revision carried a whole requirement protecting tracked `.planning/`
content from the sweep. It was written around `agenticapps-roadmap`'s 134
tracked files — a repository whose checkout was deleted on 2026-08-07. What it
would protect today is two files. **The requirement is dropped and the
disposition is simply: delete.**

Two things are recorded rather than guarded against, because the operator asked
for the deletion knowing them. `stimmung` and `neuroflash/mcp-server` hold
untracked content that is **not gitignored** — the one shape that has no copy
anywhere, so deleting it is unrecoverable. Task 2.6 lists every file before
removing any. And the directories will stay deleted only because their writer
is already dead: `meta-observer`, the `SessionEnd` hook that wrote
`.planning/skill-observations/` in every repository opened, lives in
`agenticapps-dashboard/packages/meta-observer/`, which came off the disk on
2026-08-07. Its registration in `~/.claude/settings.json` still points at the
deleted path and fires on every session end. Task 2.7 unregisters it.

## What Changes

- **BREAKING** for each repository swept: artifacts of removed tools are deleted
  — the GSD setup and plan commands, `workflow-config.md`,
  `scheduled_tasks.lock`, and `.planning/` in full.
- **`## Coding Discipline` is removed from each `CLAUDE.md`** only where the
  trigger skill demonstrably carries the same rules, rule by rule. The skill
  absorbed §11 precisely so the per-repo copies could go; a copy deleted before
  its replacement is verified to say the same thing is a rule deleted. Skill
  4.0.0 carries it, and core's own global file was cut against it on 2026-08-08
  — that is the procedure, performed once.
- **A declaration of what each removed tool owned**, append-only, because
  "remove that tool's artifacts" is not implementable from the tool's name.
- **A preservation category**, so a repository that *was* a removed tool's
  product can keep its own source without the invariant becoming unsatisfiable.
- **A sanctioned intermediate state**, because one PR per repository guarantees
  a window where some are swept and some are not.
- **A rule with a home**, so the next removal does not leave the same residue:
  a fleet repository carries no artifact of a tool the workflow has removed.

## Capabilities

### New Capabilities

- `fleet-artifact-currency`: a removed tool declares the artifacts it owned; a
  declared repository holds none of them unless a recorded preservation entry
  says why; a multi-repository removal has a defined completion; and instruction
  text is cut only against a named, reachable replacement. The general form of
  what `projects-bind-not-copy` establishes for the two declared surfaces.

### Modified Capabilities

_None._ `project-skill-binding` and `project-hook-binding` cover the declared
surfaces and are unchanged by this. Extending either to mean "and also anything
else stale" would make a precise rule vague.

## Impact

- **Six repositories in scope**, across two families. Both retired repositories
  this used to sweep — `agenticapps-dashboard` and `agenticapps-roadmap` — were
  deleted from the machine on 2026-08-07, so there is nothing local left to
  sweep in either. Their GitHub copies are archived and read-only; both were
  archived on 2026-08-05, which is the source for the retirement this change
  used to cite without one.
- **The four host repositories are out of scope.** `claude-workflow` (221
  tracked planning files), `codex-workflow` (150), `opencode-workflow` (19) and
  `pi-agentic-apps-workflow` (0) are deleted wholesale by **Phase 5b of the
  core-collapse plan — the step that removes the archived host checkouts from
  the machine**. Cleaning a repository scheduled for deletion is work with a
  negative return, and nothing should be *fixed* in them in the meantime either.
- **Depends on `projects-bind-not-copy`.** That change establishes the sweep
  pattern, the declared-fleet check and the both-directions pass. This one reuses
  all three rather than inventing a second mechanism, so it cannot start first.
  Enforcement of the new requirements lands in that check's second pass, and
  tasks 5.1–5.3 are what extend it.
- **The `CLAUDE.md` edits are the risky part.** Deleting hook shims is
  mechanical; deleting instruction text is not, because the only evidence a rule
  still reaches an agent is that some file still says it.
