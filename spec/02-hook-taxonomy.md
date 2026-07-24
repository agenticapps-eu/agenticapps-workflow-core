---
id: 02-hook-taxonomy
section_type: declarative-contract
spec_version: 1.0.0
---

# 02 — Hook Taxonomy

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and
skill names are at the host's discretion. The keywords MUST, MUST NOT,
SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

> **Remapped at spec v1.0.0.** This gate taxonomy is the 0.x (GSD-engine)
> front end and remains **normative for hosts that cite a 0.x version**.
> A host that cites **1.0.0 or later** implements the OpenSpec front end:
> the gates below are *remapped* onto the OpenSpec lifecycle by §17 (the
> gate-mapping table) — `plan-review` and `spec-review` collapse into
> `validate`, `code`/`tdd`/`verification`/`security` are retained, and
> the design/database/qa gates stay conditional. §18 retargets the
> `plan-review` enforcement hook to the OpenSpec change-gate. This
> section is not deleted; it is superseded for 1.0.0 hosts. See ADR-0021.

## Concept

A **gate** is a named control point in the workflow lifecycle. The
spec defines the gate names, when each gate fires, and what evidence
artifact each gate produces. The spec does **not** specify which
skill, plugin, or tool the host uses to satisfy a gate — that
binding is host-specific data and lives in the host's own
instruction file or workflow-config.

The complete gate list is normative. Adding host-specific extension
gates is permitted (a host MAY define additional gates beyond this
list); removing or renaming the gates below is non-conformant.

## Gate definitions

Each gate has four fields: **name**, **when fires**, **required
evidence artifact**, and **binding guidance**.

### Pre-phase gates

#### `brainstorm-ui`

- **When fires**: a phase contains at least one plan that introduces
  or modifies a frontend component, route, or visual surface, AND no
  prior CONTEXT.md exists with a "Design alternatives" section for
  this UI scope.
- **Required evidence artifact**: the phase's CONTEXT.md MUST contain
  a section listing at least two named UI alternatives with
  trade-offs.
- **Binding guidance**: hosts bind a concrete brainstorming skill or
  prompt template to this gate. The binding lives in the host's
  instruction file.

#### `brainstorm-architecture`

- **When fires**: a phase contains at least one plan that introduces
  a new service, model, integration, or data shape, AND no prior
  CONTEXT.md or RESEARCH.md exists with an "Architecture
  alternatives" section for this scope.
- **Required evidence artifact**: the phase's RESEARCH.md or
  CONTEXT.md MUST contain at least two named architectural
  alternatives with trade-offs.
- **Binding guidance**: hosts bind a brainstorming or research skill
  to this gate.

#### `design-shotgun`

- **When fires**: a phase has at least one UI plan AND no UI-SPEC.md
  exists for the surface being built.
- **Required evidence artifact**: at least three rendered visual
  variants (screenshots, sketches, or mockup URLs) MUST be referenced
  from CONTEXT.md or UI-SPEC.md, with the user's chosen variant
  marked.
- **Binding guidance**: hosts bind a multi-variant design generation
  skill (typically combining a generation skill with a browser-driven
  preview).

#### `design-critique`

- **When fires**: a UI plan with an existing UI-SPEC.md, before
  implementation begins.
- **Required evidence artifact**: a critique document (commit message,
  REVIEW-style block, or skill output) referenced from the phase
  artifacts that names at least one specific design issue and its
  remediation.
- **Binding guidance**: hosts bind a designer-eye review skill.

### Pre-execution gate

#### `plan-review`

- **When fires**: after a phase's plans exist (one or more `*-PLAN.md`)
  and before the first code-touching execution edit, UNLESS the phase
  has already been executed (a `*-SUMMARY.md` artifact exists — see
  grandfather rule below).
- **Required evidence artifact**: a per-phase `REVIEWS.md` containing
  independent plan review from at least two external AI reviewers
  (adversarial review of the plan before any code is written).
- **Binding guidance**: hosts bind a multi-AI plan-review skill and
  SHOULD enforce it with a programmatic gate. The enforcing gate MUST
  resolve the active phase robustly: relying on a single mutable
  pointer (e.g. a `current-phase` symlink) is non-conformant when that
  pointer is also used for another purpose (an observed failure mode —
  see ADR-0025). Recommended resolution order is an explicit phase
  pointer → workflow state (`current_phase`) → newest plan artifact by
  mtime → fail-open (allow). The gate MUST **grandfather** already-
  executed phases — when a `*-SUMMARY.md` exists for the resolved
  phase, the gate MUST allow the edit — so that enabling enforcement
  never retroactively blocks work in repositories that shipped phases
  before the gate functioned.

> **Host conformance (follow-up):** claude-workflow implements this
> resolver and grandfather guard as of spec 0.5.0 (ADR 0025 / migration
> 0016). codex-workflow and pi-agentic-apps-workflow MUST adopt the
> identical resolution order and grandfather rule to stay conformant —
> tracked as a follow-up, not yet implemented.

### Per-task / execution gates

#### `tdd`

- **When fires**: any task with the `tdd="true"` marker (or host
  equivalent) on a plan whose changeset will include logic
  verifiable by automated test.
- **Required evidence artifact**: the git history MUST contain an
  atomic commit pair: a commit prefixed `test(RED):` (or equivalent)
  that adds the failing test and demonstrably fails when run, followed
  by a commit prefixed `feat(GREEN):` (or equivalent) that makes the
  test pass. An optional `refactor:` commit MAY follow.
- **Binding guidance**: hosts bind a test-driven-development skill or
  enforcement extension that observes the commit sequence.

#### `ui-preview`

- **When fires**: a task modifying any frontend component, route, or
  visual surface, before the task's commit lands.
- **Required evidence artifact**: a screenshot file path (or browser
  artifact reference) referenced from the commit message or
  SUMMARY.md, taken against a running dev server with the change
  applied.
- **Binding guidance**: hosts bind a browser-driven screenshot skill
  paired with a dev-server boot procedure.

#### `verification`

- **When fires**: before any task is marked complete (i.e. before any
  `TaskUpdate --completed` or host-equivalent state transition).
- **Required evidence artifact**: at least one piece of on-disk
  evidence per `must_have` from VERIFICATION.md. See section 06 for
  the evidence-shape contract.
- **Binding guidance**: hosts bind a verification-before-completion
  skill that produces the evidence and refuses completion if it is
  absent.

### Post-phase gates

#### `spec-review`

- **When fires**: after all execution tasks complete, before phase
  verification.
- **Required evidence artifact**: REVIEW.md MUST contain a "Stage 1 —
  Spec compliance" section enumerating spec drift, missing
  `must_have` coverage, and protocol-violation flags.
- **Binding guidance**: hosts bind a spec-compliance review skill.
  Stage 1 and Stage 2 (`code-review`) MUST NOT be the same agent
  invocation. See section 07.

#### `code-review`

- **When fires**: after `spec-review` completes, before phase
  verification.
- **Required evidence artifact**: REVIEW.md MUST contain a "Stage 2 —
  Code quality" section authored by an independent reviewer agent
  (sub-agent invocation, separate session, or different person).
- **Binding guidance**: hosts bind a code-review skill that runs in a
  fresh agent context, distinct from the implementer's context.

#### `security`

- **When fires**: any phase where the changeset touches authentication,
  storage, request handling, secret material, or LLM trust boundaries.
- **Required evidence artifact**: SECURITY.md (or equivalent host
  artifact) referenced from the phase's VERIFICATION.md, listing
  audited threat models and mitigation evidence. When the changeset
  touches an LLM prompt-building path, SECURITY.md MUST record §14
  (prompt-injection defense) conformance evidence for the affected
  surface.
- **Binding guidance**: hosts bind a security-audit skill. The audit
  checks §14 conformance on LLM-scoped phases.

#### `database-security`

- **When fires**: any phase where the changeset touches database
  schema, RLS rules, security definer functions, or storage policies.
- **Required evidence artifact**: a database-audit report (e.g.
  database-sentinel output, RLS audit summary) referenced from
  SECURITY.md or VERIFICATION.md.
- **Binding guidance**: hosts bind a database-security audit skill.
  See ADR-0012.

#### `qa`

- **When fires**: any phase that ships a user-visible behavior AND a
  dev server is reachable on a host-known local port.
- **Required evidence artifact**: a QA report file (or report URL)
  referenced from VERIFICATION.md, with at least one live-app
  interaction logged.
- **Binding guidance**: hosts bind a browser-driven QA skill.

#### `impeccable-audit`

- **When fires**: any phase whose changeset modifies the visual
  surface of a shipping UI (typography, color, layout, spacing,
  motion). MAY also be invoked retroactively.
- **Required evidence artifact**: an impeccable-audit report
  referenced from REVIEW.md or VERIFICATION.md.
- **Binding guidance**: hosts bind a design-quality audit skill. See
  ADR-0011.

#### `db-pre-launch-audit`

- **When fires**: before a host's first production launch and after
  any major DB migration.
- **Required evidence artifact**: a database-audit report referenced
  from a launch-readiness artifact (e.g. SECURITY.md, RELEASE.md).
- **Binding guidance**: hosts bind a database-security audit skill,
  typically the same one bound to `database-security`. See ADR-0012.

### Finishing gate

#### `branch-close`

- **When fires**: when a feature branch is ready to merge.
- **Required evidence artifact**: a PR description (or equivalent
  merge-request body) that summarizes shipped scope, links phase
  artifacts (CONTEXT.md, PLAN.md, VERIFICATION.md, REVIEW.md), and
  documents any remaining `should_have` gaps.
- **Binding guidance**: hosts bind a branch-finishing skill that
  composes the description from the phase artifacts.

## Conformance

A host implementation:

- **MUST** define a binding for every gate above whose trigger
  condition can occur in the host's project type. Gates whose trigger
  cannot occur (e.g. `database-security` in a project with no
  database) MAY be omitted with a documented justification.
- **MUST** name the gate by the canonical name above (in any case
  convention) when referring to it in host documentation.
- **MUST NOT** rename gates or merge two gates into one. The named
  pair `spec-review` and `code-review` is particularly load-bearing —
  collapsing them is non-conformant (see section 07).
- **SHOULD** document the host-specific binding for each gate in a
  single host file (a hook-bindings table or workflow-config).
- **MAY** define additional gates beyond this list to cover
  host-specific concerns.
