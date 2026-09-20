# Design

## Two mechanisms, because the reviewers are not hosts

| Step | Who reads the rule set | How it arrives |
|---|---|---|
| grilling, propose, code-review | the agent running the workflow skill | prose in the skill |
| plan-review | third-party vendor CLIs, spawned headless | the producer's prompt |

The split is forced, not stylistic. `run-plan-review.sh` invokes gemini, codex,
claude and opencode through `reviewer-cli.sh` with the prompt as a file. Those
processes never loaded `agentic-apps-workflow`, so prose there reaches nobody;
the prompt is the only channel.

## Where the lens sits in the prompt

Appended to `INSTRUCT`, which is emitted above the `--- CHANGE:` marker. Two
properties follow, and both are asserted:

- **Not evidence.** Below the marker it would read as part of the change under
  review — a reviewer could "find" a requirement the author never wrote.
- **Not in the digest.** The digest set is `proposal.md`, `design.md` and
  `specs/**/*.md`. Prompt text is outside it, so adding the lens does not stale
  a single review written before today.

## Degradation

Three ways the lens can fail to arrive: the machine has no rule sets installed,
the vendor arm does not resolve skills (gemini, opencode), or a rename upstream
breaks the name. All three land on the same clause: review without them and say
so. A silent half-review is the outcome worth designing against — it reads
exactly like a full one.

## Decisions that are not locked

- The book-to-step mapping. Changing it is an edit to one table.
- `release-it` and DDIA as conditional reads: neither is installed; the row is a
  pointer for when a change touches that ground.
- Producer version 1.2.0 → 1.3.0 rather than 2.0.0: the prompt grew, no
  interface moved, and every existing REVIEWS.md stays valid.

## The locked decision

**Apply reads nothing.** It is hard to reverse in the sense that matters — it
sets what the implementing step is allowed to be told, and everything later
inherits it — and it is a real trade-off against the alternative of a standing
`nano` floor during implementation.

Rejected: **Pragmatic `nano` at apply.** A standing floor sounds cheap and is
not: the implementer already carries exploration, the spec delta, the tasks and
the test loop, and the ETH result says instructions are obeyed and paid for
whether or not they help. The rules have already done their work upstream, in
the delta the implementer is building to. `codebase-design` remains
model-invoked and fires on interface work, so the one discipline implementation
genuinely needs is still there.

Rejected: **wiring code-review like plan-review.** It would mean patching
`requesting-code-review`, which is upstream Superpowers — vendoring, forbidden
by ADR-0024, and undone by the next update.

Rejected: **installing more books.** `clean-code` overlaps
`the-pragmatic-programmer`; `a-philosophy-of-software-design` overlaps
`codebase-design`. ciembor's own compatibility matrix rates the first pair as
overlapping rather than complementary.

## Risk carried, not solved

The rule-set names are upstream strings. A rename breaks the lens silently in
the producer and noisily in the skill (which reports a missing skill). This is
the same exposure as the tracker pointer in `adr-home-for-bound-skills`, and it
is accepted for the same reason: binding beats vendoring, and the failure is
degradation rather than a wrong answer.

## Plan-review round 1 (codex REQUEST-CHANGES; gemini, opencode exit 1)

Accepted, and each fixed:

- **Two mappings for plan-review.** The step table said Pragmatic; the producer
  sent Pragmatic and `refactoring`. The producer was wrong — this step reads a
  delta, `refactoring` reads diffs — so the lens drops it, and a conformance row
  now asserts the prompt does *not* name it.
- **The digest row proved the wrong thing.** It compared two runs of the same
  producer with `tasks.md` edited. It now builds a pre-lens copy by stripping
  the lens paragraph and compares that producer's digest with this one's, which
  is the claim that matters for reviews written before today.
- **"SHALL continue and complete" overreached.** Narrowed: the missing rule set
  *alone* does not block; other failures of the step still do.
- **Missing scenarios.** Added: partial availability, grilling with DDD,
  a conditional `release-it` read, the prohibited pairs, and code-review with
  neither book installed.
- **The ten-change A/B was a task of this change.** It cannot be: the producer's
  lens is unconditional by requirement, so there is nothing to toggle, and ten
  future changes cannot gate completion. Moved to tracked follow-up, with the
  pre-lens reviews as baseline.

One observation the reviewer did not make, worth recording: codex did not cite
the rule set in its reply, and neither gemini nor opencode ran. The lens
therefore has **no live evidence** of changing a review yet — the conformance
rows prove only that it reaches the prompt.

## Plan-review round 2 (codex REQUEST-CHANGES; gemini, opencode exit 1)

All five accepted:

- **The contract claimed reviewers *read* the lens.** Nothing here can make a
  third-party CLI obey. The requirement now says the producer **requests** it
  and asks each reviewer to state whether it read it; the prompt asks for that
  line back. What is verifiable is what is required.
- **"Apply SHALL read none" was unenforceable** — these skills carry broad
  triggers and the operator may invoke one deliberately. Narrowed to what the
  workflow itself loads.
- **The mapping was duplicated in four places with nothing comparing them.** A
  conformance row now parses the plan-review row out of the skill's Rule sets
  table and asserts the prompt names exactly those books. Proven to have teeth:
  adding `refactoring` to the table turns the row red. Scoped to the Rule sets
  section, because the gates table carries its own `plan-review` row and an
  unscoped parse read that one first.
- **Integration and data were one ambiguous row.** Split into two, each with its
  own scenario, and both marked as pointers to uninstalled books.
- **The interface scenario fired on any `design.md`** and pulled in behaviour
  this change does not establish. Narrowed to placing a seam or specifying an
  interface; the `codebase-design` clause is gone.

## Plan-review round 3 (codex REQUEST-CHANGES; gemini, opencode exit 1)

**The lens worked.** Codex opened with "Read `the-pragmatic-programmer` mini
rule set: yes." That is the first live evidence that the request reaches a
reviewer and is acted on; rounds 1 and 2 had only the conformance rows.

Five findings, all accepted, two of them holes in this change's own tests:

- **The `refactoring` prohibition covered the whole prompt,** while artifacts
  below the marker may legitimately use the word — this change's proposal does.
  Both the requirement and the row are now scoped to the instruction block, and
  the fixture deliberately plants the word in the artifacts.
- **The mapping cross-check tested a hard-coded vocabulary.** A book added to
  the table but absent from that list would have passed silently. The row now
  derives the prompt's set from the instruction block and compares sets; proven
  by adding `release-it` to the table, which turns it red.
- **"Reported" conflicted with third-party reviewers,** who may ignore the
  status request. Reporting is now scoped to the step that reads a rule set on
  this machine; for reviewers the producer requests and counts either way.
- **`MAY` defined no owner** for the conditional books. Now `SHOULD`, decided by
  the author at propose and stated in `design.md`, with the second prohibited
  pair given its own scenario.
- **Lens provenance is unrecorded.** Accepted explicitly as a limitation, with a
  requirement that says so and says why: binding a third-party skill's bytes
  would stale every open review on any upstream edit, and the digest binds the
  artifacts reviewed, which is what staleness would actually misdescribe.
