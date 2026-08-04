## Context

Two defects, both pre-existing in `main`, both inside the capability's
provisioning section, both invisible to every check currently guarding it.

**Defect B — the axes table contradicts the requirement it summarises.** Line 847
defines Currency:

> `current` when every declared, **present** implementation is byte-identical to
> the authority's file …; `stale` when any differs, **or the authority holds no
> file for a declared artifact**

The `current` clause is scoped to present artifacts. The `stale` clause is not.
So for one condition — an artifact that is declared, absent from the machine, and
absent from the authority — the table reports `stale` while three other sources
report nothing at all:

| Source | Location | Verdict on that condition |
|---|---|---|
| Requirement prose | `spec.md:989` | not judged — "whether or not the authority holds it" |
| Scenario *The authority holds no such artifact* | `spec.md:1078` | "**not** judged for currency at all" |
| Implementation | `provisioning-check.sh:422` | `[ -f "$art" ] \|\| continue` — skipped before comparison |

**Defect A — a sentence spans two requirements.** The archive fold at `09f829e`
severed a paragraph. Its first half ends mid-clause at `spec.md:861`:

> `CLAUDE.md` went 0644 in and **0600** out, and `DELETE FROM public.users` was

Its second half sits ~66 lines later at `spec.md:927`, inside a *different*
requirement, opening on a lowercase continuation:

> **not** blocked. Both are defects the fleet believed were fixed. …

The pre-fold delta at `db02493` has the paragraph intact, confirming the tear was
introduced by the fold and not by the requirement split in PR #70.

**The constraint that shapes this change.** Neither defect is detectable by
anything currently run. `openspec validate --all` is green on both — verified on
the unmodified tree. The line-multiset diff that guarded the last refactor proves
every line survives and is *structurally* unable to notice that a line moved to
the wrong heading, which is precisely how Defect A reached `main`.

## Goals / Non-Goals

**Goals:**

- Make the table say what the requirement, the scenario and the code already say.
- Make the torn paragraph whole, in the requirement it belongs to.
- Verify by *placement*, not by survival — the property the previous check missed.

**Non-Goals:**

- Changing what the currency axis does. No code changes; `provisioning-check.sh`
  is already correct.
- Reordering, renaming, splitting or merging requirements. The tooling facts from
  the previous session (a `MODIFIED` cannot shed scenarios; a requirement cannot
  appear in both `ADDED` and `REMOVED`; `ADDED` requirements land at end-of-file)
  are avoided by construction rather than worked around.
- Fixing the *other* sentence fragment noted below. See Open Questions.

## Decisions

### D1 — Fix the table, not the requirement

**Chosen:** narrow the table's `stale` clause to `a declared, present artifact`.

The vote is three to one, and the majority includes the running code. More
decisive than the count: the requirement gives a *reason* the table does not
contradict — "reporting one fact on two axes is what made the flat four-state
list unusable" (`spec.md:992`). An artifact absent from the machine is already
completeness's finding. The table cell is a summary that dropped a qualifier; the
requirement is the considered text.

*Alternatives considered:*

- **Fix the requirement and the code instead**, making absent-from-both report
  `stale`. Rejected: it contradicts the requirement's own stated rationale,
  contradicts the scenario at `spec.md:1074`, and would require editing
  `provisioning-check.sh:422` to *add* a finding that says nothing new. This is
  the option that repairs the wrong side of the contradiction.
- **Delete the clause from the table**, leaving "`stale` when any differs".
  Rejected: under-specifies. Declared *and installed* but absent from the
  authority is a real `stale` finding, specified at `spec.md:1074` and
  implemented at `provisioning-check.sh:424-429`. Dropping the whole clause
  loses a true case in order to fix a scoping error.

### D2 — Minimal edit: one qualifier, matching the cell's own wording

**Chosen:** insert `, present` so the clause reads "the authority holds no file
for a declared, present artifact".

The cell's `current` clause already says "every declared, present
implementation". Reusing that exact phrasing makes the two clauses visibly
parallel and makes the omission self-evidently the defect it was. Rewriting the
cell more broadly was rejected: a larger diff in a normative table invites review
of text that is not wrong.

### D3 — Restore Defect A verbatim from git, do not rewrite the seam

**Chosen:** move the three lines back byte-for-byte as they stand in `db02493`.

The original text is recoverable, so reconstruction would be invention where
restoration is available. Rewriting the seam would also make the diff a prose
change requiring judgement, rather than a restoration verifiable against a commit.

### D4 — Both defects in one change, each labelled distinctly

**Chosen:** one change, two `MODIFIED` requirements.

The previous session refused to bundle a normative fix into a refactor advertised
as semantics-free. That principle forbids *concealment*, not co-delivery: here the
change is advertised as normative up front and the placement repair is labelled
separately in the proposal and the delta. Both defects also touch the same
requirement, so splitting them would mean editing one requirement twice in
sequence across two full lifecycles — more surface, no more safety.

### D5 — Verify placement, not survival

**Chosen:** commit `tools/spec-placement.test.sh`, wired into CI beside the other
conformance tests.

A line-multiset diff would pass this change even if the paragraph landed in the
wrong requirement again — it is the check that already failed here once. The
check therefore looks for the two signatures a tear leaves: a paragraph opening
mid-sentence, and a paragraph whose ending was taken away. It also asserts the
currency cell's `current` and `stale` clauses stay scoped together, so Defect B
cannot silently reopen.

**Revised after review.** The first version of this decision described assertions
the executor would run once during apply. All three reviewers independently
pointed out that this guards *this* fold and nothing after it, which was correct
— the claim of durable mitigation and the one-off mechanism did not match. The
check is now a committed test running over `openspec/specs/*/spec.md`, so a spec
added later is covered on the day it appears.

Scope note: this is code, in a change whose spec footprint is one clause. That is
deliberate and was the reviewers' point — the alternative was to keep the
mechanism ephemeral and delete the durability claim from the Risks section, which
would have been honest but would have left the fold unguarded.

## Risks / Trade-offs

- **The narrowed clause is read as removing a real finding** → It does not. The
  declared-*and-installed*-but-absent-from-authority case stays `stale`; only the
  absent-from-machine case, which the code never reported, leaves the cell.
- **The restoration re-tears on a future fold** → This is not hypothetical; it is
  what happened. The placement assertion added here is the mitigation, and it
  will run against the folded spec, not only against the delta.
- **A one-word normative diff attracts less review than it deserves** → The
  Stage-2 plan review runs before any edit, and the proposal states the normative
  footprint explicitly rather than letting reviewers infer it from the diff size.
- **Restoring verbatim carries forward any flaw in the original sentence** →
  Accepted deliberately. Restoration and revision are separate acts; folding a
  rewrite into a repair is the concealment D4 rejects.

## Migration Plan

None. Spec-only change; no deployed artifact, no data, no rollback beyond `git
revert`.

## Open Questions

- **Is Defect A the only tear?** Resolved: yes. The whole file was swept, not
  just the two affected requirements, using the two signatures a tear leaves —
  a paragraph opening on a lowercase word or bold continuation, and a
  non-indented paragraph ending without terminal punctuation:

  | Sweep | Hits | Reading |
  |---|---|---|
  | Paragraph-initial lowercase / bold | `927` | Defect A's orphan — the only one in the file |
  | Paragraph-final, no terminal punctuation | `347`, `861` | `861` is Defect A's first half; `347` is a benign ordered-list terminal item |

  So `project-hook-binding` carries exactly one tear and this change closes it.
  The seam also closes cleanly: the line preceding the orphan — "An axis is what
  obliges the summary to agree with the comparison." — is a complete thought, so
  removing the orphan leaves no gap.

  **The other four specs are swept too, and they are clean** — raised in review,
  and cheaper to run than to file as debt. `change-gate-enforcement`,
  `conformance-harness-reporting`, `core-self-enforcement` and
  `plan-review-production` all report zero on both signatures, so
  `project-hook-binding` carries the only tear in the repo. Because the committed
  check globs `openspec/specs/*/spec.md`, a spec added later is covered without
  anyone remembering to extend it.

  One honest limit remains: the sweep detects tears at *paragraph boundaries*. A
  fragment relocated as a whole, grammatically intact paragraph would pass it,
  and only reading for sense would catch that. This is the same gap that let the
  line-multiset diff through, narrowed rather than closed — the independent
  reviewer is still the only thing that reads for sense.
