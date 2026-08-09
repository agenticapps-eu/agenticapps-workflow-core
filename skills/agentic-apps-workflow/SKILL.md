---
name: agentic-apps-workflow
version: 4.0.0
implements_spec: 1.0.0
description: |
  The AgenticApps spec-first workflow. MUST activate on any task that writes or
  changes code, designs architecture, or makes a technical decision — whether or
  not the workflow is mentioned. Triggers on "let's work on X", "implement X",
  "build X", "fix X", "refactor X", a Linear issue number, or a bare "start
  working". Carries the loop, the gates, the coding discipline and the
  task-size routing.
---

# The AgenticApps workflow

Host-neutral. Nothing in this file names a host, and nothing may be added that
does. Your host's command prefix differs (`/opsx:propose`, `$opsx:propose`, …);
the steps do not.

This file **is** `docs/workflow.mmd` in prose. If the two disagree, the diagram
wins and this file is wrong.

## The loop

```
0 Linear issue  →  1 propose  →  2 validate  →  2b plan-review  →  ⟨gate⟩
   →  3 build (TDD + conditional gates)  →  4 code-review  →  5 verify
   →  6 archive  →  7 ship  ↻
```

| # | Move | What it produces |
|---|---|---|
| **0** | Pick the Linear issue | the issue ID, written as a plain string in `proposal.md` |
| **1** | `propose` | proposal + design + **spec delta** + tasks under `openspec/changes/<id>/` |
| **2** | `openspec validate --all` | green, meaning every requirement has a scenario |
| **2b** | plan-review | `REVIEWS.md` — ≥2 agents of *other* vendors adversarially review the delta |
| **gate** | hook · `git commit` · CI | **no code edits before this point** |
| **3** | `apply` | TDD, RED before GREEN, plus the conditional gates below |
| **4** | code-review | an independent reviewer reads the **diff**, not the plan |
| **5** | verification | the diff satisfies the tasks and the spec delta |
| **6** | `openspec archive` | the delta folds into `openspec/specs/` — now current truth |
| **7** | ship | commit · PR · changelog · version · close the issue |

Archiving and shipping are **two separate acts**. So are validating and
reviewing.

## What the gate actually blocks

**One condition: `openspec validate --all` is not green.** A blocked edit means
a spec delta that does not parse. Fix the delta. It never means "go get a
review".

Review evidence is **computed and reported, never enforced**. Reviewer count,
verdicts, independence and the trailer all produce `NOTE` lines; none fails any
surface — not the hook, not the pre-commit hook, not `--ci`. Two rejections open
the gate exactly as two approvals do. There is no escape hatch, because there is
nothing to escape.

> A green gate is therefore the **weakest possible evidence** that anyone read
> the delta. Nothing makes you run the reviewers. Step 2b is a discipline you
> keep, not one the machine keeps for you. If the gate prints a `NOTE` naming
> objectors, address it or record why not.

## Step 0 — the commitment ritual

Before the first tool call on any code-touching turn, emit this. It takes
fifteen seconds. The announcement *is* the commitment.

```
Task size:   tiny | small | medium | large
Change:      <openspec change id, or "none needed because …">
Gates due:   <from the table below>
Skills:      <the ones you are about to invoke, in order>
```

## Task size decides the route

| Size | Route |
|---|---|
| **Tiny** — typo, comment, README | `verification-before-completion` |
| **Small** — one file, contained logic | `test-driven-development` → `verification-before-completion` → `finishing-a-development-branch` |
| **Medium** — multi-file feature | the **full loop**. Stage-2 `requesting-code-review` and an ADR for any locked decision are mandatory |
| **Large** — cross-cutting | as Medium, plus every applicable conditional gate below |

A **bug** goes straight to `systematic-debugging` — Observe →
Hypothesize → Test → Conclude — before any fix is proposed.

The gate engages only once a change is open, so tiny and small work may proceed
without one. That is a permission, not an invitation to reclassify a medium
task as small.

## Gates

Always, on every change:

| Gate | Skill | When |
|---|---|---|
| brainstorm | `brainstorming` | before proposing anything creative |
| plan-review | `openspec-change-review` | step 2b — writes `REVIEWS.md` |
| tdd | `test-driven-development` | every task, RED before GREEN |
| code-review | `requesting-code-review` | step 4, on the diff |
| verification | `verification-before-completion` | step 5 |
| branch-close | `finishing-a-development-branch` | step 7 |
| security | `cso` | always |

Conditionally, by what the change touches:

| Touches | Gate | Skill |
|---|---|---|
| UI | qa | `qa` |

Every skill named above is **upstream, bound by this workflow and not owned by
it.** Never vendor a copy into a project or into core; bind the installed one.
If a gate's skill is absent, say so and continue — a missing upstream tool is
reported, never silently skipped and never a block.

**Name them unprefixed, as written above.** The six discipline skills come from
`superpowers`, which on one host arrived as a plugin and was addressable as
`superpowers:test-driven-development`. That prefix is a fact about one host's
packaging, not part of any skill's name, and a table written in it produced a
failed lookup on every host that installs the same skills a different way.
`install.sh` now binds one checkout into all of them, so the plain name resolves
everywhere and is the only name that does.

**Two conditional gates carry no skill, deliberately.** `database-security` and
`design` are still defined in §02 — this workflow just binds nothing to them.
`database-sentinel` was removed from every host, and `impeccable` is installed
everywhere but invoked **on demand** rather than fired automatically on any UI
change. Nothing blocks branch close on either any more (ADR-0030, superseding
ADR-0011 and ADR-0012). Bind a skill to either gate if you want it back.

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

## Rationalisation table — check before skipping anything

| The thought | The answer |
|---|---|
| "Too small for the ritual" | It takes fifteen seconds. Skipping it is how discipline erodes. |
| "The skill is obvious, no need to announce it" | The announcement *is* the commitment. |
| "TDD is impractical here" | Snapshot tests, screenshot diffs and visual regression all count. Write the test first. |
| "I already considered the alternatives" | If you did not write them down, you did not consider them. |
| "`validate` is green, so the delta is reviewed" | Validate is a schema check. It cannot tell you the delta describes the wrong behaviour. That is what step 2b is for. |
| "The gate passed, so this is fine" | The gate only checked that the delta parses. It is not a reviewer. |
| "One model's spec delta is fine" | Different vendors catch different blind spots, and 2b runs *before code exists*, where a fix is cheapest. |
| "Two-stage review is excessive" | Stage 1 catches spec drift, stage 2 catches code drift. Different failures, different readers. |
| "The user said ship fast" | Acknowledge the urgency, state the risk in one sentence, offer the minimum discipline that protects the critical path. |

## Red flags — stop, delete, restart

- Code edited while `validate` is red.
- A change opened after the code was written, to justify it.
- A spec delta edited to match the code instead of the code to match the delta.
- `REVIEWS.md` written by the same vendor that wrote the delta.
- Tasks ticked off with no diff that satisfies them.
- An archive that folds a delta the code never implemented.
- "Done" claimed without running the verification command and reading its output.

## Done means

Before claiming completion, run the check and read the output — do not assert it:

- `openspec validate --all` is green.
- The spec slot states the new truth; the delta was folded, not merely moved.
- TDD produced a RED then a GREEN.
- An independent reader reviewed the diff. Validate does not discharge this.
- Every task in the change is checked off.
- The working tree is clean and the branch is a feature branch, never `main`.
