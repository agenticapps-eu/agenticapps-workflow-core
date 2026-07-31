# Session Handoff — 2026-07-31

## The one thing to know

**The gate no longer blocks on reviews, and it is published.** Gate **2.0.0**
and producer **1.2.0** are live in `~/.agenticapps/bin/`. A plan review is
worth running; refusing to let anyone write code until one exists is a
different claim, and it was the one that kept failing.

Blocking now happens on exactly one condition: `openspec validate --all` not
green. Missing, stale, unverifiable and objecting review evidence are all
reported, never enforced. Error vs absence — a malformed spec delta is wrong on
its own terms; a missing review is a missing opinion.

Verified against the condition that caused the 2026-07-30 rollback: an active
change with a pre-trailer `REVIEWS.md`, hook mode, code payload. Gate 1.4.0 →
exit 2 BLOCKED. Gate 2.0.0 → exit 0 with a NOTE. **Publishing was not a fleet
event**, which is what dissolved tasks 8b.4, 8b.6 and 8b.7 — three tasks, a
rollback and a rolled-back publication that all existed to manage the blast
radius of a block, none of which improved a single review.

**The re-review treadmill is gone.** Editing an artifact still stales the
evidence; it no longer stops anyone. That loop consumed most of this session.

## Accomplished

| Artifact | Was | Now | Harness |
|---|---|---|---|
| `openspec-change-gate.sh` | 1.4.0 published | **2.0.0 PUBLISHED** | 71/71 |
| `run-plan-review.sh` | 1.1.0 published | **1.2.0 PUBLISHED** | 60/60 |
| `install-shared-artifact.sh` | 1.0.0 | **1.0.1** (tracked only) | 20/20 |
| `reviewer-cli.sh` | 1.2.0 | unchanged | 19/19 |

Ten commits on `feat/step3-hook-shims-and-dead-gate-removal`. Gate and producer
are live and byte-identical to the tracked sources; the published gate scores
71/71 on its own harness. 1.5.0 and 1.6.0 were never published — 1.5.0 was, on
2026-07-30, and rolled back the same day; 2.0.0 supersedes both.

## Six defects, each confirmed by execution before it was touched

1. **Section bounding discarded verdicts.** Gate closed a reviewer section at
   any level-1/2 heading, so `## Summary` above a verdict lost it. 1.6.0 closes
   only at the next `## Reviewer:`.
2. **An unclosed fence swallowed the next reviewer and the trailer.** Fixed in
   the *producer* (refuse `unbalanced-fence`), not the gate — resetting fence
   state per section would reopen the fence-forging hole the gate closes. The
   body is dropped, never repaired; the record promises verbatim vendor text.
3. **A normative `SHALL` with no implementation.** The spec has required a
   tasks-drift report since 1.3.0. The producer wrote `tasks-digest`; the gate
   contained **no reference to it at all**. Write-only evidence is worse than
   none — it reads as a control that exists.
4. **Substance had no grammar.** `---` and a bare `>` counted as a body, so
   `VERDICT: APPROVE` plus `---` passed. Now: one alphanumeric character.
5. **`--implementing-host claude,` passed the producer, failed the gate.** Word
   splitting drops a trailing empty field. `,claude` *was* caught, so the bug
   was asymmetric as well as silent.
6. **A symlinked `REVIEWS.md` was followed.** A successful review could truncate
   an arbitrary file and report success — and it is the one write the gate
   always exempts, so nothing downstream would have caught it.

## Decisions

- **Reviews became advisory (operator's call, late in the session), and that
  superseded the three tasks below it.** 8b.4 had been discharged by *accepting*
  ~35 changes across six repos as blocked; 8b.7 was then added to announce that
  block before publishing, and 8b.6 made publication depend on it. Gate 2.0.0
  dissolved all three at once — there is no block to clear, announce, or
  sequence behind. They are recorded as dissolved rather than deleted, because
  the shape is the lesson: when a precondition needs its own precondition,
  question the mechanism rather than the ordering.
- **The inventory total was wrong and is not trusted.** Recorded as 37; its own
  per-repo breakdown sums to 35. It survived three review rounds and was
  restated in two documents and two handoffs by an author who never added it up.
  Neither figure is asserted — retake the inventory if any count matters. It no
  longer gates anything.
- **Bumped rather than amended 1.5.0 in place.** It briefly reached the fleet on
  2026-07-30, and a version that ever shipped must keep meaning one thing.
- **Every new harness row was mutation-tested** — disabling the fix must fail
  the row. Adding unverified rows to fix a vacuous-harness problem would have
  been the same mistake again. One first-cut row *was* vacuous (it hashed a
  `tasks.md` the gate fixture did not have) and was caught this way.

## Round 11 — gemini APPROVE ("no concrete issues"), codex REQUEST-CHANGES

codex's first finding was **my own residual drift**: round 10 changed the
section boundary in the normative delta and one scenario, and left the old rule
stated in `design.md`, `proposal.md`, task 7b.9, and the spec's own placement
paragraph. Four sites corrected.

Also fixed: **fence balance is now defined** (an even count of fence-toggling
lines — requiring the producer to reject "unbalanced" while leaving balance
undefined was a real contradiction); **identity precedence specified** (flag
beats `AGENT_SELF`, verified by execution both ways); **the migration no longer
requires and forbids the same thing** (step 6 said "re-review each" while 8b.4
accepts 37 as blocked — split into resolve-or-accept plus step 6b, announce);
**rollback table** carries shipped versions and gains the shared-install row,
which must roll back *last* because every other row is executed by it.

**The audit-trail claim is withdrawn.** The REQUEST-CHANGES report goes to
stderr with no durable sink, no operator identity, no timestamp. It is a nag —
the objection reappears every invocation until the change is amended — and that
is worth having under its own name. Two reviewers called it overstated.

## Round 10 — gemini APPROVE, codex REQUEST-CHANGES (quorum; gate opens)

**Two of codex's findings were drift I introduced**, by changing code without
changing the prose. Both confirmed and fixed:

- The section-boundary rule still said "level 1 or 2" while gate 1.6.0 closes
  only at `## Reviewer:`, and the "later non-reviewer heading" scenario
  asserted the opposite of what the gate now does.
- `proposal.md` and `design.md` still specified producer 1.1.0 / gate 1.5.0.

**Fence behaviour is now normative** rather than deferred — the objection that
deferring it left four dependent rules non-portable was correct.

**Refuted by test:** a fenced trailer quotation alongside a real trailer yields
`TRAILERS 1`, reading the real fields. Trailer recognition is already
fence-aware, which is the condition that claim was contingent on.

**Accepted with the cost named, not fixed:** `implementing-host` accepts
`gemini` (union vocabulary — it can only discard a reviewer, never manufacture
one), and a raised `MIN_REVIEWERS` is not persisted (the honest fix records the
requested floor in the trailer, which is a §18 change).

## Reviewer accuracy this round — better than the standing one-in-four

Of ten Stage-1 claims, seven confirmed, one refuted by test (codex's claim that
a fenced `## Reviewer:` can hijack a section — the gate *is* fence-aware; only
the spec-portability half stands), two accepted as inherent. codex's "four known
vendors" claim, **false in round 8**, was **true in round 9** — the round-9
corrections had reintroduced it in prose.

## Files modified

- `reference-implementations/{openspec-change-gate,run-plan-review,shared-install}/`
- `tools/{run-plan-review,change-gate}-conformance.sh` — group H, tasks-drift
  rows, rewritten section E, env sanitising
- `openspec/changes/track-and-conform-plan-review/` — `tasks.md`, `proposal.md`,
  `design.md`, both spec deltas, `CALLER-INVENTORY.md`
- `adrs/0025-…md`, `CHANGELOG.md`

## Next session: start here

1. **Nothing is blocked and nothing is urgent.** The gate is published and
   permissive; both open changes validate. `track-and-conform-plan-review`
   carries a round-12 review whose findings were deliberately not acted on —
   read them, and treat them as optional now that no gate depends on them.
2. **Archive `track-and-conform-plan-review` when you want to.** Its remaining
   open items are declared limits (§14 non-conformance, `MIN_REVIEWERS` not
   persisted, union host vocabulary) and out-of-repo sites, not defects.
3. **Task 8.4 is the one real leftover** — the Claude installer still points at
   its own vendored producer copy rather than core, so this publication was done
   by hand with `install-shared-artifact.sh`.
4. **Retake the fleet inventory if any count matters.** The recorded total (37)
   contradicted its own breakdown (35) and neither figure is trusted. It no
   longer gates anything, so this is bookkeeping.
5. `shim-project-hooks` remains planned, not implemented.

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered; codex has raised it as a §16 conflict three times now.
- **The host/vendor vocabulary is restated in at least four places** — spec,
  producer, gate, and `~/.codex/skills/codex-openspec-change-review`. Both
  reviewers asked for a single machine-readable source, and this round's `pi`
  defect *is* that divergence materialising. Deferred, not declined.
- **`~/.codex/skills/codex-openspec-change-review` is a second producer** whose
  every `REVIEWS.md` gate 1.5.0+ counts as zero. Recorded in CALLER-INVENTORY,
  out of scope to fix here, belongs to the `codex-workflow` re-vendor.
- **`screen-review-egress`** — still a declared §14 non-conformance, not a
  closed one.
- **`gate/` remains unclassified** apart from the deleted producer, as do the
  untracked root items.
