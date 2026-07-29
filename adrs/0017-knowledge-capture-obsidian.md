> **Superseded 2026-07-28.** Spec §15 was removed at spec 1.2.0 and the
> knowledge-capture ritual retired fleet-wide. The OpenSpec archive
> (`openspec/changes/archive/`) retains each change's proposal, design, delta
> and review evidence permanently — the durable record §15's distilled note was
> approximating. Notes already written to the operator's vault are left in
> place; nothing reads or updates them. See ADR-0025.

# ADR-0017: Knowledge capture into the Obsidian vault as a portable spec section

**Status:** Accepted
**Date:** 2026-07-06
**Linear:** —
**Spec trajectory:** v0.7.0 (initial §15)

## Context

Every AgenticApps host implementation already produces learnings — the
rituals guarantee it. Session handoffs record what was done and why;
plan and phase completions surface gotchas, corrected assumptions, and
tooling insights. But those learnings die where they were made: the
per-repo `session-handoff.md` is overwritten by the next session, and
ADRs / CHANGELOGs capture repo-scoped facts by design. A root cause
discovered in `fx-signal-agent` never reaches an agent working in
`cparx`; a workflow insight from a Codex session never reaches a
Claude session in the same repo.

Donald wants a **cross-repo, human-readable memory** in his Obsidian
vault: one note per repo under
`~/Obsidian/Memex/40-49 Resources/44 Agentic Coding Learnings/`, with
a vault-side schema (`CLAUDE.md` in that folder) that defines a
curated `## Key Learnings` section, an append-only `## Log`, a
selectivity bar, and vault-safety rules. Human-readable matters: the
memory is pruned by hand and read by any agent in any repo.

Two forces shaped the decision — the same two that shaped ADR-0014
(observability) and ADR-0016 (prompt injection):

1. **Repos must be self-contained.** A host never references
   workflow-core at runtime, and no repo may embed an operator's
   machine-local vault layout in skill logic. The destination
   therefore has to come from per-repo configuration.
2. **The hosts diverge on runtime.** Claude Code, Codex CLI, and the
   pi/opencode ports wire rituals differently. The contract has to be
   expressed as host-agnostic requirements each host satisfies in its
   own idiom.

An additional constraint is machine reality: the vault exists on
exactly one machine. CI runners, containers, and other workstations
must not error, must not create phantom vault folders, and must not
require configuration to stay quiet.

## Decision

Add **`spec/15-knowledge-capture.md`**, a declarative RFC-2119
contract, in the same two-layer shape as observability (ADR-0014):
the contract lives in core; each host ships its own generator/wiring.

The contract's load-bearing choices:

1. **Three trigger points, post-artifact.** Hosts MUST write learnings
   when they (a) write a session handoff, (b) complete a plan,
   (c) complete a phase — as the final step of the ritual, after the
   ritual's own artifact is committed. Capture failure never fails the
   ritual.
2. **Per-repo config, no hardcoded paths.** `.planning/config.json`
   gains a `knowledge_capture` block (`enabled`, `note`). Host skill
   logic MUST read the destination from it at trigger time. Repos stay
   self-contained; machines without the vault stay unaffected.
3. **Graceful skip.** Block absent, `enabled: false`, or parent folder
   missing → skip silently with at most one info line. The host MUST
   NOT create the parent folder.
4. **Vault-side schema mirrored into the spec.** The folder's
   `CLAUDE.md` owns the note format; §15.4–15.6 mirror its normative
   rules (curated Key Learnings targeting ~10–20 items; append-only
   newest-first Log with the
   `### YYYY-MM-DD — <handoff|plan|phase> — <short title> (<host>)`
   heading; 1–5 transferable learnings per trigger with
   nothing-qualifies → write nothing; create-from-template on first
   write; touch nothing else in the vault; no secrets or
   client-confidential data) so the spec is self-contained.
5. **Conformance wired into §09** with three checks: config block
   present in opted-in repos, trigger wiring present in the host's
   ritual instructions, and graceful-skip behavior verified.

## Alternatives considered

- **Keep learnings in per-repo `session-handoff.md` only.** Rejected:
  the handoff is a continuity artifact for the *next session in the
  same repo*, overwritten each time. It cannot serve as cross-repo or
  cross-host memory, which is the entire point.
- **Write into the family knowledge wiki (`.knowledge/`).** Rejected:
  the wiki is regenerable synthesis compiled from sources — writes to
  it are lost on recompile — and the vault-side schema explicitly
  separates the learnings folder from the wiki plane (45 Wiki must not
  ingest project-scoped content).
- **A central database / memory-MCP service.** Rejected: adds a
  runtime service dependency to every host, and the memory stops being
  a plain markdown note a human curates in the vault. Human
  readability and hand-pruning are requirements, not conveniences.
- **Hardcode the vault path in each host's skills.** Rejected:
  violates repo self-containment, breaks on every machine that is not
  Donald's workstation, and couples three host repos to one operator's
  folder taxonomy. The per-repo config block is the decoupling.

## Consequences

- A new minor spec version, **0.7.0**. Hosts at 0.6.0 remain
  conformant for 0.6.0 claims; claiming 0.7.0 requires shipping the
  trigger wiring and skip behavior. Repos opt in individually via the
  config block; a repo that never opts in is conformant-by-skip.
- **The external path dependency is opt-in and machine-local.** The
  spec gains its first contract that targets a location outside the
  repo, but the graceful-skip rule confines it: only machines whose
  config points at an existing vault folder ever write, and every
  other environment (CI, containers, teammates' machines) is silent
  by design.
- **Downstream hosts must mirror.** `claude-workflow`,
  `codex-workflow`, and the pi/opencode port each need a migration
  that wires the three trigger points into their ritual skills and
  teaches their config templates the `knowledge_capture` block.
  Propagation machinery is out of scope here, exactly as ADR-0014 kept
  generators out of core.
- The vault-side `CLAUDE.md` becomes a second normative surface for
  the note format. §15 mirrors it to stay self-contained, at the cost
  of a documented sync obligation: if the vault schema changes, §15
  gets patched to match.
- The dashboard (consumer-only) has no ritual surface and is
  trivially conformant.
