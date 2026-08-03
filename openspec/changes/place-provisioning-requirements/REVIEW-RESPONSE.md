# Review response — place-provisioning-requirements

Round 1: gemini APPROVE, codex REQUEST-CHANGES, opencode REQUEST-CHANGES.

Two REQUEST-CHANGES verdicts do not block — since gate 2.0.0 nothing does. That
is precisely why each objection was checked against the tree rather than noted.
**Nine accepted, two rejected on verified grounds, one partly accepted.**

## Accepted and fixed

**codex-1 — the load-bearing ordering lives outside the reviewed delta.**
Correct, and unavoidable: `ADDED` requirements are appended at end-of-file and
the delta cannot express placement. Fixed by making the reorder a *reviewable
artifact* rather than a hand-edit — `tools/reorder-requirements.py` moves whole
`### Requirement:` blocks by heading name, is idempotent, and **refuses if the
line multiset changes**. Added tasks 4.2/4.3.

**codex-2 — a sorted line-multiset cannot detect content attached to the wrong
requirement.** The strongest objection of the round. A mis-cut block preserves
every line and every global count while filing the currency invariants under the
state model, and the check would pass. Added task 5.3: per-requirement scenario
inventory (6/2/8/2) plus a defining-marker check — axes table only under the
triple, licence only under currency, exit-code rule only under the shim.

**codex-3 — a second positional dependency was overlooked.** Verified: *"per the
`stale` invariant below"* exists in the `stale`/`drifted` non-merger paragraph,
which moves to the triple, while the `stale` invariant moves to currency. A third
also exists — *"contradicting the `stale` invariant above"* in the last
requirement. The design's claim that the reference "runs one direction" was
**false**. Replaced with a table of all three, their directions, and why each
survives; task 4.4 checks all three.

**codex-4 — the impact assertion is already false.** Verified:
`session-handoff.md:93` cites the removed heading outside `openspec/`, as does
the archived `check-implementation-currency` change. Proposal corrected to state
this, and task 6.4 rescoped to *executable* consumers. Both documents are
historical records and are deliberately left unedited — correcting them would
falsify a dated account.

**codex-5 — the design calls the shim block `MODIFIED`; the delta encodes it as
`ADDED`.** Correct: stale text left behind when the encoding changed. Removed.

**codex-5b — the rollback claim is inaccurate.** Correct: archiving moves the
change directory, so a revert is not one file. Migration Plan corrected.

**opencode-1 — the verification anchor contradicts itself (605–1085 vs
605–1124).** Correct and material, since the whole change rests on that check.
The boundary is 1124 deliberately: the per-machine requirement (1086–1124) is
also modified, and stopping at 1085 would leave its text unchecked. Now stated
with its reason.

**opencode-2 — the gained-set arithmetic doesn't reconcile.** Correct. "Four
structural headings plus one lead-in" was left over from the `MODIFIED` encoding.
The real figure is **26**, now enumerated in a table so a reviewer can re-derive
it.

**opencode-5 — line-count arithmetic drifts between sections.** Correct.
Normalised to ~250 lines moved and the 568-line delta.

## Partly accepted

**opencode-4 — scenario-count provenance is implicit.** The request for an
explicit before/after table is right and is now in the proposal. But the inferred
figures were wrong: the removed requirement held **16** scenarios, not 17, and
the per-machine requirement held **2** before and **2** after — it does not grow.
The reviewer's reconstruction assumed a scenario moved into the `MODIFIED` block;
none did. Measured, not argued: `awk` over `### Requirement:` / `#### Scenario:`.

The same check found a real error the reviewer was circling: the proposal said
"eleven provisioning scenarios" where the correct figure is **ten** (2 + 8).
Fixed.

## Rejected, with grounds

**opencode-3 — the heading-citation search was too narrow, and a stale by-name
citation in a sibling spec would strand a reference.** The search was widened as
requested, which is why codex-4 above is now recorded. But the conclusion does
not follow: the two hits are `session-handoff.md` and an archived change, both
historical records, and **no sibling spec cites the heading**. Verified across
`openspec/specs/`, `openspec/changes/` and docs. There is no stranded reference
to fix — only superseded mentions in dated documents, which is the correct state
for a record of what was true when written.

**opencode-6 — the two open questions "move with their prose" is unverifiable.**
The Non-Goals phrasing is loose, but the substance holds: the `cmp`-error
distinction is normative text inside the `unknown` invariant, which moves to
currency; the shared-bin gap is recorded in the archive note of the *previous*
change, not in this spec, and was never claimed to move. Phrasing left as-is
because rewriting it would imply a spec change this delta does not make; the
distinction is recorded here instead.

## Not re-run

Round 2 was not requested. The fixes are to change artifacts — proposal, design,
tasks — and to verification scope. **No spec delta content changed as a result of
this round**, so the reviewed delta and the delta to be applied are byte-identical.
That is the property worth checking before trusting this file.
