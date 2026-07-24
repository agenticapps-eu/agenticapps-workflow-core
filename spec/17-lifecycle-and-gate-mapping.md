---
id: 17-lifecycle-and-gate-mapping
section_type: declarative-contract
spec_version: 1.0.0
---

# 17 — Lifecycle & Gate Mapping

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and
binding mechanisms are at the host's discretion. The keywords MUST,
MUST NOT, SHOULD, SHOULD NOT, and MAY are used per
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

**Introduced at spec v1.0.0.** This section defines the OpenSpec-era
work lifecycle and maps the 0.x gate taxonomy (§02) onto it. A host that
cites 1.0.0 or later implements this lifecycle; §02 remains normative for
hosts citing a 0.x version. See ADR-0021.

## Concept

The 0.x front end was the GSD engine: a phase moved
CONTEXT → PLAN → execute → VERIFY → REVIEW, and a fixed set of gates
(§02) fired at known points. The OpenSpec front end keeps the *execution
discipline* (Superpowers — TDD, evidence, independent code review) and
replaces the *planning discipline* (GSD phases) with an OpenSpec change.

## The lifecycle

Every unit of product work moves through four stages:

1. **Propose** — open a change with the OpenSpec CLI (e.g.
   `openspec new change <slug>`) and author its artifacts: a proposal, a
   design note, a spec delta (the requirements this change adds, modifies,
   or removes), and a task list. Superpowers `brainstorming` feeds the
   design note when the change introduces UI or new architecture (the
   former `brainstorm-*` and `design-*` gates fold in here).

2. **Validate** — `openspec validate --all` MUST be green, **and** the
   change MUST carry independent multi-AI review (see §18) *before any
   code is written*. This single stage absorbs **both** 0.x review gates:
   `openspec validate` checks the delta against the spec slot (what
   `spec-review` did after the fact), and the multi-AI review
   adversarially reviews the proposed change (what `plan-review` did). The
   review earns its keep here — the cParX pilot's reviewer caught a real
   semantic defect *in the spec delta* before implementation.

3. **Superpowers-execute** — implement the tasks under the retained
   execution gates: TDD (RED→GREEN), verification (on-disk evidence per
   §06), independent Stage-2 code review, and any conditional gates that
   the changeset triggers (security, database, qa, design, lint). The
   retargeted change-gate (§18) blocks code edits until stage 2
   (validate + review) has passed for the active change.

4. **Archive** — fold the spec delta into `specs/<capability>/spec.md`
   so the spec slot states the new truth, then `openspec archive` the
   change into `changes/archive/<date>-<slug>/`. **Then** ship (the git
   commit + changelog entry) as a separate act.

## `archive ≠ ship`

- **MUST** treat archiving and shipping as two distinct operations.
  `openspec archive` folds the delta and moves the change directory but
  produces **no git commit**; shipping is the separate git step. The
  cParX pilot confirmed this boundary reproducibly.
- **MUST NOT** collapse the two into a single command that both folds
  the spec and pushes — the fold is a spec-slot operation reviewable on
  its own; the ship is a VCS operation with its own gate (`branch-close`
  / PR).

## Gate mapping

The §02 gates do not disappear; they are **remapped** onto the OpenSpec
lifecycle. Three fates:

- **Collapsed** — the gate's job is now done by a lifecycle stage.
- **Retained** — the gate survives unchanged as a Superpowers execution
  gate; it fires on the same trigger, now inside stage 3.
- **Conditional** — the gate is retained but fires only when the
  changeset triggers it (unchanged from §02's trigger semantics).

| §02 gate | Fate under 1.0.0 | Where it lives now |
|---|---|---|
| `plan-review` | **Collapsed → validate** | Stage 2. Multi-AI review of the change *before code* (§18), enforced by the retargeted change-gate. |
| `spec-review` | **Collapsed → validate** | Stage 2. `openspec validate --all` checks the delta against the spec slot. The former Stage-1 "spec compliance" pass becomes a machine check plus the pre-code review. |
| `code-review` | **Retained** (always) | Stage 3. Independent Stage-2 code-quality review still fires; `validate` does not read code. §07's independence rule still binds. |
| `tdd` | **Retained** | Stage 3. Superpowers TDD; RED→GREEN commit pair per §02. |
| `verification` | **Retained** | Stage 3. On-disk evidence per §06 before a task completes. |
| `security` | **Retained — always** | Stage 3. Fires on every change touching auth, storage, request handling, secrets, or an LLM trust boundary. Never conditional-away in a product host. Checks §14 on LLM-scoped changes. |
| `brainstorm-ui` | **Conditional (design)** | Stage 1. Folds into the design note when the change has a UI surface. |
| `brainstorm-architecture` | **Conditional (design)** | Stage 1. Folds into the design note when the change adds a service/model/integration. |
| `design-shotgun` | **Conditional (design)** | Stage 1/3. Fires for a UI change with no design contract yet. |
| `design-critique` | **Conditional (design)** | Stage 1/3. Fires for a UI change with an existing design contract. |
| `impeccable-audit` | **Conditional (design)** | Stage 3. Fires when the change alters a shipping visual surface. |
| `ui-preview` | **Conditional (design)** | Stage 3. Screenshot evidence for a frontend change. |
| `database-security` | **Conditional (db-sentinel)** | Stage 3. Fires when the change touches schema, RLS, definer functions, or storage policy. |
| `db-pre-launch-audit` | **Conditional (db-sentinel)** | Stage 3. Fires before first production launch / after a major DB migration. |
| `qa` | **Conditional** | Stage 3. Fires when the change ships user-visible behavior and a dev server is reachable. |
| `branch-close` | **Retained** (ship) | Stage 4. The ship step: PR body links the change (`changes/archive/<date>-<slug>/`) and its evidence. |
| `ts-declare` (§13) | **Mapped → lint** | Stage 3. The declare-first TS discipline (§13) is enforced as a lint gate on TS changes rather than a bespoke gate. |

## Requirements

- **MUST** move every unit of product work through propose → validate →
  Superpowers-execute → archive.
- **MUST** satisfy stage 2 (`openspec validate --all` green **and**
  multi-AI review present) before any code edit for the active change;
  §18 specifies the enforcing gate.
- **MUST** retain the `code-review` gate as an independent Stage-2 pass
  (§07) — `openspec validate` is a spec check, not a code review, and
  does not discharge it.
- **MUST** fire the `security` gate on every triggering change; it is
  never conditional-away in a host that ships product code.
- **MUST** fire the conditional gates (design, database, qa, lint) on
  their §02 trigger conditions when those conditions occur.
- **MUST** keep `archive` and `ship` distinct.
- **MUST NOT** reintroduce a standalone `plan-review` or `spec-review`
  gate under 1.0.0; their obligations are discharged by stage 2. A host
  MAY keep the *names* as aliases in documentation, but the enforcement
  surface is the §18 change-gate plus `openspec validate`.

## Scenarios

#### Scenario: review before code

- **GIVEN** an open change with a validated spec delta but no code yet
- **WHEN** the agent attempts to edit a source file
- **THEN** the change-gate (§18) blocks the edit until the change carries
  `REVIEWS.md` with ≥2 independent reviewers and `openspec validate
  --all` is green — collapsing plan-review and spec-review into one
  pre-code stage.

#### Scenario: code review still fires

- **GIVEN** a change that passed stage 2 and whose tasks are implemented
- **WHEN** the implementer marks the work ready
- **THEN** an independent Stage-2 code-quality review (§07) MUST still
  run in a fresh context; validate-green does not substitute for it.

#### Scenario: archive then ship

- **GIVEN** a done change (delta folded, validate green)
- **WHEN** `openspec archive` runs
- **THEN** the delta is folded and the change dir moves to `archive/`
  with **no** git commit; the ship (commit + changelog) is a separate,
  subsequent act gated by `branch-close`.

## Conformance

A host implementation:

- **MUST** implement the four-stage lifecycle and the gate mapping above.
- **MUST** retain `code-review`, `tdd`, `verification`, and `security`
  as execution gates, and fire the conditional gates on their triggers.
- **MUST NOT** ship a `plan-review`/`spec-review` enforcement surface
  separate from stage 2.
- **SHOULD** document the mapping in a single host-side table so a
  reader can see, per gate, whether it collapsed, was retained, or is
  conditional.
