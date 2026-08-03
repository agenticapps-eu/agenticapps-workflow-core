## Why

`project-hook-binding`'s requirement **"An unresolvable shim allows, and the
operator sees it"** is ~480 lines — 30% of the capability — and most of them
govern what its heading does not name: the three-axis provisioning state model,
the currency contract, and eleven provisioning scenarios. Two headings below sits
**"Provisioning is checked per machine"**, which already reaches up for that
material, saying *"computed observationally per the state table above"*.

opencode raised this in round 2 of `check-implementation-currency` as
non-blocking. It is correct and pre-existing, and that change made it worse by
adding ~200 lines under the wrong heading. Its archive note records why it grows
with delay: *"the longer it waits the larger the move gets."*

A requirement is the unit a reviewer reads and a conformance check cites. The
licence governing whether the fleet's protections may be described as running as
documented is filed under shim resolution, so the reader most likely to need it
is the reader least likely to find it.

## What Changes

- **Split one requirement into three**, so each heading names what it governs.
  Net: 15 → 17 requirements across the capability, and the oversized requirement
  drops from ~480 to ~230 lines.
- **RENAMED — `An unresolvable shim allows, and the operator sees it` becomes
  `A shim that resolves no implementation allows the call and reports it`.**
  **The rename is forced by the tooling, not chosen**: OpenSpec rejects a
  requirement present in both `ADDED` and `REMOVED`, so the surviving piece of a
  split cannot keep its name. It keeps shim resolution, the non-blocking
  exit-code rule, warning-channel verification, the repetition policy, the
  two-distinct-non-resolutions carve-out and the §18 gate consequence. Six
  scenarios.
- **NEW — `A machine's provisioning is a triple, not a state name`** takes the
  three-axis table entire, the `none` / `partial` / `complete` / `attested` /
  `drifted` invariants, the "state is the triple" rule with the `none`+`drifted`
  case, the deliberate non-merger of `stale` and `drifted`, and "all three axes
  are computed from what is on disk, never from what happened." Two scenarios.
- **NEW — `Currency is judged against an authority checkout`** takes declared-set
  scoping, authority-is-a-checkout-not-a-branch, the `current` / `stale` /
  `unknown` invariants with their aggregation rule, the
  `complete`+`attested`+`current` licence, strict mode and the
  contradictory-flags usage error. Eight scenarios.
- **`Provisioning is checked per machine, not only per repository`** keeps the
  per-machine argument and gains the rollout-ordering paragraph currently
  stranded upstream. Its `"per the state table above"` reference resolves to a
  requirement that now announces the state table.
- **NOT BREAKING.** No normative sentence is added, removed or reworded. No
  tool, test or shim reads these headings.

## Capabilities

### New Capabilities

None. This is a restructuring within an existing capability; no new capability is
introduced.

### Modified Capabilities

- `project-hook-binding`: three requirements replace two. No requirement's
  normative content changes — the delta is placement only, plus the two new
  headings and the sentences that carry material across the new boundaries.

## Impact

- `openspec/specs/project-hook-binding/spec.md` — the only file whose content
  changes.
- **No code, tool, test or template is affected.** Verified by search: no file
  under `tools/`, `reference-implementations/` or `migrations/` cites a
  requirement *heading*. `tools/project-hook-shim.test.sh` contains the phrase
  "unresolvable shim" in test descriptions, but as behavioural prose, not as a
  reference to the heading — the assertions are on exit codes and stderr.
  `provisioning-check.sh` and `project-hook-conformance.sh` implement the state
  model and cite no heading at all.
- **One positional reference must survive the move.** "Provisioning is checked
  per machine" says the state is *"computed observationally per the state table
  above"*. The new requirement owning the table must end up **above** it. This
  is an invariant of the ordering, not an accident of it, and is checked as a task.
- **`openspec archive` appends ADDED requirements to the end of the spec and
  cannot express placement.** Left alone it lands the three new requirements at
  the bottom of the file, which falsifies "above" and exiles the shim
  requirement 900 lines from its siblings — defeating the change. The spec is
  therefore **reordered by hand after the fold**, as a disclosed step of this
  change, re-verified by the same line-level multiset diff. Established by
  probing `archive` and resetting, not assumed.
- **Risk is concentrated in one failure mode**: silently dropping or reweighting
  a normative sentence during a ~290-line move. Mitigated by a mechanical
  set-difference of every `SHALL` / `MUST` / `MAY` sentence before and after,
  which must be empty — not by re-reading the result. A baseline of 116
  normative sentences, 67 scenarios and the three verbatim axes-table rows was
  captured before any edit.
