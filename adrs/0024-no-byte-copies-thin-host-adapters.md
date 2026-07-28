# ADR-0024 — No byte-copies: core owns the rules, hosts are thin adapters

**Status**: proposed
**Date**: 2026-07-28
**Extends**: ADR-0022 (core publishes the gate), ADR-0023 (hosts pin, not copy)

## Principle

> Either we bind to an external dependency (gstack, Superpowers, OpenSpec), or
> we have a central rule in core that all hosts follow. A host implements
> something itself only where that is genuinely unavoidable. **Nothing is
> byte-copied.**

ADR-0023 applied this to four files. Measurement shows the problem is an order
of magnitude larger, and that the expensive duplication is not bytes at all.

## What is actually duplicated

**Artifacts** — 16 copies of 4 core files across 4 hosts. 20 copies of 3
templates across 7 projects. 6 copies of spec §11 embedded in project
`CLAUDE.md` files. ~42 copies of things with one source of truth, and migration
`0033` — run on 2026-07-28 — *created* 20 of them.

**Decisions** — the expensive one:

| slug | hosts implementing it |
|---|---|
| `bind-openspec-v1` | 3 (each a separate ~20k document) |
| `inject-spec-11-coding-discipline` | 3 |
| `knowledge-capture` | 3 |
| `add-ts-declare-first-skill` | 3 |
| `baseline` | 4 |

Host weight tracks this directly: **987 / 274 / 127 / 74 files**
(claude / codex / opencode / pi), with 35 / 17 / 13 / 12 migration documents
each. A new host today must re-implement the chain to be conformant. That is the
cost being paid, and it is why adding a host is hard.

## The external deps already do this correctly

They are the model, not the exception:

- **OpenSpec** — the CLI *generates* `openspec/` and the per-host `opsx`
  commands (`openspec init --tools claude`). Nothing is copied; regeneration is
  the update mechanism.
- **Superpowers / gstack** — invoked by name (`superpowers:brainstorming`,
  `/browse`). The host records *that* it uses them, never *what* they are.

Core is the only dependency in the fleet that propagates by copying.

## Decision

**A host is an adapter descriptor plus a thin installer. Core owns everything
else — including the migration chain.**

What genuinely differs between hosts is smaller than it looks. It is *not* the
gate: since gate 1.2.0 the payload shapes for claude / pi / opencode are all
handled inside the one canonical script. What differs is only:

| genuinely host-specific | example |
|---|---|
| instruction file name | `CLAUDE.md` vs `AGENTS.md` |
| hook wiring format | `.claude/settings.json` vs `opencode.json` vs `pi.json` |
| skill/command layout | `.claude/skills/` vs `.opencode/skills/` vs `prompts/` |
| self identity | `OPENSPEC_GATE_SELF=claude` |

All four are *data*, not code. So:

```
host repo/
  host.json      # the four facts above, plus the core pin
  install.sh     # thin: hand host.json to core's installer
  README.md
```

Core gains `bin/install-host.sh`, which reads a `host.json` and performs what
each host's `install.sh` does today. The shared migration chain moves to core
and is parameterised by `host.json` rather than re-authored per host. A host may
still carry host-only migrations for things that are genuinely its own
(pi's `rebind-upstream-superpowers` is a fair example) — that is the
"unavoidable" escape hatch, used by exception.

**Adding a host becomes: write `host.json`.**

## Projects, not just hosts

The same principle collapses the project surface. Projects today carry
`.claude/claude-md/workflow.md`, `.claude/workflow-config.md`, a vendored
`SKILL.md`, and an embedded §11 block — all copies of one source.

The binding mechanism already exists and is already loaded: **the global
instruction file**. `~/.claude/CLAUDE.md` is read in every session of every
project. Rules that belong to every project belong there once, not mirrored into
six `CLAUDE.md` files.

A project should then carry only what is genuinely its own: its own `CLAUDE.md`
prose, its `openspec/` slot, and the hook shim (already 7 lines that `exec` the
shared path).

**The honest cost.** A repo-local copy is portable — a teammate cloning callbot
gets the rules without installing anything. Moving rules to the global file
trades that for single-sourcing, and makes "run the installer" a prerequisite
for conformance rather than a convenience. That is the same bargain every
toolchain makes, but it is a real change and should be a deliberate one.

## Consequences

- A core rule change stops being an N-host, M-project event. Today the reviewer
  floor (spec 1.1.0 / gate 1.4.0) needs 4 host PRs and, to reach projects, a
  migration authored up to 3 times.
- Host repos shrink by roughly an order of magnitude.
- Conformance becomes verifiable rather than asserted: a host either resolves
  its pin and matches its `host.json` contract, or it does not.
- **Core becomes a single point of failure.** Today a broken core artifact still
  has to be vendored deliberately by each host; under this design it reaches
  every host on next install. The pin (ADR-0023) is what keeps a human in that
  loop — this ADR is only safe *with* pinning, not instead of it.
- The migration chain's history stays where it is. Migrations already applied
  are not rewritten; the move applies to the shared chain going forward.

## Sequencing

Not a single change. Ordered by ratio of relief to risk:

1. **Finish ADR-0023** in the corrected order — the artifact pin is the
   foundation everything else stands on.
2. **`host.json` + `bin/install-host.sh` in core**, with one host converted as
   the proof. Hosts keep their existing installers until it is proven.
3. **Move the shared migration chain to core**, parameterised. Biggest single
   reduction; do it after the installer is trusted.
4. **Collapse the project surface** — global rules, no mirrors. Needs the
   portability trade decided first.
5. **Retire the per-host harness copies** — falls out of (1) and (2).

Steps 3 and 4 each need their own ADR; this one records the target and the
principle, not their design.

## Alternatives considered

**Keep copying, automate it.** A bot that opens the re-vendor PRs. Rejected in
ADR-0023 and more firmly here: it industrialises the duplication rather than
removing it, and does nothing about decisions implemented three times.

**Git submodules for core.** Real binding, no copies. Rejected for now: the
fleet already hit submodule friction (`.gitmodules` in three hosts), and a pin
plus a resolver gives the same guarantee with less ceremony and offline support.

**One monorepo.** Removes the problem by removing the boundary. Rejected: the
hosts have genuinely independent release cycles and audiences, and OpenSpec /
Superpowers / gstack prove that a well-bound external dependency does not need
to live in the same tree.
