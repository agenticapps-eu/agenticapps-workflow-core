## Why

There is no answer to *"I checked out a repo — how do I use the workflow with it?"*

`install.sh` is the one entry point for a **machine**: it publishes the shared
artifacts, binds `skills/` into each host's skill directory, and installs the git
hook. `workflow-installation` carries thirteen requirements and every one of them
is about the machine. **Not one describes what a repository needs.**

What put the workflow into the seven fleet repositories was the host scaffolders'
migration chains — `claude-workflow` and its siblings. All four of those repos are
**archived on GitHub**, and `install.sh` names them in a tombstone list whose
symlinks it sweeps. So the mechanism that answered the question is gone and
nothing replaced it.

The answer this change writes down: **the repository carries its truth, the
machine carries the behaviour, and a fresh clone needs nothing.** `openspec/` and
one instruction file are committed, so they arrive with the checkout. Skills and
enforcement are machine-level, so they are already there if the workflow is
installed. Nothing is generated per-repo per-machine, which is what made the old
answer a 72-step chain.

**pi breaks that claim today, so it is fixed here.** `install.sh` binds pi to
`~/.agents/skills`; pi reads `~/.pi/agent/skills`, a real directory of per-skill
symlinks that something other than core populated. Core's skill is not among them.
"The machine carries the behaviour" is false for one of five hosts until that is
corrected, which makes it a precondition of this change rather than a neighbour of
it.

## What Changes

**A repository's workflow surface is defined, and it is two things**

- `openspec/` — created by `openspec init`, committed. It is the repository's
  durable truth, not scaffolding.
- One instruction file — `AGENTS.md`, with `CLAUDE.md` a symlink to it, appended
  to rather than overwritten when one already exists. `AGENTS.md` is the
  cross-host surface: codex, opencode, pi and omp all read it; Claude reads
  `CLAUDE.md`. One file, two names, so no host reads a different version.
- **Nothing else.** No skills, no hooks, no shims, no `workflow-config.md`, no
  `claude-md/` directory, no commands.

**A project initializer**

- One command, idempotent, that creates the two above and does nothing else.
  Small enough to read before trusting, per the same rule `install.sh` follows.

**pi is bound where pi reads**

- The host mapping is corrected from `.agents/skills` to `.pi/agent/skills`.
- **New requirement:** a host's skill directory is established by evidence that
  the host reads it, not by assumption. This is the discipline already applied to
  host *detection*; it was never applied to the *path*.
- **omp is recorded as unverified, not fixed.** It maps to `.agents/skills`,
  it is installed, and it has no skill directory anywhere and no skill path in
  its config — so there is nothing to check the mapping against. Asserting a fix
  here would repeat the §13 error of concluding from one location.

**The installer declares the prerequisites it actually has**

- `install.sh` declares **only git and bash**. `openspec` is a hard dependency —
  the gate cannot answer its one blocking question without it — and is never
  named. `installer-prerequisite-consent` names `openspec` as its worked example
  of a declared prerequisite; the installer that has the dependency does not
  declare it.
- `superpowers` is likewise depended on — core's skills invoke it — and likewise
  undeclared. It is a **Claude plugin** here and is installed per host in each
  host's own idiom, so it SHALL be declared and reported, never installed.
- Neither is a repository concern. `superpowers` needs no project init:
  `.superpowers/` is gitignored runtime state created on demand, and
  `docs/superpowers/` is work product rather than scaffolding.

**The seven existing repositories are swept once**

- Remove what the archived scaffolders installed; keep `openspec/`; write the
  instruction file. One migration, not a chain — there are no versions to walk.
- No `.archive/` copy. The files are committed, so git is already the rollback,
  and a second copy is the thing this effort deletes.

## Capabilities

### New Capabilities

- `project-onboarding`: what a repository carries to use this workflow, what it
  does not carry, and the one command that establishes it.

### Modified Capabilities

- `workflow-installation`: a host's skill directory is established by evidence
  rather than assumed, and pi's mapping is corrected accordingly.
- `installer-prerequisite-consent`: `openspec` and `superpowers` are declared
  prerequisites of `install.sh`, and a prerequisite owned by a host is reported
  rather than offered.

## Impact

- **`install.sh`** — the `HOSTS` mapping, one line, plus the evidence obligation.
- **New project initializer** — location to be decided in design; it is core's
  first project-side surface and the repo has no precedent for one.
- **Seven fleet repositories** — `.claude/skills/`, `.claude/hooks/`,
  `claude-md/`, `workflow-config.md`, `commands/` removed; `openspec/` kept;
  instruction file written.
- **`spec/08-migration-format.md` and PR #78** — this change settles their fate.
  If onboarding is `openspec init` plus one file, there is no chain to migrate and
  no consumer for an executable migration format. Named here, decided there.

**Sequencing.** The sweep depends on `projects-bind-not-copy` (skills) and
`one-enforcement-floor` (hooks) having landed — until both do, removing a repo's
skills and hooks removes protection with nothing bound in its place. Stated as a
hard precondition in tasks, not an ordering preference.
