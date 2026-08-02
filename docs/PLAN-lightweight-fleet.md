# Plan — make the workflow small enough to stop working on

**Written 2026-07-28**, after a day in which the workflow produced four gate
versions, twelve re-vendor PRs, two ADRs and a spec change — and zero product
features.

## The problem, stated plainly

The workflow has become the project. It is 987 / 274 / 127 / 74 files across
four hosts, 77 migration documents, three conformance harnesses, and a 19-section
spec — most of which exists to describe, propagate and verify itself.

Every core change costs a PR train because four hosts hold byte-copies, and
seven projects hold copies of the templates. ADR-0023 and ADR-0024 diagnose this
correctly, but **their remedy is more machinery**, and more machinery is the
disease.

## The one measurement that reframes it

Projects do not read a host's copy of anything. Their hook is seven lines that
`exec` `~/.agenticapps/bin/`. So on this machine:

```
install -m 0755 <core>/reference-implementations/.../openspec-change-gate.sh \
                ~/.agenticapps/bin/openspec-change-gate.sh
```

…makes a gate change live in **every project immediately**. No host PR, no
migration, no re-vendor. That is how the reviewer floor (spec 1.1.0 / gate
1.4.0) shipped: one command, verified through callbot's untouched shim.

**Re-vendoring to four hosts buys exactly two things**: fresh installs on other
machines, and CI drift checks. For a single-operator fleet, both are theoretical
most of the time.

## Principles for everything below

1. **Deletion beats construction.** Prefer removing a thing over building a
   mechanism to maintain it cheaply.
2. **No PR trains.** If a change needs coordinated PRs across four repos, the
   design is wrong — fix the design, or accept the change is not worth making.
3. **The shared bin is already the binding mechanism.** Use it. Do not invent a
   second one.
4. **Migrations are a symptom.** OpenSpec has none: it owns little in the
   project and its `init` is idempotent. Copy that, do not out-engineer it.

## Steps, in order of relief per unit of effort

### 1. Kill knowledge-capture — LIVE surfaces only  *(small, do now)*

Spec §15 is already removed in core (spec 1.2.0), ADR-0017 superseded.

Remaining: **54 live surfaces** across four hosts (11 / 33 / 7 / 3), 6 project
`config.json` blocks, 6 project SKILL.md ritual tails, 8 `skill-observations/`
directories (198 files, only 8 tracked — in codex-workflow).

**Do not touch the 32 references inside `migrations/`.** Those are historical
executables replayed for repos on old versions; editing them rewrites the past
and breaks replay (the ADR-0023 lesson, learned the hard way today).

Vault notes in `~/Obsidian/…/44 Agentic Coding Learnings` (12 notes) are left
alone. Nothing will read or write them.

This is a one-time deletion. Deletions do not recur, so they do not justify
building infrastructure first.

### 2. Stop re-vendoring. Publish instead.  *(zero effort, do now)*

For any core artifact change: `install` it into `~/.agenticapps/bin/` and it is
live. Open host PRs **only** when preparing another machine or a release —
not per change.

The version arbiter already prevents an older host installer from clobbering a
newer shared copy, so hosts drifting behind is safe, not urgent.

Accept that host CI drift checks go red between a core change and an eventual
re-vendor. That red is informational, not a defect.

### 3. Make projects carry almost nothing  *(the real lever)*

> **Step 3a — hooks — DONE, 2026-08-02.** `shim-project-hooks`, ADR-0029. The
> seven projects went from eight vendored hooks each to three (two in
> `agents-task-viewer`, which keeps a documented opt-out): five hooks deleted,
> two shimmed, and the change-gate shim migrated onto the same contract.
> Executable hook logic per project fell 351 → 102 lines, byte-identical
> everywhere; fleet total 4,396 → 1,944, net −1,877 after +575 to core.
>
> Two live defects were fixed on the way: `design-shotgun-gate` blocked every
> `.tsx`/`.css` edit in `callbot` and `fbc-platform`, and a `migrations/` clause
> blocked every migration edit in **six** of the seven, both on sentinels no
> surviving command writes.
>
> `claude-workflow` was updated in the same change, or the next
> `/setup-agenticapps-workflow` would have handed a new project every hook the
> fleet had just deleted.
>
> **Carried, not closed:** the fail-open report's channel is unverified — a live
> probe showed the shims run and allow, but the exit-1 notice reached neither the
> agent nor the stream-json surface. See ADR-0029's last consequence.
>
> **Still open in step 3:** the four copies of core content per project —
> `.claude/claude-md/workflow.md`, `.claude/workflow-config.md`, the vendored
> `SKILL.md`, and the embedded §11 block. Hooks were the easy third.

Today each project carries `.claude/claude-md/workflow.md`,
`.claude/workflow-config.md`, a vendored `SKILL.md`, and an embedded §11 block —
four copies of core content per project, 20+ across the fleet, and the reason
migration 0033 existed at all.

`~/.claude/CLAUDE.md` is loaded in every session of every project. Central rules
belong there **once**. A project should carry only: its own `CLAUDE.md` prose,
its `openspec/` slot, and the seven-line hook shim.

**When projects carry nothing, migrations become unnecessary** — there is
nothing in a project left to migrate. That is what retires the 77 migration
documents, not a better migration runner.

Cost, stated honestly: rules stop being repo-portable. A teammate cloning
callbot must run the installer. Same bargain as any toolchain, but it is a
choice, not a free win.

### 4. Decide whether four hosts are needed  *(biggest lever; only you can call it)*

Since gate 1.2.0 the claude / pi / opencode payload shapes are handled inside
**one** canonical script. `bind-openspec-v1` is nonetheless implemented three
times as three separate ~20k documents.

If codex / opencode / pi are not in daily use, archiving them removes three
migration chains, three installers, three CI configs and three quarters of the
propagation problem — at a stroke, with no new machinery.

If they are needed, then ADR-0024's `host.json` is the right shape and step 3
should land first, because a thin project makes a thin host almost automatic.

### 5. Trim the spec  *(after 3 and 4)*

Nineteen sections, several describing machinery that steps 1–4 remove. A spec
section that no longer has an implementation is a maintenance obligation with no
payer.

**§02's GSD vocabulary is the root cause this step owns**, and step 3a named it
rather than fixing it. GSD was removed on 2026-07-28; §02 still describes its
gates in its terms, which is why a hook could share a name with a §02 gate
(`design-shotgun-gate`) while that gate's actual binding was a gstack skill, and
why the deletions had to be argued from what the host instruction file binds
rather than from §02's own list. Two further inheritances found while clearing
the hooks, both recorded and deliberately left for this step:

- `normalize-claude-md`'s `profile` branch still emits
  `Run /gsd-profile-user to generate` into `CLAUDE.md` — a remedy naming a
  command removed with GSD.
- The same hook rewrites `CLAUDE.md` to **link into `.planning/`**, the
  directory fleet policy designates frozen archive. It only reads, so it breaks
  no rule, but it points the live instruction file at frozen history.

See `reference-implementations/project-hooks/README.md`, "Audit: other checks
with dead preconditions".

## What NOT to do

- **Do not build the migration-chain-in-core** (ADR-0024 step 3) before step 3
  here. If projects carry nothing, that work is unnecessary; doing it first
  builds a better engine for a car being scrapped.
- **Do not finish the pinning rollout** (ADR-0023) as a priority. It optimises
  re-vendoring, and step 2 says stop re-vendoring per change. The resolver is
  built and harnessed; leave it for when a second machine actually needs it.
- **Do not add conformance rows for things being deleted.**

## Immediate next actions

1. Step 1 — delete knowledge-capture's live surfaces (hosts, projects,
   `skill-observations/`).
2. Step 2 — already in effect; gate 1.4.0 published, floor live fleet-wide.
3. Answer the step 4 question: are codex / opencode / pi live?

Everything else waits until the answer to (3) is known, because it changes how
much of steps 3 and 5 is worth doing at all.
