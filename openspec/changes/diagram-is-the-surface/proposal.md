## Why

The repository still carries the surface of things it already decided to remove.
GitNexus went on 2026-07-28 and six of its skills still load in core's own
`.claude/skills/`. `database-sentinel` went on 2026-08-07 and its implementation
and declaration entry still ship. `GSD_SKIP_REVIEWS` stopped escaping anything at
gate 2.0.0 and is still read, still advertised across twenty files, and still
recommended to the operator by `run-plan-review.sh` at a failure path.

Largest of all: **`gate/` publishes a pre-2.0.0 gate that nothing resolves.** It
defaults `MIN_REVIEWERS=2`, blocks on insufficient reviewers, treats
`GSD_SKIP_REVIEWS` as a live bypass of that live block, and `gate/README.md`
documents this as contract. Every installer, tool and hook resolves
`reference-implementations/` instead, and the installed copy at
`~/.agenticapps/bin/` is byte-identical to it. So `gate/` enforces nothing — it
only tells readers the gate works a way it has not worked since 2.0.0.

`CLAUDE.md` already states the test: *"If a thing is not on that diagram and is
not required to make a step on it work, it does not belong in this repo."* Nothing
here is a new judgment. It is that test applied to what is on disk, once.

The cost is not tidiness. A vestigial flag documented as an escape hatch gets
reached for as one. A published gate that contradicts the spec teaches the wrong
model to everyone who reads it. And a diagram that still says *"REVIEWS ≥ 2"* is
the specification of the loop, so it is wrong at the source.

## What Changes

**Removed — dead surface**

- `gate/` — the orphaned published gate and its README. Nothing resolves it;
  `resolve-core-artifact.sh` maps the shared install to
  `reference-implementations/openspec-change-gate/openspec-change-gate.sh`.
- **BREAKING** `GSD_SKIP_REVIEWS` — the variable, its conformance rows, the
  `run-plan-review.sh` failure-path recommendation, and the twenty files that
  advertise it. Vestigial since 2.0.0 by the gate's own header.
- `reference-implementations/project-hooks/database-sentinel.sh` and its
  `SHIMMED-HOOKS` entry.
- Core's own `.claude/skills/gitnexus/` — six skills.
- The dangling `~/.claude/skills/ts-declare-first` symlink, pointing into
  `~/.claude/skills/agenticapps-workflow`, which no longer exists.
- The `gitnexus` MCP server entry in `~/.config/opencode/opencode.json`.
- Four stale `SKILL.md.pre-0034` files in fleet repositories.

**Corrected — wrong, not dead**

- `workflow.mmd` line 7 states *"no code edits until validate GREEN and REVIEWS
  ≥ 2"*. Reviews have not blocked since 2.0.0.
- `workflow.mmd` line 13 routes *"db-sentinel if SQL/RLS"* to a removed hook.
- `spec/18-retargeted-change-gate.md` line 104 carries a truth-table row for the
  hatch and line 235 states the gate keeps it deliberately.
- The gate header documents `MIN_REVIEWERS` as a blocking floor. It is not; it
  selects which NOTE prints.
- Global `CLAUDE.md` warns that two skills claim the `agentic-apps-workflow`
  name. One of the two no longer exists.

**Not touched.** `adrs/`, `openspec/changes/archive/`, `CHANGELOG.md`, and the
change documents recording these removals. Deleting the record of a decision is
not minimizing; it is losing the reason.

**§13 is not in this change, and an earlier revision had it wrong.** It proposed
retiring `spec/13-ts-declare-first.md` on the claim that no host bound it. That
claim was false and was made by checking `~/.claude/skills` and stopping.
`reference-implementations/README.md` records **three** hosts binding it —
`codex-ts-declare-first`, `opencode-ts-declare-first`, `pi-ts-declare-first` —
and pi reached `full` conformance at host v0.6.0 *by* binding §13, after ADR-0004
reversed its minimal-host framing to do so. Removing it breaks three hosts and
demotes one. It is dropped, not deferred: the evidence says it is load-bearing.

This also dissolves the spec-version collision with PR #78. Nothing here is
breaking to the `spec/` surface, so 2.0.0 stays uncontested.

## Capabilities

### New Capabilities

- `vestigial-surface-removal`: what makes a *shipped enforcement or interface*
  artifact vestigial, and the obligation to remove it rather than carry it with a
  comment explaining that it does nothing. Deliberately scoped to that class —
  see design; an earlier revision stated it over all artifacts and condemned the
  repository's own records.

### Modified Capabilities

- `change-gate-enforcement`: `GSD_SKIP_REVIEWS` is removed from the gate's
  interface rather than retained-but-inert; the gate's documentation of
  `MIN_REVIEWERS` must match its behaviour; and no published copy may contradict
  the capability.

*Not `project-hook-binding`.* An earlier revision listed it for
`database-sentinel` leaving `SHIMMED-HOOKS`. That is already specified by
`projects-bind-not-copy`, whose "No project binds any fleet hook once the surface
is closed" subsumes the single entry. A second delta would compete with a
twice-reviewed one.

## Impact

- **`gate/`** — removed entirely. The one item that changes what a reader believes
  about enforcement.
- **`reference-implementations/openspec-change-gate/`** — the hatch branch, its
  header block, the `MIN_REVIEWERS` documentation, the README, the CI yml.
- **`reference-implementations/run-plan-review/`** — line 677 recommends the
  hatch to the operator. This refutes "the conformance rows are its only live
  consumers", which an earlier revision asserted.
- **`reference-implementations/project-hooks/`** — `database-sentinel.sh`,
  `SHIMMED-HOOKS`, the gate shim.
- **`spec/18`** — two statements of the hatch.
- **`skills/agentic-apps-workflow/SKILL.md`** — core's own trigger skill
  advertises it.
- **`tools/`** — conformance rows asserting the hatch.
- **`workflow.mmd`** — two lines, both load-bearing, both currently false.
- **Published artifacts** — `OpenSpec-Change-Cheatsheet.html`, `publish/index.html`,
  `docs/HOW-IT-FITS-TOGETHER.md`, `WORKFLOW-EXPLAINED.md`, `GATE-INVENTORY.md`,
  `PILOT-REPORT.md`.
- **Outside the repository** — the dangling host symlink and the opencode MCP
  entry, recorded as steps rather than shipped.

**Sequencing.** `database-sentinel`'s removal is decided in
`projects-bind-not-copy` and executed here. That change is unmerged, so the
dependency is a hard block with a stated fallback, not an ordering preference —
see design.
