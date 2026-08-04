## Why

`openspec/specs/project-hook-binding/spec.md` currently says two different things
about one condition, and carries one sentence split across two requirements. Both
defects are pre-existing in `main`, both survived `openspec validate --all`, and
both survived the line-multiset diff that guarded the last refactor — because
neither check can see them.

The first is the contradiction the previous session deliberately left unfixed
rather than smuggle a normative change into a no-semantic-change refactor. The
second was found while confirming the first, and is the sharper of the two: a
paragraph was torn in half by the archive fold at `09f829e`, and its second half
now sits inside a different requirement, where it reads as an orphaned fragment
opening with a lowercase continuation.

## What Changes

- **The Currency cell of the provisioning axes table gains the presence qualifier
  its own `current` clause already carries.** The cell says an artifact is `stale`
  when "the authority holds no file for a declared artifact". Three sources say
  otherwise for an artifact absent from the machine, and they agree with each
  other:
  - the requirement prose — "Currency is judged over the declared artifacts that
    are PRESENT … whether or not the authority holds it";
  - the scenario *The authority holds no such artifact* — "a declared artifact
    that is absent from the machine *and* from the authority is **not** judged
    for currency at all";
  - the implementation — `tools/provisioning-check.sh` skips absent artifacts
    with `[ -f "$art" ] || continue` before any currency comparison.

  The table is the lone outlier, and it is the summary a reader meets first. It
  is narrowed to match; the requirement, the scenario and the code are unchanged.

- **The torn paragraph is restored.** Three lines are moved back from the
  requirement *Currency is judged against an authority checkout* into the
  paragraph they were severed from in *A machine's provisioning is a triple, not
  a state name*, verbatim as they stand in the pre-fold delta at `db02493`. No
  requirement changes meaning; two requirements stop each holding half a
  sentence.

- Not breaking. No behavior changes: the narrowed clause describes what the
  implementation already does.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `project-hook-binding`: two requirements are modified.
  - *A machine's provisioning is a triple, not a state name* — the axes table's
    Currency cell narrows its `stale` condition to **present** artifacts
    (normative), and the paragraph severed by the fold is made whole again
    (placement only).
  - *Currency is judged against an authority checkout* — the orphaned fragment
    is removed (placement only). Its normative content is untouched.

## Impact

- **Spec:** `openspec/specs/project-hook-binding/spec.md` — two requirements.
- **Code:** `tools/provisioning-check.sh` is **unchanged** — it already implements
  the behavior the narrowed clause describes, and is this change's evidence
  rather than its target.
- **Tests:** `tools/spec-placement.test.sh` is **added** and wired into
  `.github/workflows/openspec-gate.yml`. It sweeps every spec in
  `openspec/specs/` for torn paragraphs and asserts the currency cell's two
  clauses stay scoped together. It exists because the check that guarded the last
  refactor proved every line survived and is structurally unable to detect a line
  filed under the wrong heading — which is exactly how the torn paragraph reached
  `main`. Added on review: all three reviewers independently observed that a
  one-off assertion would not guard the next fold.
- **Downstream:** none. No host consumes the table cell programmatically.
