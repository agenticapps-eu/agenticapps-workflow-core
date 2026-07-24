---
id: 16-openspec-spec-slot
section_type: declarative-contract
spec_version: 1.0.0
---

# 16 — OpenSpec Spec Slot

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and the
concrete OpenSpec CLI version are at the host's discretion. The keywords
MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used per
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

**Introduced at spec v1.0.0.** This section, together with §17
(lifecycle & gate mapping), §18 (retargeted change-gate), and §19
(spec-vs-process & Linear coupling), replaces the GSD-engine front end
that §02 (hook taxonomy) and §07 (two-stage review) described for the
0.x line. §02 and §07 remain normative for hosts that cite a 0.x
version; a host that cites **1.0.0 or later** implements the OpenSpec
spec slot defined here. See ADR-0021.

## Concept

Under the 0.x line, a project's current truth was scattered across
`.planning/` phase artifacts (CONTEXT.md, PLAN.md, VERIFICATION.md) and
the always-loaded instruction file. There was no single, validatable
statement of *what the product currently guarantees* — only a history
of the phases that built it.

The **spec slot** is that single statement. It is an
[OpenSpec](https://github.com/Fission-AI/OpenSpec) directory tree,
generated per host, that holds three kinds of content with three
distinct lifespans:

- **`specs/`** — durable current truth. One `spec.md` per capability,
  each a set of requirements the shipping product satisfies *right now*.
  This is what a reader consults to learn what the system does.
- **`changes/`** — in-flight deltas. Each open change is a proposal to
  add, modify, or remove requirements, held apart from `specs/` until it
  is done.
- **`changes/archive/`** — history. A change that has shipped and been
  folded into `specs/` moves here, dated, as the durable record of *how*
  a requirement came to be.

A capability spec is durable; a change is transient; the archive is
immutable. Confusing the three is the failure this section exists to
prevent.

## The installed CLI is authoritative over this prose

OpenSpec is a live, upstream tool. Its on-disk schema and command
surface evolve independently of this spec. This section fixes the
*contract* (the three-slot model, the done-ness rule, the bind-upstream
rule); it does **not** freeze the CLI's file names or subcommands.

The 2026-07-24 cParX pilot (see `PILOT-REPORT.md`) ran against a
CLI-driven `spec-driven` schema in which:

- changes are scaffolded with `openspec new change <slug>` and carry a
  per-change directory of `proposal.md`, `design.md`, a spec delta, and
  `tasks.md`;
- project context lives in `openspec/config.yaml` under `context:`,
  not a standalone `project.md`;
- verb-first `openspec validate` / `openspec show` are current, and the
  older `openspec spec …` subcommands are deprecated.

A host **MUST** implement against the OpenSpec CLI version it actually
installs, and **MUST** record that version in its instruction file.
Where this prose and the installed CLI disagree on a file name or
subcommand, the CLI wins and the host notes the divergence — the
three-slot model and the done-ness rule below are what remain
normative.

## Requirements

### Slot layout

- **MUST** initialize the spec slot with the OpenSpec CLI (e.g.
  `openspec init`), producing at minimum `openspec/specs/`,
  `openspec/changes/`, and `openspec/changes/archive/`.
- **MUST** keep exactly one authoritative `spec.md` per capability under
  `specs/<capability>/`. A capability is a coherent product surface
  (e.g. `analysis-pipeline`, `role-based-access`), not a single phase.
  See §19 for the merge-not-mirror rule that governs how phases map to
  capabilities.
- **MUST NOT** treat `changes/` or `changes/archive/` as a source of
  current truth. A reader answering "what does the system do today?"
  reads `specs/` only.

### Done-ness

- **MUST** define a change as *done* only when **both** hold: its spec
  delta has been **folded** into the affected `specs/<capability>/spec.md`
  (so `specs/` now states the new truth), **and** `openspec validate
  --all` reports green for the seeded capabilities and every remaining
  open change.
- **MUST** move a done change from `changes/` into
  `changes/archive/<date>-<slug>/`. A change directory that has been
  folded but not archived, or archived but not folded, is a
  non-conforming half-state.
- Folding and archiving are distinct from **shipping** (the git commit).
  §17 makes the `archive ≠ ship` boundary normative.

### Bind-upstream

- **MUST** consume OpenSpec as an **upstream tool linked per host**, not
  as prose re-ported into this repo or copied between hosts. Each host
  generates its spec slot with the CLI it installs; the slot is a
  build-time product of that tool, not a vendored artifact maintained by
  hand.
- **MUST NOT** fork OpenSpec's schema into a host-local reimplementation.
  A host that cannot use the upstream CLI (runtime constraint, offline
  build) documents that as a spec delta per §09 rather than shipping a
  hand-rolled parallel format.
- This mirrors the fleet's existing bind-upstream posture for Superpowers
  and GSD (consume upstream skills rather than re-author host copies) and
  supersedes the 0.x "bind-upstream-gsd" convention. The front-end tool
  changes from the GSD engine to OpenSpec; the *rule* — link upstream,
  generate per host, do not re-port — is unchanged.

## Scenarios

#### Scenario: reader consults current truth

- **GIVEN** a capability `analysis-pipeline` with a shipped requirement
  set in `specs/analysis-pipeline/spec.md` and two open changes under
  `changes/`
- **WHEN** a reader (human or agent) asks what the pipeline guarantees
  today
- **THEN** the answer is read from `specs/analysis-pipeline/spec.md`
  alone, and the open changes are understood as *not-yet-true*.

#### Scenario: a change reaches done-ness

- **GIVEN** an open change whose spec delta modifies the classifier's
  logged fields
- **WHEN** the delta is folded into `specs/analysis-pipeline/spec.md`
  and `openspec validate --all` reports green
- **THEN** the change is *done* and MUST be moved to
  `changes/archive/<date>-<slug>/`; `specs/` now states the new field as
  current truth.

#### Scenario: CLI schema diverges from this prose

- **GIVEN** an installed OpenSpec CLI that scaffolds `proposal.md` +
  `design.md` + delta + `tasks.md` and reads context from
  `openspec/config.yaml`
- **WHEN** this section's prose names a different file (e.g. a
  standalone `project.md`)
- **THEN** the host implements against the installed CLI, records the
  CLI version and the divergence in its instruction file, and remains
  conformant — the three-slot model and done-ness rule are satisfied.

## Conformance

A host implementation:

- **MUST** generate the spec slot with the upstream OpenSpec CLI and
  record the CLI version in its instruction file.
- **MUST** maintain the three-slot model (`specs/` truth, `changes/`
  deltas, `archive/` history) and the two-part done-ness rule.
- **MUST NOT** re-port OpenSpec's schema or maintain the spec slot as a
  hand-edited second source of truth.
- **SHOULD** seed `specs/` for a brownfield project by reconstructing
  product truth from its prior `.planning/` artifacts (see §19 and the
  planning→openspec recipe under `docs/recipes/`).
