## Why

A shim whose report is suppressed by the hourly rate limit still exits 1, so the
host renders `hook error — No stderr output`. The alarm fires exactly as often as
the message would have and says nothing — which is worse than the repetition the
rate limit was adopted to prevent. Reproduced three times on 2026-08-04 against an
unresolvable shared install.

Fixing what shims say is a contract change, and the contract requires every
declared binder to be reached and verified. Measured with the repo's own
instrument, only **two of seven** binders carry a contract shim at all: five
carry unmarked inlined copies of all three hooks, which are invisible to the
currency axis and carry live defects the reconciliation already fixed and never
delivered.

## What Changes

- A suppressed report emits **one** line and keeps `exit 1`, instead of exiting 1
  with empty stderr. The rate limit becomes a verbosity limit, which is what it
  can actually deliver — the exit code is not suppressible without converting an
  announced fail-open into a silent one.
- The general invariant behind that instance is stated and tested: **a shim's
  non-zero exit always carries at least one stderr line.**
- The version-bump rule gains *reporting* alongside resolution order, exit
  behaviour and identification. This change is the proof: it alters what every
  shim says without touching any of the three currently named.
- **BREAKING (shim contract):** `shim-contract` goes to **1.2.0**. Every shim at
  1.1.0 is stale until re-issued.
- All seven declared binders are brought to 1.2.0 contract shims — 6 files
  re-versioned, 14 inlined copies converted, 1 file deleted under a documented
  opt-out. Conversions adopt reconciliations already argued in
  `reference-implementations/project-hooks/README.md` (differences 1–6); no new
  semantics are decided here.
- Converting the copies **changes live behaviour in five repos**, in two ways
  that are the point rather than a side effect: `migrations/*` edits stop being
  blocked behind a sentinel file those repos do not have (remedy named
  `/gsd-discuss-phase`, removed 2026-07-28), and a false
  `Migration 0009 not yet applied` stub stops being injected into `CLAUDE.md`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `project-hook-binding`: the repetition-policy requirement gains a suppressed-
  report clause; a new requirement states the non-zero-exit-implies-a-message
  invariant; the contract-version-bump rule adds reporting to the three things
  that oblige a bump.

## Impact

- `reference-implementations/project-hooks/shim-template.sh` — the authority.
- `reference-implementations/project-hooks/openspec-change-gate.shim.sh` — carries
  its own copy of the same `report_rate_limited`.
- `tools/project-hook-shim.test.sh` — RED first, for both the instance and the
  invariant.
- `reference-implementations/project-hooks/README.md` — the propagation note
  currently says three repos; the instrument says five, across two families.
- **Seven repositories outside this one**, each by its own branch and PR:
  `agenticapps-dashboard`, `agenticapps-roadmap`, `agents-task-viewer`,
  `callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`. Four are in the `factiv`
  family; the cross-family work is explicitly authorized for this change and is
  not a standing permission.
- Verification instrument: `tools/project-hook-conformance.sh --fleet ~/Sourcecode`,
  which reports **30 findings today** and must report **0** when this change is
  done.
