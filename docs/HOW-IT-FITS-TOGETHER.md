# How it fits together

The machine-level view: five agents, where their files live, what binds them,
and what the installer does. **The loop itself is not here** — that is
`docs/WORKFLOW.md` and `workflow.mmd`. This document is the topology under it.

## One sentence

Five AI coding agents run on this machine, they should all follow the same
development workflow, and that workflow should live in exactly one place — this
repo — with every agent pointed at it by symlink, so `git pull` updates all five
at once.

Everything below is machinery for that sentence.

## The five hosts

A *host* is an agent CLI that reads skills.

| Host | Skill directory |
|---|---|
| claude | `~/.claude/skills` |
| codex | `~/.codex/skills` |
| opencode | `~/.config/opencode/skills` |
| pi | `~/.agents/skills` |
| omp | `~/.agents/skills` |

pi and omp share one directory, so five hosts need four directories.

**No host gets a hook, and every host is treated identically.** There is
deliberately no per-host branch anywhere in the binding path — the moment one
exists, the second is cheap. There were three host hook implementations; they
were removed, and why is below.

## The three places files live

Most confusion here comes from mixing these up.

**A — the checkout**, `agenticapps-workflow-core/`. The source of truth. Nothing
in it is "installed"; it is the master copy.

**B — the shared bin**, `~/.agenticapps/bin/`. Real copied files published from
A: `openspec-change-gate.sh`, `run-plan-review.sh`, `reviewer-cli.sh` and
`init-project.sh`. Those four are the whole set, and every one of them is
published by `install-shared-artifact.sh`.

A second, project-hook set used to be published beside them by its own attesting
installer, which also wrote `manifest.tsv` recording what was published at what
version. Both were retired on 2026-08-09 with the last artifact they carried.
Nothing read the manifest but its own test suite, and the version arbitration it
was assumed to underwrite lives in `install.sh`'s `check_artifact`, which
compares bytes against the checkout and never consulted it.

**C — the host directories**, `~/.claude/skills` and friends. Symlinks into A.
Never copies.

The rule: **executables are copied and version-arbitrated; skills are symlinked
and always current.** The executables are invoked by absolute path from many
projects and need arbitration; a skill copy is a fork nobody notices has forked.

## Skills — three kinds, and core owns two

`~/.claude/skills` holds ~99 entries. Core owns two of them.

**Core's own** (`skills/` in the checkout, host-neutral — no host name may
appear inside):

- `agentic-apps-workflow` — the trigger skill. The loop, the gates, the coding
  discipline, task-size routing. Self-activates on any code-touching task.
- `openspec-change-review` — step 2b. Runs ≥2 adversarial reviewers of *other*
  vendors over a change before code exists.

**Upstream skills core binds but does not own** — `cso`, `impeccable`, `qa`,
`database-sentinel`, gstack, superpowers. Never vendored. If one is absent the
workflow says so and continues: a missing upstream tool is reported, never
silently skipped and never a block.

**Host-prefixed copies** — `codex-cso`, `opencode-qa`, `codex-impeccable-audit`.
The archived host installers vendored copies of upstream skills and prefixed
them per host, which is the vendoring the workflow forbids. These are what the
installer's sweep exists to remove.

## Hooks — one gate, two surfaces

There is one gate, `openspec-change-gate.sh`. It fires at two points:

| Surface | When | Effect |
|---|---|---|
| git pre-commit | on `git commit` | blocks the commit |
| CI | on the pipeline | fails the build |

There used to be a third — a host hook before an Edit/Write tool call — and it
was removed. Three measurements decided it. With no active change the gate
returns satisfied, so the hook never enforced spec-before-code; the condition it
*did* enforce is caught again at `git commit` and again in CI; and it accounted
for every host-specific line in the repository — 27 installer lines, 293 in
`hosts/`, a consent flag and the `jq` dependency. The gate's own git hook makes
the argument in its header: a `PreToolUse` hook "is loaded at session start and
cannot gate the session that installed it, and it does not exist at all for a
human with an editor."

What was lost is in-session latency, and nothing else. A malformed spec delta
now surfaces at `git commit` rather than at the first `Edit`.

**The gate blocks on exactly one condition: `openspec validate --all` is not
green.** A blocked commit means a spec delta that does not parse — so fix the
delta. It never means "go get a review".

Review evidence — reviewer count, verdicts, independence, the trailer — is
computed and reported, never enforced. All of it produces `NOTE` lines. Two
rejections open the gate exactly as two approvals do. The escape hatch is
nothing — reviews do not block, so no escape hatch exists.

The consequence, stated in the trigger skill itself: **a green gate is the
weakest possible evidence that anyone read the delta.** Running the reviewers
before code is a discipline you keep, not one the machine keeps for you.

`OPENSPEC_GATE_STRICT=1` makes the gate block when there is *no* active change —
"no code without a change". It is off by default.

Projects bind the gate through a shim at `.claude/hooks/openspec-change-gate.sh`
resolving the published copy from `~/.agenticapps/bin/`. Core is the exception —
it resolves its own working-tree copy, so it scores the bytes it ships
(ADR-0028). That is the one self-hosting binder.

**This is mid-move.** `one-enforcement-floor` replaces the per-repository hook
install with a single machine-level binding via
`git config --global core.hooksPath`. Nine repositories on this machine carry
the gate today at four different byte sizes — one authority, nine copies, four
versions, and nothing reporting the divergence.

## Instruction files

**Global.** `~/.claude/CLAUDE.md` currently carries workflow rules. This is
known to be wrong and the file says so: it is behaviour, and it reaches one host
of five. It stays only until the trigger skill carries those rules, because
deleting a rule with no other home deletes the rule.

**Per-project.** One shared file plus one link per agent:

```
AGENTS.md                    exactly ONE workflow section, host-neutral
  frontmatter: agents: {codex: .codex/AGENTS.md, ...}
  .codex/AGENTS.md           only codex-specific content
  .opencode/AGENTS.md        only opencode-specific content
```

The only host-specific content an installer may write into the shared file is
one link per agent. Two copies of an instruction are not extra information —
they are the same instruction stated twice, and they drift.

In core, `AGENTS.md` is a symlink to `CLAUDE.md`. One rule, one home.

`tools/agents-md-conformance.sh` *checks* all of this and writes none of it.
That gap is why `--project` had to be deferred.

## The installer

One file, `install.sh`, at the repo root, capped at **228 executable lines** by
a specified requirement (it measures 210). You are being asked to let it write into your home
directory, and the honest basis for that trust is that you can read it.

```
./install.sh                  payload + core's git pre-commit hook. No host needed.
./install.sh --host claude    ...plus bind that host's skills. Repeatable.
./install.sh --host auto      ...for whichever hosts are installed.
./install.sh --check          report state, change nothing.
```

A full run, in order:

1. Publish the four executables to `~/.agenticapps/bin/` through
   `install-shared-artifact.sh`. That is the whole publishing step — the second
   delegation that published a project-hook set and attested it was retired on
   2026-08-09.
2. Install core's own git pre-commit hook.
3. Per host directory: remove legacy copied skill directories → sweep archived
   symlinks (rebind or remove) → bind core's two skills.
4. Scan for any archived binding that survived, and report it.

It writes **no** host configuration at any point — that is asserted by a test
against the files, not against the absence of the code that used to write
them.

**It is a front end.** It never writes a published file itself; it delegates to
installers that already carry version arbitration, downgrade refusal,
cross-process locking, atomic replacement, attestation, and git-hook resolution
that survives worktrees and `core.hooksPath`. A front end that reimplements its
back end acquires the back end's bugs without its fixes.

**One consent flag.** `--replace-unrecognised` grants "delete a directory that
may hold work". There were two — the other granted "edit the JSON your editor
reads" — and it went with the wiring. Passing it now is an unknown-argument
error rather than a silent no-op, so a script that still sends it fails loudly.

**Everything it replaces is preserved and the restore command printed.** Backups
of skills mirror out to `~/.agenticapps/pre-install/` rather than sitting in a
directory a host scans — a preserved skill is still a skill, and at least one
loader deep-scans nested `SKILL.md`.

## Updates

- **Skills: `git pull`.** They are symlinks into the checkout. There is no
  update step.
- **Executables: re-run `./install.sh`.** Each carries a
  `# <name>-version: X.Y.Z` marker and the publisher refuses to overwrite a
  higher version. A destination that is already newer is reported as *satisfied*,
  not skipped — calling it a failure would fail a correct machine.
- **Migration replay is gone.** The old `update-agenticapps-workflow` replayed
  numbered migrations from a host repo's `migrations/`. Core has no
  `migrations/`, so there is nothing to replay.
- **`--check` is the doctor.** Currency is judged by *content* against the
  checkout, not by version marker — a marker comparison reports a hand-edited
  file as current, which is the condition you run `--check` to find.

## The loop

Not restated here. `docs/WORKFLOW.md` is the prose and `workflow.mmd` is the
specification; the trigger skill is the same loop in operational form. If the
skill and the diagram disagree, the diagram wins.

## What is not finished

- **`--project` is dropped, not pending.** It needed a project-shim installer
  and an instruction-file provisioner. Once the floor is bound machine-wide
  there is no per-repository hook left for it to install, and what remained
  depends on the open question below. Its Phase 5b sequencing constraint is
  released.
- **The setup capability window is open on purpose.** This change removes
  `setup-agenticapps-workflow` before its replacement exists. The alternative
  was leaving a binding into an archived checkout, which is the condition the
  change exists to end.
- **Two skills are removed with no replacement** — `codex-design-critique` and
  `codex-spec-review`. No mapping was guessed; binding `design-critique` to
  `design-review` because the names rhyme is how a skill silently does the wrong
  thing.
- **`--check` reports a binding into an archived checkout as plain `bound`.** It
  does not run the archived-binding scan, which is install-mode only.
- **`workflow.mmd` still says the gate requires "REVIEWS ≥ 2".** Untrue since
  gate 2.0.0.

## Open design questions

Recorded because they are live, not because they are decided.

**Whether `AGENTS.md` still needs a workflow section.**
`host-neutral-instruction-files` requires exactly one whenever an agent is
provisioned, because a repo listing an agent without one is "pointed at a
workflow the file does not describe". If the trigger skill carries the workflow
and is installed globally, that premise weakens. It is deliberately not settled
by the hooks work — repealing a requirement as a side effect is how a rule
disappears without anyone deciding it should.

The live counter-evidence is worth keeping in view: the skill that loaded in the
session that wrote this document was the 402-line copy from an **archived**
checkout, not core's 235-line v4.0.0. A workflow that lives only in a skill is
exactly as reliable as skill resolution, and skill resolution picked the wrong
file that day.

**Whether a global instruction file could replace per-project installation.**
`~/.codex/AGENTS.md` is a real Codex mechanism (the audit deleted this machine's
copy because its only line was dead, not because the path is unsupported), and
opencode reads `~/.config/opencode/rules/`, which currently holds one leftover
file. The 2026-08-05 audit recorded "no global instruction file at all" for
opencode, pi and omp; that is accurate about the `AGENTS.md` paths it probed and
should not be read as establishing that the hosts lack the concept.
