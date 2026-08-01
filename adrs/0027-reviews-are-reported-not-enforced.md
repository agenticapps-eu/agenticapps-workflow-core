# ADR-0027: Reviews are reported, not enforced

**Status**: Accepted  **Date**: 2026-08-01  **Spec**: 1.5.0 (§18, §17)
**Supersedes**: the enforcement half of ADR-0018's independence property, as
carried into §18 by ADR-0021. The counting half stands unchanged.

## Context

From ADR-0018 onward, a code edit under an active change was blocked until the
change carried independent multi-AI review. §18 made that normative for the
OpenSpec era: `validate` green **and** `REVIEWS.md` ≥ 1 counted reviewer, and
"either alone is a block."

The reviewers are third-party CLIs. They are slow, rate-limited, and return
nothing often enough that the floor went unmet routinely for reasons bearing no
relationship to the quality of the change under review. Measured on this
repository, blocking cost:

- three rollbacks;
- a six-repository outage on 2026-07-30, when gate 1.5.0 reached the fleet and
  every open change in every project was blocked at once;
- a migration whose stated precondition was **announcing that outage in
  advance** — machinery built solely to manage the blast radius of the block;
- three planning tasks that dissolved rather than completed when the block was
  withdrawn (clear the fleet, announce the block, publish behind the
  announcement), none of which had ever improved a review.

What it prevented is not identifiable. No blocked edit is on record as having
been a defect the block caught.

Gate 2.0.0 withdrew the enforcement on 2026-07-31. **The spec was not swept**,
so §18 and §17 continued to mandate the block for another release: the
reference implementation the whole fleet pins was non-conformant with core's
own spec, and so was every host pinning it. The divergence surfaced when pi
declined to pin `hooks/openspec-gate.ci.yml` — pinning it would have imported
prose describing a reviewer floor the gate beside it does not enforce.

## Decision

**The gate blocks on validation and reports on review.**

`openspec validate --all` failing — including the `openspec` CLI being
unavailable, so the question cannot be answered — is the only condition that
blocks a code edit. Review state in every form (absent, below the floor, below
the preference, untrailered, malformed, stale, or carrying an unresolved
REQUEST-CHANGES) is reported on every invocation and blocks nothing.

**The consequence is withdrawn; the arithmetic is not.** Every counting rule —
verdict *and* body, the closed `APPROVE | REQUEST-CHANGES` vocabulary, section
bounds, digest binding, implementing-host exclusion — is retained verbatim as a
reporting obligation. A gate that reports must count as accurately as one that
blocked: "0 reviewers" printed over two real reviews is just as wrong when it is
advisory, and the report is now the entire mechanism.

**A stricter posture is a declared extension.** A host MAY block on review
state, and MUST document it where its other gate behaviour is documented. This
is what makes spec 1.5.0 a minor rather than a major: a host that still blocks
becomes a declaring host, not a non-conformant one.

## Rationale

The distinction is between an **error** and an **absence**.

A malformed spec delta is wrong on its own terms. It is answerable locally,
instantly and deterministically, with no network and no third-party CLI in the
path. Refusing an edit on it costs the author seconds and is never wrong.

A missing review is a missing **opinion**. The change is not more broken for the
absence of it. The person best placed to judge whether the absence matters is
the one being interrupted — and the interruption arrives at the moment they are
least able to resolve it, because resolving it means waiting on a vendor CLI
that may be down.

Blocking treated the two as one fact. It bought the appearance of a guarantee at
the cost of a real, recurring, measurable outage, and the failures it produced
were concentrated almost entirely on the wrong cases.

## Consequences

- Reviews will sometimes not happen. That is the accepted cost, and it is
  bounded by the report rather than by refusal: the gate names what is missing
  on **every** invocation, so proceeding without a review is a repeated act
  rather than a silent one.
- An unresolved REQUEST-CHANGES no longer stops anything. The gate names each
  objecting reviewer for as long as the objection stands. This is a nag, not an
  audit trail — the report goes to stderr, has no durable sink, records no
  operator identity, and requires no acknowledgement. It is described that way
  in §18 rather than overclaimed.
- A stale review is reported distinguishably from no review. Under the old
  behaviour both produced a block, so the distinction was invisible; it is
  load-bearing now, because it is the whole output.
- Callers depending on exit `2` for an unreviewed change no longer get it. This
  is why the *gate* went to 2.0.0 while the *spec* moves by a minor — the gate's
  contract broke, the spec's did not, because of the declared-extension clause.
- `GSD_SKIP_REVIEWS` is vestigial. It suppresses the review reports and is kept
  so existing exports do not error; it has never bypassed `validate` and must
  not be documented as though it does.

## Alternatives considered

**Keep blocking, fix the reviewers.** The reviewer CLIs are third-party and
their availability is not ours to fix. Two years of retries, timeouts and
fallbacks would still leave the floor unmet whenever a vendor is down, and the
cost falls on the author of an unrelated change.

**Block only when reviewers are reachable.** Makes enforcement depend on
network conditions, so the same change is permitted or refused depending on when
it is attempted. A gate whose verdict is not reproducible is worse than one that
does not gate.

**Raise the floor to two and keep blocking, per ADR-0018's evidence.** The
evidence that two reviewers beat one is real and is retained as the SHOULD — in
the 2026-07-28 fleet migration the decisive finding was unique to one vendor
every time. But it argues two is better than one, not that one is better than
none, and a hard floor of two blocked all work whenever the second vendor was
slow. It was tried, and the six-repository outage is what it produced.

**Major version instead of minor.** Rejected together with the declared-
extension clause: with a MAY for the stricter posture, no existing host
implementation becomes non-conformant, which is the test for a major. A host
that blocks declares; a host that reports is the default.
