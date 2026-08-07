## Context

`install.sh` answers "how do I put this workflow on a machine". Nothing answers
"how do I use it with a repository". `workflow-installation` has thirteen
requirements and all thirteen are machine-side.

The old answer was the host scaffolders' migration chains — `claude-workflow` 34
migrations, `codex-workflow` 16, `opencode-workflow` 12, `pi-agentic-apps-workflow`
12. **All four repos are archived on GitHub**, and `install.sh` carries them in a
tombstone list whose symlinks it sweeps. The answer was retired without a
replacement being written.

Meanwhile the seven fleet repositories still carry what those chains installed:
`.claude/skills/` copies, `.claude/hooks/` shims, `claude-md/`,
`workflow-config.md`, `commands/`. Two in-flight changes remove the first two
categories. Nothing has said what should remain.

## Goals / Non-Goals

**Goals:**

- Define what a repository carries: `openspec/` and one instruction file.
- Provide an initializer that establishes exactly that and nothing else.
- Bind pi where pi reads, and require that a host's skill directory be evidenced.
- Sweep the seven existing repositories once.

**Non-Goals:**

- Deciding `spec/08`'s or PR #78's fate. This change makes that decidable by
  settling what onboarding is; it does not make the decision.
- Fixing omp. Recorded unverified — see Decisions.
- Writing global instruction files for any host. `install.sh` writes no host
  configuration and that stands.
- Generating CI workflow files. A repository may want the third enforcement
  surface; that is a separate choice with its own shape.

## Decisions

**The split is truth versus behaviour.** The repository carries what is true about
*it* — `openspec/specs/` is the product, not scaffolding, and no other machine can
supply it. The machine carries how to work, because a repository that carried
behaviour would carry a *version* of it, and versions in repositories are the
drift measured this morning: seven copies of one skill at three digests across two
claimed versions.

**One instruction file under two names.** `AGENTS.md` real, `CLAUDE.md` a symlink
to it. `AGENTS.md` is what codex, opencode, pi and omp read; `CLAUDE.md` is what
Claude reads. *Alternative rejected: two real files.* That is two versions of one
rule, which is the failure this workflow names everywhere else. Core already does
exactly this with its own `AGENTS.md`, and its stated reason — "one rule, one home
— so no host can read a different version of it" — is the whole argument.

**No global instruction file, though all five hosts support one.** Measured:
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
`~/.config/opencode/AGENTS.md`, `~/.pi/agent/AGENTS.md`, `~/.omp/agent/AGENTS.md`
are all supported paths; only the first exists here. So the reason not to use them
is not that they are unavailable — it is that behaviour there means five files in
five locations maintained separately, while the skill is one file symlinked into
all of them. Same reach, a fifth of the copies. *This corrects the repository's
own note that the workflow section "reaches one of five hosts" — it is one of five
populated, five of five supported, and the distinction changes the argument
without changing the conclusion.*

**pi's mapping is a defect, not a missing feature.** `workflow-installation`
already requires binding into "a host's skill directory"; `~/.agents/skills` is
not pi's. What was missing is any obligation to *establish* which directory that
is, which is why the defect survived: binding into the wrong directory succeeds,
and the resulting absence errors nowhere.

**omp is recorded unverified rather than fixed.** It is installed, shares pi's
mapping, and has no skill directory anywhere and no skill path in its config. The
temptation is to move it to `~/.omp/agent/skills` by symmetry with its documented
`AGENTS.md` path. Rejected: that is inference from one location, which is exactly
how this change's author concluded §13 was unused when three hosts bound it.
Unverified is a state the spec now has, and using it is cheaper than being wrong.

**The sweep is one operation, not a chain.** There are no versions to walk — the
scaffolders are archived and the target is a single shape. A chain exists to keep
"what does v1.3.0 look like on disk" single-sourced across versions; one target
state has no such problem.

**No `.archive/` copy.** The files are committed, so git already holds them and
`git revert` restores them. A retained copy inside the repository is a second
source of the thing being deleted. *Alternative rejected: archive then delete,*
which was the initial instinct and is worth naming because it feels safer and is
not — it produces the duplication whose removal is the point.

## Risks / Trade-offs

**The sweep runs before the floor exists and leaves repositories unprotected.** →
The sweep refuses unless both `projects-bind-not-copy` (skills) and
`one-enforcement-floor` (hooks) have landed. Stated as a precondition the sweep
checks, not as an ordering note.

**Correcting pi's mapping binds into a directory core did not create.**
`~/.pi/agent/skills` holds 25 per-skill symlinks written by something else on 16
July. Binding into it means core writes alongside another tool's links. → The
existing binding-state requirements already define every state a target can be in;
this adds no new state. But the co-tenancy is real and is recorded rather than
assumed benign.

**An initializer inside someone's repository is a higher-trust surface than a
machine installer.** → It is required to be short enough to read first, to write
only the two artifacts, and to touch no host configuration and no network.

**The instruction-file append could collide with an existing `AGENTS.md`.** →
Append behind a provenance marker, never rewrite. Where both files exist
independently and differ, refuse and report rather than choosing — collapsing them
decides which rule survives, and that is not the initializer's decision.

## Migration Plan

1. Correct pi's mapping and add the evidence obligation to the installer.
2. Record omp unverified; make the installer report unconfirmed bindings.
3. Build the initializer, RED first.
4. Verify a fresh clone works on all bound hosts with no per-repo step.
5. Sweep the seven repositories, gated on the two in-flight changes.

Rollback: `git revert` per repository for step 5; the installer changes are
ordinary reverts.

## Open Questions

1. **Where does the initializer live and what is it called?** Core has no
   project-side surface today, so there is no precedent. A subcommand of
   `install.sh` would overload a script whose header says it puts the workflow on
   a *machine*.
2. **Does a repository want a CI workflow file?** CI is the third enforcement
   surface and the only one that survives a machine without the workflow. It is
   out of scope here, but "a fresh clone needs nothing" is true only for the two
   local surfaces.
3. **Is omp's skill directory ever going to be establishable?** If omp reads no
   skills at all, binding it is meaningless and the mapping should be removed
   rather than corrected.
4. **What happens to `agenticapps-dashboard-add-agent-board`?** The stray worktree
   would be swept by a naive fleet loop. Named in `diagram-is-the-surface` as
   needing its own decision; it is a hazard for this change's sweep too.
