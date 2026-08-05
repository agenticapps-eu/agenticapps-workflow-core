---
id: 11-coding-discipline
section_type: canonical-prose
spec_version: 0.4.0
---

# 11 — Coding Discipline

**Section type**: canonical prose. The block below MUST be reproduced
verbatim in **the trigger skill** (`skills/agentic-apps-workflow/`).
Substitution is permitted only inside `{{...}}` placeholders;
alteration of any surrounding prose is non-conformant.

> **Changed 2026-08-05.** This section previously required the block in
> *every project's* primary instruction file. That produced one copy per
> project — ~80 lines each across the fleet, loaded into context every
> session, drifting independently and impossible to correct in one place.
> One copy in the trigger skill reaches every host, because the skill is
> host-neutral and symlinked rather than vendored.
>
> The obligation the old wording protected — that the model actually reads
> it — is preserved by *when* the skill fires: on any code-touching turn,
> which is the scope the block itself claims in its closing paragraph. A
> project MAY still restate it, but MUST NOT be required to, and a project
> that omits it is conformant.

**Provenance**: distilled from public discussion of recurring failure
modes in coding-agent output (Karpathy, 2025-2026), as gathered in the
community skill collection `multica-ai/andrej-karpathy-skills`. The
spec's contribution is the canonical wording, the section-type
classification, and the conformance obligation. Conformance requires
the verbatim block below, not the provenance.

## Canonical block

````
## Coding Discipline (NON-NEGOTIABLE)

These four rules are reread every session because the failure modes
they prevent recur every session.

### 1. Think Before Coding

State assumptions explicitly before writing any line. When the request
is ambiguous, present the alternative interpretations and ask which
applies. When the request contradicts itself, surface the contradiction
rather than silently picking one side. When you are confused, stop and
ask — confusion is signal, not friction.

Anti-patterns this rule prevents:

- Diving into implementation without restating what was actually requested.
- Picking one reading of an ambiguous instruction silently and shipping it.
- Treating two contradictory requirements as if both can be satisfied without comment.
- Treating "I'll figure it out as I go" as a substitute for understanding the goal.
- Generating code first and asking clarifying questions only after a failure.

### 2. Simplicity First

Write the smallest thing that satisfies the request. No features
beyond what was asked. No abstractions for code with one caller. No
flexibility for callers that do not exist. No error handling for
scenarios that cannot occur given the code's invariants. The
senior-engineer test: would a senior engineer reviewing this say it is
overcomplicated for what was asked?

Anti-patterns this rule prevents:

- Adding a helper function "in case we need to call this from elsewhere later."
- Introducing a configuration option for behavior that has one consumer.
- Wrapping internal calls in try/catch when no internal caller throws.
- Designing for a hypothetical second consumer that does not exist.
- Replacing three similar lines with a parameterised abstraction.
- Shipping a "framework" when a function would do.

### 3. Surgical Changes

Touch only what you must to satisfy the task. Adjacent code is out of
scope. Match the existing style of the file you are editing rather than
the style you would have chosen. Clean up only the orphans your own
change created. If you notice an unrelated improvement, leave it as a
follow-up note, not a diff.

Anti-patterns this rule prevents:

- Reformatting untouched lines to "fix style" while editing nearby.
- Refactoring a function that the task did not name.
- Renaming a variable across the file because the new name is "better."
- Deleting code you decided is unused without verifying it has no callers.
- Pulling adjacent code into the diff because "while I'm here."
- Bundling a cleanup pass into a feature commit.

### 4. Goal-Driven Execution

Every task is a goal, not a list of imperative steps. Restate the goal
in a form that is verifiable from on-disk artifacts before writing any
code. For bug fixes: write the failing test that reproduces the bug
first, then make it pass. For performance work: capture the measurement
first, then change the code, then capture it again. For behavioral
changes: define the assertion the diff must satisfy before the diff
exists. "Done" is "the goal is verifiably satisfied," not "the code now
exists."

Anti-patterns this rule prevents:

- "Fix the bug" without a failing test that reproduces it.
- "Improve performance" without a measurement before and a measurement after.
- "Make it work" without a definition of "work" the diff can be checked against.
- Marking a task complete on the basis of "the code now exists" rather than "the goal is satisfied."
- Writing implementation before there is anything that can fail to confirm the goal is met.

These four rules apply to every code-touching turn. They do not
replace the commitment ritual, the rationalisation table, the red
flags, or the evidence rules — they sit alongside them as the
session-level discipline the model brings to every diff.
````

## Conformance

- The **trigger skill** MUST reproduce the canonical block above
  verbatim. Substitution is permitted only inside `{{...}}`
  placeholders; alteration of any surrounding prose, including the rule
  numbers and the anti-pattern bullets, is non-conformant.
- There is exactly **one** copy. A project MUST NOT be required to carry
  one, and a project that carries none is conformant.
- A project **MAY** restate the block, or add anti-pattern bullets for
  failure modes peculiar to that codebase. Additions layer on top; they
  neither satisfy nor alter the canonical bullets. A restatement that has
  drifted from the canonical block is a defect in the project, not a
  second authority.

Projects that ship coding-discipline prose under a different heading
(e.g. "Engineering principles," "Coding rules") SHOULD delete it in
favour of the skill's copy, rather than reconcile two texts.
