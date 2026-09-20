# ADR-0032: The workflow loads no book rule set during apply

**Status:** Accepted
**Date:** 2026-09-20
**Linear:** —

## Context

Three book rule sets (`the-pragmatic-programmer`, `refactoring`,
`domain-driven-design-distilled`) are installed machine-wide and bound to loop
steps by `bind-rule-sets-to-the-loop`. The apply step was the open question: a
standing rule set during implementation is the intuitive choice, and it is the
one place in the loop where context is scarcest.

## Decision

The workflow loads no book rule set for the apply step. A rule set the operator
names explicitly is honoured; this governs what the workflow loads unasked.

## Rejected alternatives

- **`the-pragmatic-programmer` at `nano` as a standing floor during apply.**
  The implementer already carries exploration, the spec delta, the tasks and the
  test loop. The books have done their work upstream, in the delta the
  implementer is building to, and `codebase-design` remains model-invoked and
  fires when an interface is being shaped — the one discipline implementation
  genuinely needs is still present. The ETH Zurich evaluation of repository
  context files is the external evidence: instructions are followed faithfully,
  task success does not improve, and cost rises over 20%. A floor that is paid
  for on every turn must earn it on some turn.
- **All four steps read the same books.** Uniform is not cheaper; it is the same
  cost repeated where no decision is being made.

## Consequences

Hard to reverse in the sense that matters: it fixes what the implementing step
is allowed to be told, and every later step inherits that context. Reversing it
is one table row plus a spec scenario, but the reason to reverse it should be
measured rather than felt — the follow-up read (findings per review round, diff
size, tokens) is where that evidence comes from. A book that changes nothing
costs tokens for nothing.
