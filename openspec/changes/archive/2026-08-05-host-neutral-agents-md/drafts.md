# Source material and drafts — tasks 2.1–2.6

Working notes for task group 2. The spec text in group 3 is written from
this file; this file is archived with the change and is not itself normative.

## Source: the live templates, not the cparx blocks

The two cparx blocks the proposal quotes were deleted by cparx PR #125. The
templates that *wrote* them are still on disk and are what a fresh install lays
down today, so they — not the deleted copies — are what task 2.3 means by
"what the workflow actually does today":

- `codex-workflow/skills/setup-codex-agenticapps-workflow/templates/agents-md-additions.md`
- `opencode-workflow/skills/setup-opencode-agenticapps-workflow/templates/agents-md-additions.md`
- `pi-agentic-apps-workflow/templates/pi-md-sections.md`

All three open with the *same* marker, `agentic-apps-workflow sections`. That is
the mechanism of the duplication: two hosts writing the same marker into one
file, neither looking first.

| | codex | opencode | pi |
|---|---|---|---|
| Lines | 134 | 103 | 131 |
| §11 canonical block | absent (region-aware placement, codex ADR-0010) | present | present |
| Workflow prose | full: 16-row gate table, task-size routing, plan-review runbook | pointer | OpenSpec lifecycle + pointer |
| Session handoff | full protocol inline | pointer | pointer |
| Planning front end | GSD | none named | OpenSpec |

**Three copies in three different states of decay.** This is stronger evidence
than the cparx pair, which only showed two copies of one generation drifting
apart. Here each copy is stalled at a different point in the workflow's own
history, and no copy is correct:

- **codex** is pre-§12 and pre-OpenSpec. It carries the full gate table,
  routing, handoff protocol and plan-review runbook eagerly — the exact content
  §12 "Instruction-surface economy" (0.10.0) says belongs in the lazily-loaded
  trigger skill. It is the only one still citing GSD.
- **opencode** is slimmed per §12 but names no planning front end at all, so a
  project set up from it learns nothing about how work moves.
- **pi** is the only one describing the OpenSpec lifecycle, and it is the only
  one carrying a *false* statement of the gate (see 2.2 below).

The proposal's claim that "the second copy exists only to disagree with the
first" holds, and generalises: every copy disagrees with every other copy, and
the disagreements track when each host last adopted rather than anything about
the host.

## 2.1 — The host-neutral section body

§12 "Instruction-surface economy" already fixes the membership question, so the
body is not a merge of the three copies — it is the small thing §12 says the
always-loaded file should contain, with every host name removed:

1. The **§11 canonical block**, verbatim, near the top per the placement
   advisory. Identical in opencode and pi today; codex places it regionally, so
   its absence there is conformant, not drift.
2. A **short workflow pointer**: the project uses the AgenticApps spec-first
   OpenSpec workflow; the trigger skill activates on code-touching tasks, emits
   the commitment ritual, and carries the gate bindings, task-size routing and
   session-handoff protocol — read them there, not here.
3. The **OpenSpec lifecycle**, host-neutrally: propose → `openspec validate
   --all` → change review → apply (TDD) → two-stage code review → verify →
   archive → ship. Named as steps, not as any host's invocation syntax.
4. A **gate statement** that is true today (2.2).
5. A **pointer to the durable spec**, `agenticapps-workflow-core`.
6. The **per-agent links** (shape settled by 2.5).

Everything else in all three templates — the 16-row gate table, the task-size
routing table, the handoff format, the plan-review runbook — moves to or stays
in the trigger skill. That is not a new decision; §12 already says so at
SHOULD level. This change makes the *shared file* the place it binds.

## 2.2 — GSD references removed, and a second stale claim found

GSD was deleted fleet-wide on 2026-07-28. Only the **codex** template still
cites it, in four places: the `/prompts:gsd-*` prompts in the routing list, the
"GSD ... bound from upstream" sentence, the `gsd-debug` aside, and
`.planning/config.codex.json`. None can survive into canonical text.

The `GSD_SKIP_REVIEWS` env var is the one GSD-named thing that stays. It is the
live escape hatch — §18 keeps the name for compatibility (`spec/18`, line 235)
— so it is a name, not a reference to the deleted system.

**A second stale claim, not recorded in the proposal.** The pi template states:

> No code edits until the active change validates AND carries
> `openspec/changes/<name>/REVIEWS.md` with ≥ 2 external reviewers. This is
> enforced, not requested.

That has been false since gate 2.0.0. `spec/18-retargeted-change-gate.md`
(v1.5.0, line 21): review state is **"reported, never enforced"**; the gate
blocks on a red `openspec validate --all` and on nothing else. The same stale
claim was corrected in all seven projects' gate shims on 2026-08-02 by
`shim-project-hooks` — and it survived here, in the template that provisions new
projects, which is where it would have been re-seeded into the eighth.

The canonical text therefore states the gate as: **blocks on validation, reports
on review.**

This matters beyond the wording. It is a second instance of the failure this
change exists to fix — a correction applied to every consumer while the producer
kept the original error — and it was found only because the templates were read
side by side.

## 2.3 — The drifted step names

The proposal frames this as `gsd-execute-plan` vs `gsd-execute-phase`, one step
under two names, needing a winner. Resolved against today's workflow: **neither
name survives, and the question dissolves.** GSD is gone, and the step it named
has no successor under that shape — phases were replaced by changes. The
equivalent step is now `apply` in the OpenSpec lifecycle (`/opsx:apply` on
Claude and Pi, `$`-prefixed on Codex), which is precisely the kind of
host-specific invocation syntax that 2.4 sends to the host's own file.

So the canonical text names the **step**, `apply`, and never an invocation. That
is the general rule the scenario "Invocation syntax differs between agents" in
`host-neutral-instruction-files` already states; this is the worked instance.

## 2.4 — The host-specific values: the count holds, the membership does not

The proposal identified four: binding repo, host config path, skill invocation,
prompt invocation. Extracting every value that actually differs across the three
templates gives six:

| Value | codex | opencode | pi |
|---|---|---|---|
| Binding repo | `codex-workflow` | `opencode-workflow` | `pi-agentic-apps-workflow` |
| Host directory | `.codex/` | `.opencode/` | `.pi/` |
| Version stamp | `.codex/workflow-version.txt` | `.opencode/workflow-version.txt` | `version:` in `.pi/skills/agentic-apps-workflow/SKILL.md` |
| Workflow config | `.planning/config.codex.json` | `.planning/config.json` | `.planning/config.json` |
| Session handoff | `.codex/session-handoff.md` | `.opencode/session-handoff.md` | `.pi/session-handoff.md` |
| Invocation syntax | `/prompts:…`, `codex-*` skills | `…` | `/opsx:…` |
| Trigger-skill install root | `${CODEX_HOME:-$HOME/.codex}` | — | — |

Two corrections to the proposal's four:

- **"Skill invocation" and "prompt invocation" are one axis, not two.** They
  differ per host in the same way and are recorded in the same place.
- **Three of the six are not independent values.** Version stamp, workflow
  config and session-handoff path all derive from the **host directory**. Given
  `.codex/`, all three follow.

Reducing to genuinely independent values gives **four** — the count the proposal
claimed, with different membership:

1. **Host directory** (`.codex/` | `.opencode/` | `.pi/`)
2. **Binding repo** name and URL
3. **Invocation syntax** for skills, prompts and slash commands
4. **Trigger-skill install root** — the one path *not* under the repo's host
   directory

The host directory **bounds** the version-stamp, session-handoff and
workflow-config paths but does not **name** them. Pi is the counter-example:
its version stamp is a `version:` field inside
`.pi/skills/agentic-apps-workflow/SKILL.md`, not a predictable
`.pi/workflow-version.txt`. So the distinction is:

- **Four values carry the contract.** Containment under the host directory is
  what makes removal the deletion of one directory rather than a search — it is
  the load-bearing property of the "agent's own directory is the unit of
  removal" requirement.
- **Six values are written out in the per-host file (2.6)**, because a path that
  is merely contained still has to be stated to be found.

The `.planning/config*.json` divergence (`config.codex.json` vs `config.json`)
is drift rather than design: nothing about Codex requires the infix. Worth
flagging to codex-workflow, out of scope here.

## 2.5 — The link's shape: frontmatter list

**Decided (Donald): a frontmatter list.** Over the recommended per-agent marker
pair.

The entries carry **paths, not bare ids**:

```yaml
---
agents:
  codex: .codex/AGENTS.md
  pi: .pi/AGENTS.md
---
```

A bare `agents: [codex, pi]` list would be a *manifest*, and this design already
rejected a manifest — "an agent reading `AGENTS.md` would have no pointer to its
own instructions." Entries carrying paths keep the pointer property, so the
frontmatter list satisfies the requirement as a link surface rather than
replacing it with an inventory. Bare ids would not.

What the choice costs, recorded honestly rather than argued again:

- **Adding or removing one entry rewrites the frontmatter block**, so no tool
  can prove it left the other agents' entries byte-untouched the way per-agent
  markers would. The lifecycle scenarios that say another agent's link "SHALL be
  unchanged" are therefore assertions about *content*, not about bytes — the
  spec text and the harness rows both have to say so.
- **The rewrite fragility lands on the host installers, not on core.** Core's
  harness only ever reads this file. The `sed`-rewriting hazard is real for
  `codex-workflow` and `pi-agentic-apps-workflow` when they implement, and L11
  in the migration linter already rejects non-portable `sed -i`, which covers
  the likeliest form of it.
- **Frontmatter sits at the top of the file**, the most expensive real estate
  per §12. It is small — one line per agent — and it buys the §11 block staying
  first among the *prose*, which is what the placement advisory is actually
  about.

What it buys: the agent list is machine-readable without markers at all, one
entry per agent with no delimiter overhead, and a single well-known location
rather than a scan of the body.

## 2.6 — The per-host file

The link target. Six values from 2.4, and nothing else — anything larger
crossing this boundary is the signal to re-examine. Worked example for Codex at
`.codex/AGENTS.md`:

```markdown
# Codex — host binding

This file carries only what differs between agents. The workflow itself is
described host-neutrally in the project's `AGENTS.md`.

| | |
|---|---|
| Host directory | `.codex/` |
| Binding repo | [`codex-workflow`](https://github.com/agenticapps-eu/codex-workflow) |
| Version stamp | `.codex/workflow-version.txt` |
| Workflow config | `.planning/config.codex.json` |
| Session handoff | `.codex/session-handoff.md` |
| Trigger-skill install root | `${CODEX_HOME:-$HOME/.codex}/skills/agentic-apps-workflow/` |

## Invocation

The host-neutral file names workflow steps; this table gives this host's form.

| Step | This host |
|---|---|
| propose | `$opsx-propose` |
| apply | `$opsx-apply` |
| archive | `$opsx-archive` |
```

The invocation rows are the shape, not verified content — core does not own
codex's command names, and the host fills them in on adoption. The four
contract values and the two contained paths are evidenced from the live
template.
