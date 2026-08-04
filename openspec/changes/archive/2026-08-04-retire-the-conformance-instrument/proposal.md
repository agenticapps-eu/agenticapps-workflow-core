## Why

The migration this repository was asked for — hook implementations published
once and bound by every project through a shim, instead of five inlined copies —
shipped on 2026-08-02 (PR #61, ADR-0029). All seven declared repositories bind
all three shimmed hooks, byte-identical to the authority.

The instrument built alongside it did not stop.

| | lines |
|---|---|
| The thing bound: shim template + gate shim | 320 |
| `tools/project-hook-conformance.sh` + its suite | 1,962 |

`project-hook-conformance.sh` was created inside PR #61 itself, from a task in
that change's own plan — *"a version marker with no check makes nothing
detectable"* — rather than from anything anyone asked for. The reasoning was
locally valid and never checked against the goal: the shim carries a marker, so
the marker needs a verifier; the verifier needs a spec; the spec needs axes; the
axes produce findings; the findings produce changes. **Six of the eight changes
archived in the last eight days are repairs to the instrument, not to the fleet.**
Each repaired a real defect, and each was discovered by reading the previous
one's output. That is a loop with its own supply of work.

The most recent iteration is the argument in miniature. `instrument-counts-what-it-names`
corrected three numbers whose labels asked narrower questions than they answered;
its Stage-2 review then found that the corrected classifier had *lost* detection
of Makefile, `*.mk`, `justfile` and `Taskfile.yml` assignments — four ways to set
an override, all reported as `OK — no known vector found`. The next change would
have fixed that. This one stops instead.

## What Changes

- **`tools/project-hook-conformance.sh` and its 1,000-line suite are deleted**,
  along with the `instrument-counts-what-it-names` change that was repairing
  them. Nothing invokes either: every reference to the tool in this repository
  and in the family is a comment, and it was never wired into CI.
- **`tools/check-shims.sh` replaces them** — one line per (repository, hook)
  saying whether the shim is present and whether its bytes match the authority,
  exit 1 if any is missing or drifted. Run by hand after a shim-contract bump,
  which is the only event that can invalidate the answer. Core is in the default
  target list rather than excluded from it.
- **Two requirements are removed** from `project-hook-binding`: "An absent shim
  is a finding, not a silence" and "The authority's own binder is scored, never
  assumed". Both specify the reporting behaviour of the deleted instrument.
- **The override-vector scan stops being mandated.** "A project binds a hook
  through a shim" keeps the policy (a project SHALL NOT set an override
  variable), keeps the honest statement that the policy is not enforced at
  runtime, and keeps the vector list as guidance for a reviewer — but no longer
  requires a check to scan for it. A capability that mandates measurement gets
  the measurement it mandates.
- **`OPT-OUTS` is retained**, read by the replacement script in three lines, so
  `agents-task-viewer`'s argued non-binding of `normalize-claude-md` still
  reports as an opt-out rather than a missing file. `MATCHERS`, `FLEET`,
  `SHIMMED-HOOKS` and `ARTIFACTS` are retained; they declare contract content and
  `ARTIFACTS` has two other consumers.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `project-hook-binding`: two requirements removed, and the detection block
  inside "A project binds a hook through a shim" restated from a mandate on a
  check to guidance for a reviewer.

## Impact

- **Deleted**: `tools/project-hook-conformance.sh` (962 lines),
  `tools/project-hook-conformance.test.sh` (1,000 lines).
- **Added**: `tools/check-shims.sh` (~60 lines with its header).
- **Untouched and deliberately so**: `tools/provisioning-check.sh` and the four
  provisioning requirements it implements answer a different question — whether
  *this machine* has the shared install — and nobody has complained about it.
  `openspec/specs/conformance-harness-reporting/` governs the harnesses that
  measure *host* implementations of the gate, producer and reviewer, which is a
  different set of tools and out of scope here.
- **Not deleted, not merged**: branch `feat/instrument-counts-what-it-names`
  keeps its eleven commits, its evidence and its code review. If retiring the
  instrument proves wrong, the repair is still there.
- **What is genuinely lost**: nothing detects a project that sets an override
  variable in its own files. That detection ran seven times and found nothing,
  it never covered the route the capability says matters most (an operator's own
  shell), and the policy remains stated. This is a real reduction in coverage and
  is accepted rather than argued away.
