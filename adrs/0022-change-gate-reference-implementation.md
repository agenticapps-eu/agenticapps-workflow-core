# ADR-0022: Core publishes the §18 change-gate as a reference implementation

**Status**: Accepted  **Date**: 2026-07-25
**Issue**: [#32](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/32)
**Spec trajectory:** none. §18's normative text is untouched and no requirement
is added — a host is not obliged to vendor this. The change lands entirely in
`tools/` and `reference-implementations/`, neither of which is normative spec
text, so no spec version moves and no host conformance claim changes.

## Context

§18 is a declarative contract, and its Conformance section binds *hosts*: each
"**MUST** ship a `PreToolUse` (or equivalent) change-gate implementing" the
truth table. Core wrote the contract and shipped no implementation. Four hosts
each wrote their own, and by 2026-07-25 there were **five mutually divergent
copies** of a script whose entire purpose is to make behaviour uniform:

| Copy | lines | lineage |
|---|---|---|
| `core/gate/` (untracked working-tree scratch) | 138 | A |
| `claude-workflow/bin/` | 184 | A |
| `pi-agentic-apps-workflow/bin/` | 193 | A |
| `opencode-workflow/bin/` | 164 | B (ground-up rewrite) |
| `codex-workflow/bin/` | 164 | B (byte-identical to opencode) |

Lineage B shares no function with lineage A. None of the five satisfied §18.

Two things made this worse than ordinary drift.

**The contract was unverifiable as written.** §18 requires the gate be
"demonstrable by direct script invocation with simulated payloads", but every
copy hardcoded the `openspec` binary, so the block/allow rows could not be
driven without a real populated OpenSpec repo — and a failing `validate` masks
every row as a block. Nobody could measure conformance, so nobody noticed its
absence.

**Divergence propagated through a shared install path.** `claude-workflow`'s
installer writes its copy to `~/.agenticapps/bin/openspec-change-gate.sh`, and
every host's hook shim, `pre-commit`, and pi's extension resolve there. Whichever
installer ran last owns the path for every host. The defect was found in reverse:
opencode's installer had run last on the reporter's machine, so claude's shims
measured as conformant and two "OK" results were confounded by machine state
rather than by the shims' own correctness.

The failure mode was not "a host has a bug". It was "there is no upstream", and
no amount of fixing individual hosts addresses that.

## Decision

Core publishes the gate at
`reference-implementations/openspec-change-gate/`, and ships an executable
conformance harness at `tools/change-gate-conformance.sh`. Hosts vendor the
script rather than maintaining their own.

§18's normative text is deliberately left alone. The gate is offered, not
mandated: making "vendor core's copy" a MUST would be a breaking change to a
1.0.0 contract, to solve a problem that having an upstream at all already
solves. The pointer lives in `reference-implementations/README.md`.

Three supporting choices:

**The implementation is composed, not adopted.** Neither surviving variant was
correct. `pi-193` passed the truth table, every payload shape, and the
`--pre-commit`/`--ci` floor but counted reviewers with `grep -c`.
`claude-184` counted reviewers correctly but could not parse pi's payload.
Each was taken for what it got right; the union scores 19/19.

**Conformance is executable, and a behaviour change requires a harness row.**
The harness stubs `openspec` on PATH and adds `OPENSPEC_BIN` so `validate` can be
driven green or red independently of the gate's own logic. This is what makes
§18's "demonstrable by direct invocation" clause true rather than aspirational.

**Reviewer counting is a real count, not a line count.** Fenced blocks are
skipped, names are deduplicated, and `OPENSPEC_GATE_SELF` excludes the
implementing host.

## Alternatives Rejected

**Adopt opencode/codex's 164-line variant as canonical** — what #32 proposed, on
the reasonable evidence that it passed every hook-mode row the others failed. It
has no mode dispatch: `--pre-commit` and `--ci` fall through to hook mode, read
empty stdin, parse no path, and fail open. Both floors become silent no-ops
returning 0 — measured, in harness section C. Since §18 makes the shell script
"the real enforcement surface ... including against a human editor", and a
`PreToolUse` hook provably cannot gate the session that installed it, this would
have traded three wrong exit codes for the loss of the only surfaces that
actually guarantee the rule. It also stops at the first active change, so
directory order decides the verdict when two are open; renames `MIN_REVIEWERS`;
drops `OPENSPEC_GATE_STRICT`; and widens `GSD_SKIP_REVIEWS` to bypass `validate`
as well as reviews.

**Fix each host in place, ship nothing from core** — preserves core's spec-only
role and is the minimal reading of §18, which does assign the gate to hosts. It
treats the symptom. Five copies diverged *because* there was no upstream; four
coordinated fixes leave the same structure that produced the divergence, and the
`~/.agenticapps/bin/` install race unresolved. Core already ships
`tools/drift-report.sh` to *measure* host drift, so shipping the artifact hosts
drift from is continuous with its role rather than a departure from it.

**Track the gate at a top-level `gate/`** — where the untracked scratch copy
already sat, and the least surprising place relative to how the work was
requested. Rejected because it puts an implementation at the root of a spec repo
with nothing explaining why core now ships code.
`reference-implementations/` already exists and already means "the host-facing
surface"; this is what it is for.

## Consequences

- **Hosts re-vendor.** Each host's adoption is its own PR, per the existing
  convention. Until then the copies remain divergent — this ADR creates the
  upstream, it does not migrate anyone. The four host issues are the prompt.
- **`~/.agenticapps/bin/` stays a race** until every installer writes the same
  bytes. Re-vendoring is what closes it; the harness is what proves it closed.
  The `pre-commit` wrapper documents `OPENSPEC_GATE` as the opt-out.
- **§18's contract is unchanged.** No host's conformance level moves on account
  of this ADR. A host that ships a hook-only gate was already non-conformant to
  §18's "real enforcement surface" clause; the harness now says so out loud,
  which will read as new failures against unchanged behaviour.
- **A second spec-repo precedent.** `tools/drift-report.sh` measures hosts;
  this measures and now supplies them. If more of §16–§19 acquires reference
  implementations, `reference-implementations/` becomes code, not a registry —
  a direction to take deliberately.
- **Untracked scratch remains.** `core/gate/` and the cParX dry-run `openspec/`
  corpus are working-tree artifacts, not repo members. `gate/run-plan-review.sh`
  is the one piece with no home yet; it is not part of §18's contract.
