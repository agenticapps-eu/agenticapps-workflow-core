## MODIFIED Requirements

### Requirement: Reviews are reported, never enforced

The gate SHALL NOT block a code edit on the state of `REVIEWS.md`. It SHALL
report that state — absent, short of the preferred count, unverifiable, stale,
or carrying REQUEST-CHANGES — on every invocation where it applies.

The gate SHALL block an edit on exactly one condition: `openspec validate --all`
is not green (or the `openspec` CLI is unavailable, so the question cannot be
answered). A commit is blocked on that condition and on one more: the two
instruction files differ (see *The gate fails a commit whose two instruction
files differ*). Neither condition is a review. The reviewer count remains defined, computed and reported, because a
report that miscounts is as wrong as a block that miscounts. What is removed is
the consequence, not the arithmetic.

**Why the enforcement was withdrawn.** The distinction that matters is between
an ERROR and an ABSENCE. A malformed spec delta is wrong on its own terms —
local, instant, deterministic, and knowable without asking anyone. A missing
review is a missing OPINION: the change is not more broken for the absence of
it, and the person best placed to judge whether that matters is the one being
interrupted.

Measured on this repository, blocking cost three rollbacks, a six-repository
outage on 2026-07-30, and a migration whose stated precondition was announcing
that outage in advance. What it prevented is not identifiable. Because the
reviewers are third-party CLIs that are variously slow, rate-limited, and prone
to returning nothing, the floor went unmet routinely for reasons bearing no
relationship to the quality of the change under review — so the block landed
almost exclusively on the wrong cases.

A plan review is worth running, and the gate says so every time it notices one
is missing. Saying so is the whole of the mechanism.

#### Scenario: An active change carries no review

- **WHEN** validation is green and `REVIEWS.md` carries no counted reviewer
- **THEN** the gate ALLOWS the edit and reports that no plan review has been run

#### Scenario: An active change carries a stale review

- **WHEN** the reviewed artifacts have changed since `REVIEWS.md` was written
- **THEN** the gate allows the edit and reports that the review no longer
  describes the current text — distinguishably from having no review at all

#### Scenario: Validation is not green

- **WHEN** `openspec validate --all` fails, whatever the review state
- **THEN** the gate blocks the edit

#### Scenario: Validation is green and the instruction files differ

- **WHEN** validation is green and a commit stages `AGENTS.md` and `CLAUDE.md`
  that are not byte-identical
- **THEN** an edit is allowed, and the commit is blocked

#### Scenario: The spec is read for the reviewer count

- **WHEN** a reader or host implementer looks up the reviewer count
- **THEN** every statement of it in the spec agrees, and every one describes a
  reported threshold rather than an enforced one

