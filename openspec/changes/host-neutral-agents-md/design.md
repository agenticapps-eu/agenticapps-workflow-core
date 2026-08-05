## Context

`AGENTS.md` is read by every agent that opens the repo. Each host's setup skill
appends its own marker-delimited block to it independently, and no host looks
first to see whether the section is already there. With one host installed the
design flaw is invisible; the fleet survey found every repo but one carrying
exactly one block, which means the fleet is conformant by accident.

`factiv/cparx` is the exception and the evidence. It had codex and opencode
installed, so it had two blocks — 96 and 94 lines. Normalising host names out
of both leaves ~50 of ~190 lines differing, and every one of those differences
is drift rather than design: `/prompts:gsd-discuss-phase` against
`/gsd-discuss-phase`, `gsd-execute-plan` against `gsd-execute-phase` for the
same step, and both blocks citing GSD, removed fleet-wide on 2026-07-28. The
duplication did not encode a host difference. It manufactured a disagreement.

Two constraints shape the work. Core owns the contract but not the
implementations — the templates that write these blocks live in
`codex-workflow` and `pi-agentic-apps-workflow`, separate repos. And core
already has an established way to bind a contract it cannot execute: the
`tools/*-conformance.sh` harnesses, which a host repo runs against its own
artifacts to prove it satisfies a spec section.

## Goals / Non-Goals

**Goals:**

- One host-neutral workflow section in `AGENTS.md`, whatever the agent count.
- Adding and removing an agent are both supported, idempotent, re-runnable.
- Removal is bounded — one directory, not a search — and says what it found
  rather than guessing.
- The contract is machine-checkable by a host repo without core executing it.

**Non-Goals:**

- `CLAUDE.md`. Claude is its only reader; there is no second agent to
  coordinate with, so a marker convention there buys nothing.
- The curl-able bash installer (separate Part-2 change). Recorded there, not
  here: the installer should detect missing prerequisites on whatever machine
  it runs on and **offer** to install them, with the user accepting first.
- Editing the host repos' templates. This change defines what they must
  satisfy; they change on their own schedule.
- Auto-collapsing existing duplicate blocks. See Decisions.

## Decisions

**A duplicate section is reported, never auto-collapsed.** The obvious move is
to detect two blocks and merge them. Rejected: the cparx pair had drifted, so
"merge" means choosing between `gsd-execute-plan` and `gsd-execute-phase`, and
nothing in the text says which is right. Both, as it happens, were wrong — the
system they named had been deleted. A tool that picks silently would have
propagated a dead reference with the authority of having been "fixed".
Reporting both and stopping is the honest failure. *Alternative considered:*
collapse to the first block and diff the second into a `.orphan` file. Still a
silent choice, plus a new file nobody reads.

**Presence of an agent is the presence of its directory, and partial presence
is a first-class state.** Both cparx hosts were half-installed: `.opencode/`
had a config and a version stamp but no skills, `.codex/` was never committed
at all. A definition that admits only present/absent classifies both wrongly
and makes removal either refuse or over-delete. Removal therefore removes what
is there and reports what was expected but missing. *Alternative considered:* a
manifest per host listing every provisioned file. Better fidelity, but it is
new state that can itself drift from the directory, and the failure mode is
worse — a manifest that disagrees with disk is harder to reason about than a
directory that is simply incomplete.

**Tool-owned state inside a host directory is reported, not deleted.**
`.opencode/` also holds a `package.json` and `node_modules` that the opencode
CLI manages for itself. Removal must not take those: the workflow did not
install them and does not know what depends on them. This is the same rule the
cparx cleanup followed by hand.

**The shared file is touched only at the first-agent and last-agent
boundaries.** This is what makes "add a second agent" a no-op on the shared
file, which is precisely the behaviour whose absence produced the cparx state.
It also makes the common case — adding or removing an agent when others remain
— provably non-destructive: byte-identical before and after.

**One marker name, host-neutral, with the legacy names recognised for
detection only.** Today's markers are host-scoped
(`BEGIN: agentic-apps-workflow sections`, `BEGIN: opencode-workflow sections`).
The new section needs a single name. Legacy names must still be *recognised*,
or the duplicate check cannot see the state it exists to report — but they are
recognised for reporting, not rewritten, consistent with the no-auto-collapse
decision.

**Core binds this with a conformance harness, not an implementation.** Follows
the established `tools/*-conformance.sh` shape: a host repo points the script
at its own artifacts and gets a pass/fail row per requirement. Core cannot
provision an agent into a repo it does not own, and the last time a contract in
this repo was stated in prose alone, seven fixtures and a worked example
drifted from it undetected until CI ran on a different machine.

## Risks / Trade-offs

**The single-section rule is unenforced until every host adopts it.** → The
harness makes non-adoption visible per host rather than fleet-wide, so
adoption can be sequenced instead of coordinated. Until then the current
accidental conformance holds, since one agent per repo is the norm.

**Reporting duplicates rather than fixing them leaves manual work.** → It is
one repo, already cleaned by hand, and the report names both blocks and their
line ranges. The alternative silently picks a loser.

**"Host-neutral" has no mechanical test.** A host could satisfy the
single-section rule and still write its own name inside the section. → The
harness can check for known host identifiers in the section body. That is a
denylist and will not catch novel phrasing — a real residue, worth stating
rather than papering over.

**Splitting content into host directories can under-specify an agent.** If
something genuinely shared gets pushed into a host directory, other agents lose
it. → The measured host-specific surface is about four values; anything larger
crossing that boundary is the signal to re-examine, and the harness reports
host-directory size rather than assuming.

## Migration Plan

Fleet scope is zero repos in the duplicate state — cparx was the only one and
its cleanup already merged as cparx PR #125. The migration exists to define
the collapse, not to run it.

1. Spec §12 gains the single-section and host-directory requirements.
2. Core ships the conformance harness; core's own CI runs it against core.
3. Each host repo adopts on its own schedule, using the harness as the gate.
4. A repo found with duplicate blocks is reported, resolved by hand, and the
   resolution recorded — there is no automated collapse path by design.

Rollback is deleting the harness and reverting the §12 requirements; nothing
in a downstream repo depends on this change until that repo adopts it.

## Open Questions

- Should the harness fail or warn on a host identifier found inside the
  host-neutral section? Failing risks false positives on prose that merely
  mentions a host; warning risks the rule being ignored.
- `.opencode/` in cparx held both workflow files and opencode-CLI state in one
  directory. Should the contract require a subdirectory separating the two, or
  is reporting the unrecognised state sufficient?
- Does the last-agent-leaves case remove the section, or leave it? Removing is
  symmetric; leaving it means a repo that briefly has no agent does not lose
  documentation it will want back. The spec currently says remove.
