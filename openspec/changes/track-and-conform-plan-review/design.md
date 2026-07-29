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

### Decision 2: Default the floor to 1, keep the override

**Chosen:** `MIN_REVIEWERS` defaults to 1; an explicit value wins.

*Alternative — default to 1 with no override.* Simpler surface. Rejected
because §18 distinguishes a floor from a preference: the floor is one, but a
caller may legitimately want more for a risky change. Removing the override
would make the stricter posture unreachable.

*Alternative — leave the default at 2 and document the override.* This is the
status quo, and it failed in practice on 2026-07-29: the operator did not know
the override was needed until a review was already lost. A default that
contradicts the spec is a trap, not a configuration.

### Decision 3: Report failures rather than failing the run

A run that met the floor SHALL succeed and name the vendors that did not
return. Previously a shortfall against the *requested* count produced no
artifact at all, which is what discarded gemini's completed review.

This keeps the missing opinions visible — `REVIEWS.md` says who reviewed, and
the run output says who could not — without letting one slow vendor veto the
whole result.

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
