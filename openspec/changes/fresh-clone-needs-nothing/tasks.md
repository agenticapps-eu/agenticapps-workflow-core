## 1. Bind pi where pi reads

A defect against the existing requirement that skills are bound into "a host's
skill directory". `~/.agents/skills` is not pi's.

- [ ] 1.1 Record the evidence before changing the mapping: pi reads
      `~/.pi/agent/skills` (a real directory holding 25 per-skill symlinks into
      `../../../.agents/skills/`, written 16 July by something other than core),
      and `agentic-apps-workflow` is absent from it while present in
      `~/.agents/skills`
- [ ] 1.2 RED: a check asserting pi resolves the workflow skill. It fails today
- [ ] 1.3 Correct `install.sh`'s `HOSTS` entry from `pi:.agents/skills:pi` to
      `pi:.pi/agent/skills:pi`
- [ ] 1.4 GREEN: pi resolves `agentic-apps-workflow`. **Confirm by resolution,
      not by the symlink existing** — the symlink existed all along, in the wrong
      directory, which is why this went unnoticed
- [ ] 1.5 Record the co-tenancy: core now writes symlinks alongside another
      tool's 25. Check the existing binding-state requirements cover it; they
      should, but say so rather than assume
- [ ] 1.6 **omp: record unverified, do not change.** It is installed
      (`~/.bun/bin/omp`), shares pi's old mapping, has no skill directory at
      `~/.omp/agent/skills` or anywhere else, and names no skill path in
      `~/.omp/agent/config.yml`. Moving it to `~/.omp/agent/skills` by symmetry
      with its documented `AGENTS.md` path is inference from one location — the
      §13 error. Report it as unconfirmed
- [ ] 1.7 Implement the evidence obligation: the installer reports a binding as
      unconfirmed when nothing establishes the host's skill directory, and does
      not count it toward success

## 2. Declare the prerequisites the installer actually has

- [ ] 2.1 `install.sh` declares only `git` and `bash`. That is the tier-1
      hard-fail rule, not the declaration set. Add `openspec` and `superpowers`
      as declared prerequisites
- [ ] 2.2 Report `openspec` when absent, stating that the gate's one blocking
      condition cannot be evaluated without it. Offering it through npm is
      permitted by the existing consent rules — it is the
      `@fission-ai/openspec` case the capability already names
- [ ] 2.3 Report `superpowers` when absent, per detected host, with that host's
      own install command. **Never install it**, opt-in flag or not: it is a
      Claude plugin here, a git install on pi, and something else elsewhere
- [ ] 2.4 Do not report a single presence for `superpowers` across hosts — per-host
      installs succeed and fail per host

## 3. RED: the initializer

- [ ] 3.1 RED: running the initializer in a bare repository produces `openspec/`
      and `AGENTS.md`, with `CLAUDE.md` a symlink to it, and nothing else
- [ ] 3.2 RED: running it twice changes nothing the second time — no duplicated
      section, no re-created symlink, no re-initialized `openspec/`
- [ ] 3.3 RED: an existing `CLAUDE.md` with content keeps every line, and the
      workflow section is appended behind a provenance marker
- [ ] 3.4 RED: both files existing independently with different content is
      reported and refused, not silently collapsed
- [ ] 3.5 RED: it writes no host configuration, no hook, no skill, no CI workflow
      file, and makes no network call
- [ ] 3.6 A test suite against a scratch repository — no case touches a real one
- [ ] 3.7 RED: only `CLAUDE.md` exists as a regular file → its content becomes
      `AGENTS.md` and `CLAUDE.md` becomes a symlink. **Assert the negative too:**
      no run ever leaves two regular instruction files, which is what appending to
      `CLAUDE.md` and creating `AGENTS.md` separately would do
- [ ] 3.8 RED: both exist byte-identical → collapse to the symlink; `CLAUDE.md` is
      a symlink elsewhere → refuse without following it; either name is a
      directory or a dangling link → refuse
- [ ] 3.9 RED: the section is written behind the markers
      `host-neutral-instruction-files` makes normative, and their presence is what
      makes a second run a no-op. No marker of this change's own
- [ ] 3.10 RED: `openspec` absent → refuse before writing anything. Reachable by
      design, since this change makes `openspec` a reported, non-blocking
      prerequisite
- [ ] 3.11 RED: invoked from a subdirectory → resolves the repository root; no
      second `openspec/` beside the first; every target preflighted before the
      first write

## 4. Build the initializer

- [ ] 4.1 Write it at `reference-implementations/init-project/init-project.sh`,
      carrying an `init-project-version:` marker line — decided; it is published
      like the gate rather than added as an `install.sh` subcommand
- [ ] 4.1a Publish it from `install.sh`: one `ARTIFACTS` line,
      `init-project/init-project.sh:init-project-version`. Through the arbitrating
      helper, never by copy — `workflow-installation` already requires this of any
      published executable that is not a project hook
- [ ] 4.1b Do **not** add `~/.agenticapps/bin` to `PATH`. It is not on it today and
      putting it there means writing shell configuration, which `install.sh`
      refuses. Onboarding documents the absolute path
- [ ] 4.1c Confirm `--check` reports the initializer like the other artifacts, and
      that installing twice leaves one copy at one version
- [ ] 4.2 Implement to pass §3, and no further
- [ ] 4.3 Short enough to read before trusting. It runs inside someone's
      repository against files they already own, which is a higher-trust surface
      than the machine installer
- [ ] 4.4 Write the workflow section it appends. It is a pointer to the trigger
      skill plus whatever is genuinely repository-specific — not a copy of
      behaviour, which is the drift this whole effort removes

## 5. Verify a fresh clone needs nothing

- [ ] 5.1 On a machine where `install.sh` has run: clone a repository carrying
      `openspec/` and its instruction file, and confirm the workflow is usable
      with no per-repository step
- [ ] 5.2 Confirm per host, not once. Claude, codex, opencode and pi — the
      measurement on 2026-08-07 proved hosts differ, and one loader validates one
      host
- [ ] 5.3 Confirm the negative: `openspec/` remains readable as the repository's
      specification on a machine *without* the workflow, and the missing
      enforcement is reported as the machine's condition

## 6. Sweep the seven existing repositories

- [ ] 6.0 **The sweeper is its own artifact, not a mode of the initializer.** The
      initializer writes two files and removes nothing; folding removal into it
      breaks its "does only what this capability names" requirement
- [ ] 6.1 **Hard precondition, checked by effect:** the skill resolves for the
      host in use and the enforcement floor is active *for the repository being
      swept*. Do not check whether `projects-bind-not-copy` or
      `one-enforcement-floor` is merged — that is a fact about core's history, not
      about the machine the sweep is running on
- [ ] 6.1a Refuse on a repository whose worktree is not clean. `git revert`
      restores committed files and nothing else, so an unclean sweep is an
      irreversible one
- [ ] 6.1b Remove only from an **exact manifest** of artifacts this workflow
      published. Anything else in a scheduled path is a refusal, not a deletion
- [ ] 6.1c Act on the enumerated seven. **No directory glob** — a glob over the
      family directory reaches the stray worktree in 6.8
- [ ] 6.2 Remove `.claude/skills/` (core-published names only), `.claude/hooks/`,
      `claude-md/`, `workflow-config.md`, `commands/`
- [ ] 6.3 **Keep `openspec/`.** It is the repository's truth, and the one thing
      here that no other machine can supply
- [ ] 6.4 Keep the six `openspec-*` skills. Core does not publish them; they are
      installed per-project by the openspec CLI and deleting them breaks
      `/opsx:*`
- [ ] 6.5 Write the instruction file per §3–§4
- [ ] 6.6 **No `.archive/` copy.** The files are committed, so git is the
      rollback. A retained copy is the duplication this change removes
- [ ] 6.7 One commit per repository, so `git revert` restores it cleanly
- [ ] 6.8 **`agenticapps-dashboard-add-agent-board` is a stray worktree** carrying
      its own gate and conformance harness. A naive fleet loop would sweep it.
      Exclude it explicitly and record why

## 7. Settle what this makes decidable

- [ ] 7.1 Record that onboarding is `openspec init` plus one instruction file, so
      there is no chain to migrate and no consumer for an executable migration
      format. `spec/08` and PR #78 are decided against this, not here
- [ ] 7.2 Correct the claim — in this repository and in the global instruction
      file — that the workflow section "reaches one of five hosts". Measured
      2026-08-07: **five of five hosts support a global instruction file**
      (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
      `~/.config/opencode/AGENTS.md`, `~/.pi/agent/AGENTS.md`,
      `~/.omp/agent/AGENTS.md`); one of five is populated. The conclusion stands
      on the one-copy argument, but not on the stated reason
- [ ] 7.3 Record that superpowers needs no project init: `.superpowers/` is
      gitignored runtime state and `docs/superpowers/` is work product

## 8. Verify

- [ ] 8.1 `openspec validate --all --strict` green
- [ ] 8.2 The installer's own test suite passes with the corrected pi mapping
- [ ] 8.2a **Observe pi resolving the skill**, and record the observation. Until
      that exists, pi is *corrected but unconfirmed* — the current evidence is that
      `~/.pi/agent/skills` holds symlinks, which is directory presence, the thing
      this change's new requirement refuses as evidence
- [ ] 8.2b Confirm a name collision in pi's shared directory is reported and the
      other tool's entry is left intact
- [ ] 8.3 A swept repository contains exactly `openspec/`, the instruction file,
      and the six `openspec-*` skills — nothing this workflow publishes
- [ ] 8.4 `git revert` of a sweep commit restores a repository, with no archived
      copy consulted
