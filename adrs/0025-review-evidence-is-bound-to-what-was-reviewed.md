# ADR-0025: Review evidence is bound to what was reviewed

**Status**: Accepted  **Date**: 2026-07-30  **Change**: `track-and-conform-plan-review`

## Context

§18's review requirement rests on an artifact — `REVIEWS.md` — produced by one
process and consumed by another. Four things were wrong with that arrangement at
once, and each was found by using it rather than by reading it.

**The producer existed in no repository.** The implementation that ran was 227
lines at `~/.agenticapps/bin/run-plan-review.sh`. Core's `gate/run-plan-review.sh`
was a 66-line ancestor, unmarked, in an untracked directory — 161 lines behind
the thing it was supposed to be. The gate, the wrapper and the installer were all
tracked under `reference-implementations/`; the producer was not. Nothing
reported the drift, because a drifted artifact reports clean.

**The producer and its verifier disagreed about the same rule.** §18 dropped the
reviewer floor to one at spec 1.1.0 and the gate followed at 1.4.0; the producer
still defaulted to two. On 2026-07-29 one vendor returned a complete review and
two timed out — the producer discarded the review and wrote nothing, enforcing
*zero* reviewers in exactly the situation the floor change existed to prevent.

**A heading counted as a review.** `reviewer_count()` counted `## Reviewer:`
headings. Two distinct failures rode on that: a verdictless preamble counted, and
on 2026-07-29T07:52:54Z a bare `VERDICT: APPROVE` with no body counted. At a
floor of one, either alone opens the gate.

**Nothing tied a review to what it reviewed.** An amended change kept its old
`REVIEWS.md` and the gate could not tell. This was not hypothetical: during the
session that wrote the requirement, both open changes were substantially revised
after review and both retained their prior evidence.

## Decision

**Track the producer in core, seeded byte-identically from the copy that runs.**
Not from the in-repo ancestor. The ancestor was what someone believed ran; the
installed copy was what ran, and a baseline that is provably the running
implementation is worth more than one that is merely in the right directory.

**One floor, stated once.** `MIN_REVIEWERS` defaults to 1 everywhere. `0` is
rejected outright — it was not a lax setting but an evidence destroyer: with
every reviewer failing, `0 -lt 0` is false, so the producer published a
zero-byte `REVIEWS.md` over existing evidence and exited 0.

**A section counts only with a verdict *and* a body**, by a predicate the
producer and the gate share byte-for-byte. A verdict alone is not a review; a
body alone is not a verdict. The two processes previously mirrored each other's
parsing by hand, under a comment warning that divergence would mean the gate
counts one set of reviewers and reports on another.

**The implementing host is declared, never defaulted, and recorded in the
artifact.** The old default was `claude` — correct on one host, wrong on three.
The gate's own default was empty, applying no exclusion at all. The identity now
lives in the artifact because the party evaluating evidence is routinely not the
party that produced it: CI and pre-commit hooks read files other hosts wrote, so
an environment-derived identity names the wrong party.

**A digest binds the review to the reviewed bytes**, covering exactly what is
transmitted — `proposal.md`, `design.md`, `specs/**/*.md`. Not `tasks.md`: it is
never sent to reviewers, and binding it would stale a review on every ticked
checkbox and deadlock the gate during implementation.

**The prompt leaves argv.** All four wrapper arms passed the full change as a
command-line argument, world-readable in the process table for as long as the
reviewer ran.

## Alternatives rejected

**Seed the tracked copy from `gate/run-plan-review.sh`.** It is the in-repo file
and the obvious choice. Rejected: it is 161 lines behind, so tracking it would
have enshrined a version that never ran and quietly reverted every fix the real
producer carried.

**Sign `REVIEWS.md`.** Considered and rejected as out of scope. The digest is
computable by anyone holding the same artifacts, so it detects drift, not
authorship. An earlier draft argued from *forgery* and shipped a mechanism that
does not answer forgery; the claim is now made in its weaker, true form.

**Bind `tasks.md` into the digest.** Rejected for deadlock. The consequence is
stated rather than hidden: a task list can change without invalidating a review,
so a post-review task ("add a debug endpoint") slips through. An earlier revision
justified the exclusion by asserting that any meaningful task change must also
alter a bound artifact; a reviewer supplied the counter-example and that
assumption was withdrawn. An optional `tasks-digest` reports the drift without
blocking.

**Block on `REQUEST-CHANGES`.** Rejected. §18's threshold is a quorum: two
rejections open the gate exactly as two approvals do. The gate names objectors on
every invocation instead.

**Prompt for confirmation before egress.** Rejected. The producer runs from CI
and hooks, where a prompt either hangs or is auto-answered — worse than none. A
notice is printed at every invocation instead.

## Consequences

**Every `REVIEWS.md` in existence became unverifiable.** All predate the trailer,
so a 1.5.0 gate counts them zero. This is a scheduled migration, not a
discovered one: publish the producer, re-review, then publish the gate. Reversing
that order blocks every change in every project at once.

**The producer's interface broke.** `--implementing-host` is required with no
default. An inventory found **no executable caller anywhere** in the fleet — every
reference is documentation — so the breakage surfaces interactively, with a usage
error naming the missing input.

**Rollback became executable.** The installer's downgrade refusal made every
rollback row in the migration plan a lie. `--allow-downgrade <artifact> --reason
<text>` is the narrow escape, with the log write gating the replacement so a
failed audit record cannot leave a silently downgraded binary.

**Three defects were found by building, not reviewing.** A zero-floor that
destroyed evidence; a line-based digest enumeration that silently dropped
newline-bearing paths (framing record boundaries is pointless if the boundary is
lost during enumeration); and a vocabulary that would have locked `pi` out of the
fleet entirely — `pi` is a host with no reviewer arm, and validating the
implementing host against the *reviewer* set made every pi-authored change
permanently unreviewable. Six review rounds across three vendors missed the last
one; the conformance harness caught it on the first run that seeded it.

**The migration order is not advice, and skipping it caused a live incident.**
On 2026-07-30 gate 1.5.0 was published after re-reviewing only *this repo's*
two changes. The fleet inventory (task 8b.1) was run afterwards and found **37
active changes across six repos, none carrying a trailer** — every one of them
blocked at `PreToolUse` the moment the shared gate landed. This is precisely the
"flag day announced by an outage" the plan's step 6 exists to prevent, and the
plan named it in advance.

The remedy was the downgrade path this same change introduced:
`--allow-downgrade openspec-change-gate.sh --reason "fleet not re-reviewed…"`,
restoring 1.4.0 byte-identically with a durable audit record. Task 10.4 had
rehearsed that path on a scratch artifact; this exercised it on the real one,
under real breakage, which is a better test than the rehearsal.

Two lessons, both cheap to state and expensive to learn:

1. **"Re-review the in-flight changes" means the fleet, not the repo you are
   working in.** A shared artifact has shared blast radius; the inventory is
   the step that makes that concrete, and it belongs *before* publication, not
   after.
2. **A rollback path is worth building before it is needed.** Had
   `--allow-downgrade` still been "a task-list aside" — which is how an earlier
   revision of this change carried it, until a reviewer objected — the only
   remedies would have been hand-editing a shared binary or re-reviewing 37
   changes under pressure.

**Stub harnesses cannot verify vendor integration.** Converting the wrapper to
stdin scored green on every stubbed arm while two were broken against the real
CLIs: `opencode`'s `--file` is an array option that swallowed the message
positional, and `gemini` refused its input because the *hint wording* told an
agentic CLI to go open something called "stdin". Each arm is now smoke-tested
against its real vendor before publication.
