---
id: 01-commitment-ritual
section_type: canonical-prose
spec_version: 0.1.0
---

# 01 — Commitment Ritual

**Section type**: canonical prose. Host implementations MUST reproduce
the block below verbatim in their host-instruction file (e.g.
`SKILL.md` or the host's equivalent project-instruction file).
Substitution of values within placeholders `{{...}}` is permitted at
runtime when the agent emits the block; substitution of any text
outside placeholders, or alteration of the surrounding prose, is
non-conformant.

The block is the agent's first user-facing output of any code-touching
turn. It is the Cialdini commitment device that the rest of the
workflow leverages: once stated publicly, the agent is consistent with
its own plan.

## Canonical block

````
## Step 0 — The Commitment Ritual (NON-NEGOTIABLE)

As the FIRST user-facing output of your turn, before any tool call or
clarifying question, you MUST emit a `## Workflow commitment` block:

```
## Workflow commitment

I am using the agentic-apps-workflow skill for this task.
Task scope: {{one-sentence description}}
Task size: {{tiny | small | medium | large}}

Skills I will invoke, in order:
1. {{skill-name}} — {{why it applies}}
2. {{skill-name}} — {{why it applies}}
...

Post-phase gates (if applicable): {{review | cso | qa}}
Verification evidence I will produce: {{list of artifacts}}

Once I have stated this plan, I am committed to it. Deviating without
explicit user approval is a protocol violation.
```

Skipping this ritual is itself a protocol violation. You cannot rationalize
your way out of it — see the rationalization table below.
````
