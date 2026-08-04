## Why

`retire-the-conformance-instrument` deleted the tool and removed two
requirements that specified its reporting. It missed a third.

"Registration matches the implementation's tool coverage" specifies four
properties, and the fourth is:

> **Check** — a conformance tool SHALL evaluate every declared hook in every
> scanned project against the declaration, and SHALL say when it could not
> evaluate one rather than passing over it.

There is no conformance tool. The capability now mandates a check that does not
exist — which is the failure the same requirement complains about three
paragraphs earlier ("a requirement with no check makes nothing detectable"),
arrived at from the other direction. Its declaration file,
`reference-implementations/project-hooks/MATCHERS`, correspondingly has no
reader: three rows of data that look maintained and are not.

This was found by asking why `MATCHERS` was being kept. The answer was that it
had been kept, not that it was needed.

## What Changes

- **`reference-implementations/project-hooks/MATCHERS` is deleted**, and the
  three declared matcher sets move into the requirement itself as a table. The
  contract content survives where the contract lives; the file that duplicated it
  does not.
- **The `Check` property is withdrawn**, and what withdrawing it costs is stated
  in its place: a narrow or absent registration is no longer detected, and
  surfaces when the hook does not fire. The five-repository `MultiEdit` defect is
  retained as the evidence that this is a real cost — it is also, however, the
  evidence that a person found it without a tool.
- **Five scenarios are reworded** from what a check reports to what is true of
  the project. None is dropped: "the check reports it as a finding" becomes "that
  project is not bound for that hook", and so on. The obligation moves onto the
  change that rewrites a `settings.json`, which the first scenario already
  required to verify its work per project.
- **A condition is placed on reinstating it.** If a matcher check comes back, it
  comes back as a comparison inside an existing script — not as a capability with
  requirements of its own to be defective in. That distinction is the whole
  difference between the tool that was needed and the instrument that was built.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `project-hook-binding`: one requirement modified — the declaration inlined, the
  check mandate withdrawn with its cost stated, five scenarios restated as facts
  about projects rather than as outputs of a tool.

## Impact

- **Deleted**: `reference-implementations/project-hooks/MATCHERS` (3 rows, no
  reader).
- **Unchanged**: `tools/check-shims.sh`. It was offered a matcher axis and did
  not get one; adding a JSON parser to it is how the retired instrument started.
- **What is genuinely lost**: nothing verifies that a project's `settings.json`
  registers each hook on the tools its implementation handles. That has gone
  wrong once, across five repositories, and it was found by a person noticing a
  hook had not fired. The remedy now sits on whoever edits a `settings.json`,
  which is where the knowledge is and where the edit happens.
