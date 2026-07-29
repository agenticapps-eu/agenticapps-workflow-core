## Context

Two copies of the plan-review producer exist, and neither is a tracked source:

| Location | Lines | Version marker | Behaviour below floor | Tracked |
|---|---|---|---|---|
| `~/.agenticapps/bin/run-plan-review.sh` | 227 | `1.0.0` | refuses to write `REVIEWS.md` | no |
| `gate/run-plan-review.sh` (core) | 66 | none → `0.0.0` | warns, continues | no (`gate/` untracked) |

The installed copy is the real implementation: it carries the stdout sanitiser
(vendor banners and session-hook logs were landing in `REVIEWS.md` as review
prose), the `## Reviewer:` forge guard, and per-code reporting of reviewer-cli
1.1.0's 3/4/5 exit codes. The `gate/` copy predates all of that.

The producer's own header warns about exactly the situation it is now in:

> The producer sat in the same shared directory, installed by the same script,
> three lines below the gate's arbitration block — and was left blind. Nothing
> has broken yet only because no sibling host ships a producer to overwrite it
> with; that is luck, not design.

Something has now broken, in a different way: the floor drifted from the spec.

## Goals / Non-Goals

**Goals**

- Give the producer a tracked home so it can be reviewed, diffed and recovered.
- Make its default floor match §18.
- Stop discarding completed reviews.

**Non-Goals**

- **Re-litigating the floor.** §18 lines 88–102 decided one reviewer, with
  reasoning. This change implements that decision.
- **Changing the sanitiser, forge guard, or exit-code reporting.** Carried
  across byte-for-byte; they are why 1.0.0 is the real implementation.
- **Classifying the rest of `gate/`.** Only `run-plan-review.sh` is resolved
  here. `gate/`'s other contents (`openspec-change-gate.sh`, `pre-commit`,
  `hooks/`, `README.md`) duplicate tracked reference-implementations and need
  their own keep/track/delete call.
- **Touching the four hosts.** Per plan step 2, publish rather than re-vendor.

## Decisions

### Decision 1: Promote the installed 1.0.0, not core's `gate/` copy

**Chosen:** `reference-implementations/run-plan-review/run-plan-review.sh` is
seeded from the 227-line installed copy.

*Alternative — seed from `gate/run-plan-review.sh`, the in-repo copy.*
Superficially the tidier story: the repo copy becomes canonical. Rejected on
inspection — it is a 66-line ancestor missing every fix made since. Choosing it
would silently revert the sanitiser and the forge guard, reintroducing the bug
where vendor banners were recorded as review prose.

The lesson generalises: "the copy in the repo" and "the current implementation"
were not the same file, and only reading both revealed which was which.

### Decision 0: Fix §18 rather than conform to it

§18 currently mandates two different floors. Line 73's truth table and line 80
say one reviewer; lines 146 and 174 say two. Spec 1.1.0 changed the truth table
and wrote the rationale, and left the two prose clauses behind.

**Chosen:** correct lines 146 and 174 to one, matching the truth table.

*Alternative — conform the producer to the ≥2 clauses.* Rejected: it
contradicts the truth table the gate implements, and reverses a decision §18
argues for at length over fifteen lines.

*Alternative — treat this as out of scope and file it separately.* Rejected as
the more dangerous kind of tidiness. This change's entire premise is "the
producer disagrees with the spec"; leaving the spec self-contradictory means
the next reader cannot tell which half the producer was made to match. The
reviewer that caught it was right that the change must own the spec edit.

The gate binary already enforces ≥1, so no running enforcement changes. This
aligns the text with behaviour that has been live since 1.1.0.

### Decision 2: Default the floor to 1, keep the override, reject below 1

**Chosen:** `MIN_REVIEWERS` defaults to 1; an explicit value of 1 or more wins;
0, negatives and non-integers are usage errors.

The existing guard rejects only empty and non-digit values, so `0` passes,
`[ 0 -lt 0 ]` is false, and the producer publishes and exits 0 — announcing a
floor it never evaluated. That is the same failure the comment directly above
that guard was written to prevent, reintroduced one value to the left.

*Alternative — default to 1 with no override.* Simpler surface. Rejected
because §18 distinguishes a floor from a preference: the floor is one, but a
caller may legitimately want more for a risky change. Removing the override
would make the stricter posture unreachable.

*Alternative — leave the default at 2 and document the override.* This is the
status quo, and it failed in practice on 2026-07-29: the operator did not know
the override was needed until a review was already lost. A default that
contradicts the spec is a trap, not a configuration.

### Decision 3: Report failures into the artifact, not just stderr

A run that met the floor SHALL succeed, and `REVIEWS.md` itself SHALL record
which vendors were requested, counted, excluded and failed. Previously a
shortfall against the *requested* count produced no artifact at all, which is
what discarded gemini's completed review.

*Alternative — report failures on stderr only,* as first proposed. Rejected on
review: the terminal is gone by the time anyone reads an archived `REVIEWS.md`,
so "two reviewers" cannot be distinguished from "two of five, three failed".
The artifact would systematically overstate the scrutiny a change received.

### Decision 4: A section counts only if it carries a verdict

Counting any non-empty, exit-zero output as a review is what let opencode's
"I'll fact-check this change before issuing a verdict" preamble count as one of
three reviewers on this very change. At a floor of one, such a section alone
would open the gate for a change nobody reviewed.

**Chosen:** a section counts only with a parseable verdict; output without one
is a failure with that reason. REQUEST-CHANGES counts — an objection is a
review, and the gate reports objections separately.

### Decision 5: Independence is structural, not environmental

Self-exclusion currently rests on `OPENSPEC_GATE_SELF` defaulting to `claude`,
which is wrong on every host except one. At a floor of two this was survivable;
at a floor of one, a single self-review satisfies the gate entirely.

**Chosen:** determine the running host and exclude it by rule; de-duplicate
repeated vendors. The floor's whole claim is "at least one *independent*
opinion" — without this, the word independent is unenforced.

### Decision 6: Declare the egress boundary; defer screening

The producer sends proposal, design and spec deltas to external vendor CLIs,
which forward them off this machine, with no manifest and no screening. It also
passes the prompt as a process argument, readable from the process table.

**Chosen:** declare what is sent and to whom, treat invocation as consent, and
pass the prompt by file. Secret/PII screening is deferred to its own change.

*Alternative — full screening now.* Rejected on scope: it turns a conformance
fix into a security feature and delays a floor repair that is losing reviews
today. Declaring the boundary is what makes the deferral auditable instead of
silent — the gap is now written down.

## Risks / Trade-offs

- **A lower default floor is a weaker signal.** One reviewer catches less than
  three. §18 accepts this explicitly and argues the alternative — zero
  reviewers whenever a vendor is slow — is worse. This change does not add
  risk; it stops the producer enforcing a stricter rule than the spec while
  reporting itself as conformant.
- **Promoting the installed copy imports whatever is in it**, including any
  undiscovered defect, into the tracked source. Mitigated by the fact that it
  is already the code every review on this machine has run through; tracking it
  makes those defects reviewable rather than invisible.
- **`gate/` remains partly unclassified** after this change, so core still
  carries untracked material that looks authoritative. Narrowing the scope here
  is deliberate — classifying the rest requires per-file judgement that would
  swamp a conformance fix.

## Migration Plan

1. Add `reference-implementations/run-plan-review/` seeded from the installed
   1.0.0, byte-identical, with README and install contract.
2. Apply the floor and reporting changes; bump the marker to 1.1.0.
3. Verify against the recorded failure: one vendor returning and two timing out
   must now produce a written `REVIEWS.md`.
4. Publish to `~/.agenticapps/bin/` through the existing install path.
5. Delete `gate/run-plan-review.sh`.

Rollback: restore the 1.0.0 file from the reference implementation's history
and republish. No project depends on the producer's internals — callers pass a
slug and read `REVIEWS.md`.

## Open Questions

- Should the producer refuse to run when *every* requested vendor is the host's
  own (`OPENSPEC_GATE_SELF`)? Out of scope here; reviewer-cli already ships all
  vendor arms deliberately, and exclusion is documented as the producer's job.
