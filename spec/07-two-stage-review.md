---
id: 07-two-stage-review
section_type: declarative-contract
spec_version: 0.1.0
---

# 07 — Two-Stage Review

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and
agent-binding mechanisms are at the host's discretion. The keywords
MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Concept

Spec compliance and code quality are different failure modes. A
review pass that mixes them catches less of each.

- **Stage 1 — Spec compliance**: did this phase's changeset honor the
  CONTEXT.md decisions, satisfy every `must_have`, follow the gate
  bindings, and avoid protocol violations?
- **Stage 2 — Code quality**: is the resulting code idiomatic,
  well-named, free of obvious bugs, and consistent with the
  surrounding style?

These are separate concerns and MUST be reviewed by separate agent
invocations. This pairs with the `spec-review` and `code-review`
gates in section 02.

## Requirements

### Order

- **MUST** run Stage 1 before Stage 2. A Stage 2 review of a
  spec-noncompliant changeset wastes reviewer attention on code
  that may not survive the Stage 1 fix.

### Independence

- **MUST** perform Stage 2 in an independent reviewer context. The
  spec is silent on the mechanism — sub-agent invocation, second
  session in a fresh context, second human reviewer, separate CI
  job — but Stage 1 and Stage 2 MUST NOT share the same agent
  invocation, the same conversation context, or the same role.
- **MUST NOT** allow the implementer agent to author Stage 2. Even
  if the implementer is freshly re-invoked, sharing the
  implementation context biases the review.
- **SHOULD** prefer a sub-agent or fresh session over a second pass
  in the same session, because conversation-context bias is the
  most common source of review collapse.

### Artifact

- **MUST** record both stages in a single REVIEW.md (or
  host-equivalent review document) under separate top-level
  headings (`## Stage 1 — Spec compliance` and `## Stage 2 — Code
  quality`).
- **MUST** include in Stage 1 at minimum: protocol-violation flags
  (e.g. missing commitment ritual, missing brainstorm artifact,
  missing TDD commit pair), `must_have` coverage gaps, and gate
  evidence gaps.
- **MUST** include in Stage 2 at minimum: code-style consistency
  notes, naming concerns, obvious-bug scan results, and a summary
  verdict (`pass` / `pass-with-followups` / `block`).
- **SHOULD** link each finding to a specific file:line in the
  changeset.

### Forbidden collapses

The following patterns are non-conformant:

- A single "review" pass that addresses both spec and code in one
  document under one heading.
- A Stage 2 review authored by the same agent invocation that
  authored Stage 1 (even if the agent claims to "switch hats").
- A Stage 2 review that defers to "we'll catch code-quality issues
  in PR review" without producing a Stage 2 artifact.
- Skipping Stage 2 because Stage 1 found blocking issues — Stage 1
  blockers are fixed, then both stages re-run; Stage 2 is not
  optional.

## Conformance

A host implementation:

- **MUST** wire the `spec-review` and `code-review` gates such that
  the bound skills run in different agent contexts.
- **MUST** produce a REVIEW.md (or equivalent) per phase containing
  both stages.
- **SHOULD** automate the order: `code-review` does not fire until
  `spec-review` has produced its artifact.
- **MAY** add additional review stages for host-specific concerns
  (e.g. a Stage 3 accessibility review for UI-shipping hosts) so
  long as Stage 1 and Stage 2 remain distinct and independent.
