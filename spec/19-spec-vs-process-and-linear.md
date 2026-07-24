---
id: 19-spec-vs-process-and-linear
section_type: declarative-contract
spec_version: 1.0.0
---

# 19 — Spec-vs-Process Placement & Linear Coupling

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. The keywords MUST, MUST NOT, SHOULD,
SHOULD NOT, and MAY are used per
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

**Introduced at spec v1.0.0.** This section governs *where content
lives* once a project has a spec slot (§16), and the loose convention
that couples a change to a roadmap item. It extends §12's
instruction-surface economy (ADR-0020) from "what belongs in the
always-loaded file" to "what belongs in the spec slot versus the
instruction file versus history." See ADR-0021.

## Concept

With a spec slot in play, three destinations exist for prose that used
to pile up in `.planning/` and the always-loaded instruction file:

- **The spec slot (`openspec/specs/`)** — *product capability*: what the
  system guarantees. Durable, validatable, read by anyone asking "what
  does it do?"
- **The host instruction file (`CLAUDE.md` / `AGENTS.md`)** — *process*:
  how this team works. Coding rituals, gate bindings, stack notes,
  runbooks. Read every turn (§12 economy applies).
- **`docs/legacy-planning/`** — *effort history*: the record of how the
  product was built. The retained `.planning/` tree lives here (§ Tier 0
  of the migration recipe). Never deleted, rarely read.

## The placement test

For any line of prose, ask:

> **Is this a product guarantee, or a way of working?**

- A **product guarantee** — something a user or downstream system can
  rely on, that would be a bug if violated (a scoring weight, a field
  the API returns, an access rule) — belongs in the **spec slot** as a
  requirement.
- A **way of working** — a convention the team follows, invisible to the
  product's users (use TDD, run the security gate on auth changes, boot
  the dev server before a UI screenshot) — belongs in the **instruction
  file** as process.
- A **record of past effort** — the phases, plans, and verifications that
  produced the product — belongs in **`docs/legacy-planning/`** as
  history.

The cParX pilot showed the split is usually already clean: its
`CLAUDE.md` was overwhelmingly process, and the one product guarantee
hiding there — the mock-scoring dimension weights (Financial 25% / Legal
20% / ESG 20% / Market 20% / Technical 15%) — was moved into the
capability spec as a requirement, with the instruction file keeping only
a pointer and the prototype-scope framing. A *decision ledger* (the ADR
index) is process/record and stays put; the product invariants those
ADRs reference are what get normatively specified.

## Capabilities are merged, not mirrored

- **MUST** reconstruct `specs/<capability>/` by **merging related work
  into a coherent capability**, not by mirroring one planning phase to
  one spec. A capability is a product surface (e.g. `analysis-pipeline`
  merges phases 03 / 03.5 / 03.6); one-phase-one-spec is a
  non-conforming mirror that recreates `.planning/`'s fragmentation
  inside `specs/`.
- **MUST** exclude from a seed spec what was never product truth —
  operational logging, chat/SSE plumbing not yet built, scaffolding — so
  the spec states guarantees, not implementation incidentals. (The pilot
  correctly left OBS-* logging and unbuilt chat/RAG out of the seed.)

## Requirements — placement

- **MUST** place product guarantees in the spec slot, process in the
  instruction file, and effort history in `docs/legacy-planning/`.
- **MUST NOT** leave a product guarantee stranded in the always-loaded
  instruction file once a spec slot exists; move it to a requirement and
  leave a pointer if navigational context is useful.
- **MUST NOT** delete the `.planning/` history to make room; it is
  moved to `docs/legacy-planning/` (§ Tier 0), never removed.
- **SHOULD** leave a decision ledger (an ADR index, a "key decisions"
  table) in place as process/record even after its referenced invariants
  are specified — gutting a navigational index is not surgical.

## Linear coupling (loose)

The roadmap lives in Linear; the spec slot lives in the repo. They are
**loosely coupled by convention, not synchronized**.

- **SHOULD** reference a Linear issue ID from a change (e.g. in the
  change's `proposal.md`, its slug, or its ship commit) so a reader can
  trace a shipped requirement back to its roadmap item.
- **MUST NOT** build or require a bidirectional sync between Linear and
  the spec slot. There is no obligation for a Linear issue to exist for
  every change, for every Linear issue to have a change, or for state to
  mirror between them. The coupling is a human-followable pointer, not a
  system of record integration.
- A missing Linear reference is at most a SHOULD gap, never a
  conformance failure.

## Scenarios

#### Scenario: a product guarantee is relocated

- **GIVEN** the mock-scoring weights written as a constraint line in
  `CLAUDE.md`
- **WHEN** a spec slot exists
- **THEN** the weight values become a requirement in
  `specs/analysis-pipeline/spec.md`, and `CLAUDE.md` keeps only a pointer
  plus scope framing.

#### Scenario: phases merge into one capability

- **GIVEN** planning phases 03, 03.5, and 03.6 all concerning the
  analysis pipeline
- **WHEN** the seed spec is reconstructed
- **THEN** they merge into a single `analysis-pipeline` capability spec,
  not three phase-shaped specs.

#### Scenario: a change points at Linear

- **GIVEN** a change implementing roadmap item `FAC-482`
- **WHEN** the change is proposed
- **THEN** its proposal or ship commit references `FAC-482`; no sync job
  runs and none is required.

## Conformance

A host implementation:

- **MUST** apply the placement test — product guarantees to the spec
  slot, process to the instruction file, history to
  `docs/legacy-planning/`.
- **MUST** reconstruct capabilities by merging related work, excluding
  non-product content.
- **MUST NOT** synchronize Linear with the spec slot or require a
  Linear ID per change.
- **SHOULD** carry a Linear reference on a change for traceability.
