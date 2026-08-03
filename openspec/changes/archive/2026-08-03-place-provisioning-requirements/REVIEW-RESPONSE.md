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

---

# Round 2 — independent code review (Stage 2)

Run in a fresh context after the spec was applied and reordered. The reviewer
**independently re-derived the content-preservation result** rather than trusting
it, and it held. It then found four defects on the axis the multiset diff is
blind to by construction: **attachment** — content preserved perfectly, but filed
under the wrong heading. Three fixed, one recorded.

## Fixed

**R2-1 — the "The installer runs" scenario was filed away from the SHALL it
tests.** Confirmed: the scenario sat under *"A machine's provisioning is a
triple"*, while the obligation it exercises — *"The installer SHALL verify that
every shimmed implementation is present and executable"* — is at `:722-727` under
the shim requirement. The `complete` invariant only *defines* a value and imposes
nothing on the installer.

Fixed by moving the **scenario** to the shim requirement, not the paragraph to
the triple as the reviewer suggested. That sentence is load-bearing inside the
shim requirement's absence-versus-misconfiguration carve-out (*"a per-tool-call
block is not a substitute for it"*); moving it would have broken that argument to
fix a filing error. Scenario counts go 6/2/8/2 → **7/1/8/2**.

**R2-3 — a paragraph reorder retargeted a pronoun.** Confirmed: the currency
blocks were emitted `635 → 673 → 644 → 653 → 659`, the one place relative order
was not preserved. *"This was found by its consequence"* originally continued
*"A machine can therefore be `complete` + `attested` against a stale row
indefinitely"* — which now lives in the triple.

The reviewer proposed disclosing it. Better available fix taken instead: the
2026-08-03 evidence paragraph moved to the **triple**, immediately after
*"Currency is a third axis and not a value on either of the others"*. That
restores the original adjacency **and** the original referent, and the evidence
argues for the third axis, which is the triple's thesis. No disclosure needed for
a thing no longer true.

**R2-4 — `The rule that a project must never bind a missing implementation…` was
dangling.** Confirmed: both its referents — the rule itself, and the
fresh-clone contradiction it resolves — live in the triple, 220+ lines away.
Moved to the triple, beside the contradiction. The genuinely
rollout-ordering paragraph stays under per-machine.

## Recorded, not fixed

**R2-2 — the axes table's Currency row is stranded from the rules that narrow
it.** The strongest observation of the round. The table's `stale` cell says
*"or the authority holds no file for a declared artifact"*, while the Currency
requirement says an artifact absent from the machine is **not** judged on this
axis at all. For an artifact absent from both, the table and the rules disagree.

Not fixed here, deliberately. The tension is **pre-existing and byte-identical in
`main`** — the split did not create it, it relocated the qualification further
from the claim. Narrowing the table's cell to `declared, present` would be a
**normative change**, and this change's entire contract with its reviewers is
that it changes no normative text. Fixing a real defect inside a
no-semantic-change refactor is how a relocation smuggles in a rewrite.

This is the correct seed for the next change, and it is a better-formed defect
than the placement complaint that started this one: the spec says two different
things about one condition. Filed here rather than in a handoff so it travels
with the capability.

## What this round demonstrates about the verification

The multiset diff proved the text was preserved and was **right**. It also could
not have found any of R2-1, R2-3 or R2-4, all of which are real. The
per-requirement marker check (added after round 1) caught neither, because it
checked the three markers it was told to check.

**A mechanical check is only as good as the property it encodes**, and
"every line still exists" is a weaker property than "every line is in the right
place". The independent reviewer, reading for sense, is what closed that gap.
