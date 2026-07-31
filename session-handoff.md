# Session Handoff — 2026-07-31

## The one thing to know

**The change's own thesis was false in its own code, and the harness was
structurally unable to see it.** `track` claims the producer and the gate apply
one predicate. They did not. Two ordinary vendor outputs — a `## Summary`
heading above the verdict, and a truncated code fence — made the producer report
success on evidence the gate counted as **zero reviewers**.

It shipped green at 55/55 because the producer harness advertised a
`G. Cross-check — producer and gate agree on the same file` group **that did not
exist in the file**. Nothing in the tree ever fed producer output to the
verifier. Group H now does.

Found by the Stage-2 independent code review (task 10.5), not by six rounds of
Stage-1 vendor review across three vendors. Stage 1 reads artifacts, and the
artifacts described the invariant correctly.

## Accomplished

| Artifact | Was | Now | Harness |
|---|---|---|---|
| `openspec-change-gate.sh` | 1.5.0 | **1.6.0** tracked, **NOT published** | 69/69 |
| `run-plan-review.sh` | 1.1.0 | **1.2.0** tracked, **NOT published** | 60/60 |
| `install-shared-artifact.sh` | 1.0.0 | **1.0.1** | 20/20 |
| `reviewer-cli.sh` | 1.2.0 | unchanged | 19/19 |

Six commits on `feat/step3-hook-shims-and-dead-gate-removal`. Nothing was
published to `~/.agenticapps/bin/`; the fleet is untouched and the shared gate
is still 1.4.0. The final re-review was run with the **tracked** 1.2.0 producer
precisely to avoid publishing.

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

- **8b.4 discharged by acceptance, not by clearing the fleet** (operator's
  call). 37 changes across six repos are recorded as accepted-blocked. Three of
  the six repos are factiv-family, so a "re-review the fleet" task written here
  was unsatisfiable by construction — the same defect class as the round-6 `pi`
  lockout.
- **That moves the precondition, it does not remove it.** New **task 8b.7**:
  announce the block before publishing. Six repos will hit a hard `PreToolUse`
  block with no warning; publishing without notice reschedules the 2026-07-30
  outage rather than avoiding it. 8b.6 now depends on 8b.7.
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

1. **Read the round-12 verdicts in `REVIEWS.md`** — run at the end of the
   session so the branch is left GREEN rather than blocked, and **deliberately
   not acted on**. Any findings there are yours to triage. Triage the way this
   session did: verify against running code first. Three claims this session
   were refuted by a two-minute test (`fenced ## Reviewer:` hijack, fenced second
   trailer, and — with the caveat that the spec gap was real — fence
   portability), and one that was false in round 8 was true in round 9.
2. **The loop is at diminishing returns, and stopping is a decision.** Round 9
   found six defects, round 10 found two (both mine), round 11 found one real
   drift plus text corrections. Every round of fixes stales the evidence and
   buys another round; the fixes have been shrinking and turning textual, which
   is what convergence looks like. **Quorum already opens the gate** — an
   outstanding REQUEST-CHANGES is reported, not blocking, by design. So a green
   branch carrying noted objections is a legitimate resting state, and a stale
   one is not. The next required act is **8b.7**, which is communication, not
   code. Do not start round 13 unless a finding is a real defect.
3. **8b.7 gates everything downstream.** Write the notice, then 8b.6 (publish
   gate 1.6.0), then 8.4, then archive. Publishing before 8b.7 is the one move
   this branch has already been burned by, and 8b.4's acceptance *moved* that
   precondition rather than removing it.
4. **Task 10.2** (`--ci` green) is satisfiable once round 11 lands. Expect the
   advisory tasks-drift NOTE to fire, since `tasks.md` is edited after every
   review — that is the feature working, not a fault.
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
