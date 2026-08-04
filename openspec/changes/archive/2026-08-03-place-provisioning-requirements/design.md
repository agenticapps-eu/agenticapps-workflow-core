## Context

`project-hook-binding/spec.md` is 1604 lines across 15 requirements. One of them —
"An unresolvable shim allows, and the operator sees it", lines 605–1085 — is ~480
lines, roughly 30% of the capability, and most of it governs something the
heading does not name.

The material that does not belong there arrived in two waves. The three-axis
state model came from the change that replaced a flat four-state list after a
reviewer showed the list was not mutually exclusive. The currency axis and its
eight scenarios came from `check-implementation-currency` on 2026-08-03, which
added ~200 lines. Neither wave was wrong to add the text; both put it under the
nearest heading rather than the right one.

The requirement two headings below, "Provisioning is checked per machine, not
only per repository", is 38 lines and already reaches upward for the material,
saying the state is *"computed observationally per the state table above"*.

This is a restructuring of durable capability text. No code reads these headings
— verified across `tools/`, `reference-implementations/` and `migrations/`.

## Goals / Non-Goals

**Goals:**

- Each requirement heading names what the requirement governs.
- The provisioning state model is findable by a reader who goes looking for it.
- Zero change to normative content: no sentence added, removed, reordered within
  a block, or reworded.
- The move is *proven* content-preserving by a mechanical check, not asserted
  after a reading.

**Non-Goals:**

- **No rewriting, tightening or de-duplication of the moved prose**, however
  tempting. Editing while moving would make the mechanical check impossible and
  hide a semantic change inside a large diff.
- No change to `provisioning-check.sh`, `project-hook-conformance.sh`, any test,
  or any template.
- Not resolving the open questions the moved text records (the untested
  `cmp`-error path; `provisioning-check.sh` absent from the shared bin). They
  move with their prose, unchanged.
- No renumbering or reordering of the capability's other 13 requirements.

## Decisions

**Three requirements, not two.** The alternative — folding everything into
"Provisioning is checked per machine" — was considered and rejected. That
heading is about *where* the check applies; the state model is about *what a
machine's state is*. Folding ~290 lines under it would fix the current mismatch
by reproducing it one size smaller, leaving the state model once again under a
heading that does not announce it.

**The axes table stays whole, in the state-model requirement.** Its Currency row
moves with the other two even though a separate requirement governs currency.
The table defines the *state space* — splitting a three-row table across two
requirements would be a worse version of the problem being fixed. The currency
requirement then elaborates only *how a machine gets a currency value*.

**There are three textual cross-references across the new boundaries, not one.**
An earlier draft of this design claimed the reference "runs one direction
(currency → table)". That was false, and a reviewer caught it. Enumerated:

| reference | lives in | points at | direction | still true after reorder? |
|---|---|---|---|---|
| *"computed observationally per the state table above"* | Provisioning is checked per machine (4) | the axes table (2) | upward | yes — 2 precedes 4 |
| *"per the `stale` invariant below"* | the `stale`/`drifted` non-merger, which moves to the triple (2) | the `stale` invariant, which moves to currency (3) | downward | yes — 3 follows 2 |
| *"contradicting the `stale` invariant above"* | The implementation version marker is compared (last requirement) | the `stale` invariant (3) | upward | yes — 3 precedes it |

All three survive the intended ordering, but none of them survives it *by
accident*: each constrains where the three requirements may go. That is the real
reason ordering is load-bearing, and each is checked as a task rather than
assumed.

This was the live objection when the three-way split was chosen: separating
currency from the state model risks putting a definition and its axis in
different requirements. Keeping the table whole is the mitigation, and it is the
reason the split is safe rather than merely tidy.

**Three tooling constraints shape the encoding. All three were established by
probing `openspec archive` and resetting, not by reading its help text.**

1. **`MODIFIED` cannot shed scenarios.** Archive aborts with *"current spec
   contains scenario(s) not present in the modified block"* — it cannot see that
   the ten scenarios landed under sibling requirements in the same delta. So no
   `MODIFIED`-based encoding can move a scenario between requirements. This is a
   sound guard (it is what stops partial-content `MODIFIED` from silently losing
   detail), and it simply does not model relocation.
2. **A requirement may not appear in both `ADDED` and `REMOVED`.** Archive
   rejects it outright. So the surviving piece of a split **cannot keep its
   name** — the rename is forced by the tool, and calling it a choice would
   misdescribe it.
3. **`ADDED` requirements are appended to the end of the spec.** The delta has no
   way to express position.

Taken together: a requirement split is expressible only as `REMOVED` + three
`ADDED`, with a forced rename and no control over placement.

**The spec is reordered by hand after the fold.** Constraint 3 is the awkward
one, because placement is the whole point of this change. Left alone, archive
puts the three new requirements at lines ~1133/1345/1433 — below "Provisioning
is checked per machine", falsifying its *"state table above"*, and moving the
shim requirement from position 5 to 15, 900 lines from "A project binds a hook
through a shim". That is a worse document than the one being fixed.

The alternative considered was to accept the tool's ordering and replace the
positional reference with a named one (*"the state table in <requirement>"*),
which is arguably better engineering because named references survive any
reordering. Rejected because it fixes the reference and leaves the readability
regression: the change would then make the spec harder to read while claiming to
make it easier.

So: archive folds, then the three blocks are moved into positions 5–7 as a
disclosed step, and the **same line-level multiset diff is re-run against the
reordered file** — a reorder that loses a line is exactly as bad as a move that
loses one, and is checked the same way.

**Ordering is load-bearing, not cosmetic.** The intended final order is:

1. A shim that resolves no implementation allows the call and reports it
   *(renamed, reduced)*
2. A machine's provisioning is a triple, not a state name *(new)*
3. Currency is judged against an authority checkout *(new)*
4. Provisioning is checked per machine, not only per repository

This keeps "per the state table above" literally true — the table is in
requirement 2, still above requirement 4. Any other ordering silently falsifies
a positional reference. Checked explicitly as a task, against the **applied**
spec rather than the delta, because the delta cannot express order at all.

**The delta was produced by slicing the source, not retyping it.** Each block is
an exact line range from the current spec, concatenated in the new order. This is
what makes byte-preservation checkable rather than a claim about care taken.

**Exactly one line of new prose**, non-normative: `Invariants on the currency
axis:` — the lead-in for the `current`/`stale`/`unknown` bullets, mirroring the
existing `Invariants attach to a value on one axis, never to a state name:` that
stays with the completeness/integrity bullets. It contains no SHALL/MUST/MAY, so
it cannot alter the normative set.

## Risks / Trade-offs

**A normative sentence is silently dropped or reweighted during the ~250-line
move.** → This is the entire risk of the change, and it is the exact failure
shape this repo has hit three sessions running: an error rendered as a passing
observation.

**The compared region is lines 605–1124, and that boundary is deliberate.** The
removed requirement is 605–1085; the region extends to 1124 because
*"Provisioning is checked per machine"* (1086–1124) is also modified by this
change and gains two paragraphs from upstream. Comparing only 605–1085 would
leave the MODIFIED requirement's text unchecked. An earlier draft stated the
boundary two different ways, which a reviewer correctly flagged as making the
check's provenance unverifiable.

**The expected result, stated exactly so a reviewer can re-derive it.** Lines
lost MUST be **zero**. Lines gained MUST be **26**, and only these:

| count | what |
|---|---|
| 3 | delta section headers — `## ADDED` / `## MODIFIED` / `## REMOVED Requirements` |
| 3 | the new `### Requirement:` headings |
| 1 | the non-normative lead-in `Invariants on the currency axis:` |
| 19 | the `**Reason**` / `**Migration**` metadata on the REMOVED block, which is change metadata and never enters the spec |

A sentence-level check was tried first and rejected — it produced false
lost/gained pairs, because reordering blocks changes which neighbour a wrapped
sentence joins to. Sorting whole lines is immune to that.

This already caught one real defect: the first build sliced the final currency
scenario to line 1084 instead of 1085, dropping *"the same reason a shim marker
ahead of the template is `unrecognised`"*. A reading would very plausibly have
missed one dropped line in the 568-line delta.

**A sorted line-multiset cannot detect content attached to the WRONG
requirement.** → Raised by a reviewer and correct: a mis-cut block preserves
every line and every global count while filing the currency invariants under the
state model. Totals are therefore not sufficient. Mitigation is a
**per-requirement** check after applying — scenario inventory *per requirement*
(expected 6 / 2 / 8 / 2) and a spot-check that each requirement's body contains
its defining marker (the axes table only under the triple; the licence sentence
only under currency; the exit-code rule only under the shim requirement).

**The reorder is a hand-edit of durable truth, done after the fold, and so sits
outside the reviewed delta.** → Raised by a reviewer. Mitigation: the reorder is
performed by a **committed script** that moves whole `### Requirement:` blocks by
heading name, not by hand-dragging lines, so it is deterministic and re-runnable;
and the same multiset diff is re-run against its output. The delta genuinely
cannot express order — that is a property of the tool, not a shortcut taken here.

**Three new requirements make the capability 17 requirements long.** → Accepted.
Requirement count is not the thing being optimised; a reader's ability to find a
governing rule is.

## Migration Plan

No consumer migration required: nothing executable reads a requirement heading.

Rollback is `git revert` of the commits on this branch. Note it is **not** a
single-file revert, as an earlier draft claimed: archiving moves the whole change
directory into `openspec/changes/archive/`, so the revert spans the spec file,
the change directory's old path and its new one.

Two historical documents cite the removed heading by its old name —
`session-handoff.md` and the archived `check-implementation-currency` change.
Those are **records of what was true when written** and are deliberately left
alone; correcting them would falsify a dated account. This is why the
"no consumer reads headings" check is scoped to executable consumers.

## Open Questions

None blocking. The open questions carried *inside* the moved prose (the untested
`cmp`-error path, `provisioning-check.sh` not published to the shared bin) are
unchanged by this change and remain open where they are recorded.
