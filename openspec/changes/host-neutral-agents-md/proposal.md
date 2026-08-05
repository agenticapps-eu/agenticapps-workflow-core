## Why

Every host's setup skill appends its own marker-delimited block to a project's
`AGENTS.md`, with no awareness that another host may already have written the
same content. With one host installed nothing looks wrong — a fleet survey
found every repo but one carries exactly one marker block. Install a second
host and the file gets two near-duplicate copies of the same instructions,
which then drift apart with nothing to reconcile them.

`factiv/cparx` is the one repo that had two (codex and opencode), and it shows
what the duplication actually costs. The two blocks are 96 and 94 lines.
Normalise the host names out of both and only ~50 of ~190 lines differ — and
those differences are drift, not host-specific design:

| Block A | Block B | Same thing? |
|---|---|---|
| `/prompts:gsd-discuss-phase` | `/gsd-discuss-phase` | yes |
| `gsd-execute-plan` | `gsd-execute-phase` | yes — one step, two names |
| references GSD | references GSD | GSD was removed fleet-wide 2026-07-28 |

The genuinely host-specific content is roughly four values: the binding repo
name, the host config path, and the skill/prompt invocation syntax. Nobody
designed per-agent sections; they are an accretion of each installer appending
independently, and the second copy exists only to disagree with the first.

The second half of the problem is that there is no supported way to take an
agent back out. Removing codex and opencode from cparx was done by hand, and it
was surgical only because those two hosts happened to write markers. Nothing
guarantees that, and nothing re-runs.

## What Changes

- **`AGENTS.md` carries exactly one host-neutral workflow section**, whichever
  agents are installed. The section describes the workflow, not the host.
- **Host-specific detail moves into the host's own directory** (`.codex/`,
  `.opencode/`, `.pi/`) — the binding repo, config path and invocation syntax
  that are the only things that actually differ.
- **A second host installing into a repo that already has the section adds no
  second copy.** This is the behaviour whose absence produced the cparx state.
- **Adding and removing an agent both become supported, re-runnable
  operations.** Removing an agent deletes its host directory; `AGENTS.md` is
  touched only when the first agent arrives or the last one leaves.
- **BREAKING** for any project with more than one host block today: the
  duplicate blocks collapse to one. cparx is the only known instance and has
  already been cleaned up by hand (cparx PR #125), so the migration's real
  fleet scope is zero — but the format has to define the collapse rather than
  assume nobody hits it.

Explicitly **not** in scope:

- **`CLAUDE.md`.** Claude is its only reader, so there is nothing to
  coordinate. claude-workflow having no marker convention is therefore not a
  defect to fix here.
- **The curl-able bash installer itself** (the separate Part-2 change). One
  requirement belongs to that change and is recorded here only so it is not
  lost: the installer should detect missing prerequisites on whatever machine
  it runs on and **offer** to install them, with the user accepting before
  anything is installed.

## Capabilities

### New Capabilities

- `host-neutral-instruction-files`: `AGENTS.md` carries one host-neutral
  workflow section regardless of how many agents are installed; what is
  genuinely host-specific lives in the host's own directory. Covers the
  single-section rule, what may and may not appear in it, and what a host
  installing into an already-provisioned repo must do.
- `agent-lifecycle-management`: adding and removing an agent from a repo are
  both supported, idempotent, re-runnable operations. Covers what each
  operation owns, when the shared instruction file is touched, and what
  happens on the first-agent and last-agent boundaries.

### Modified Capabilities

None. No existing capability under `openspec/specs/` states requirements about
instruction-file structure or agent provisioning.

## Impact

- **`spec/12-authoring-conventions.md`** — owns how host instruction files are
  authored ("This section governs how host SKILL.md / AGENTS.md / equivalent
  ...") and is where the single-section rule belongs.
- **`spec/11-coding-discipline.md`** — supplies the canonical block that sits
  near the top of `CLAUDE.md` / `AGENTS.md`. Referenced, not changed: it
  already describes one block, not one per host.
- **Host setup-skill templates** — `codex-workflow`'s
  `templates/agents-md-additions.md` and `pi-agentic-apps-workflow`'s
  `templates/pi-md-sections.md` are the two that write marker blocks today.
  They are in other repos; this change defines the contract they must meet and
  does not edit them.
- **Fleet** — one repo (`factiv/cparx`) had the duplicate state and is already
  cleaned up. Every other surveyed repo has a single block and is conformant
  by accident rather than by rule, which is what this change fixes.
