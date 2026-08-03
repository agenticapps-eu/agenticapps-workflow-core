## Why

On 2026-08-03 `tools/provisioning-check.sh` reported this machine
`COMPLETENESS complete`, `INTEGRITY attested`, "This machine is provisioned. The
shims will resolve." — while it was running `database-sentinel` 1.0.0 and
`normalize-claude-md` 1.0.0, three landed fixes behind the 1.1.0 and 1.0.1 that
core ships. Measured on the published copies, not inferred: `normalize-claude-md`
took `CLAUDE.md` from 0644 to **0600**, and `database-sentinel` did **not** block
`DELETE FROM public.users`. Both are defects the fleet believes are fixed.

`project-hook-binding` says of `attested`: "This is the only value on either axis
under which the fleet's protections may be described as running as documented."
That sentence was false on this machine for fifteen hours. `attested` compares
each published file to **the manifest row written when it was installed** — a
record of what *was* published, never of what core *now* ships — so a machine can
be attested against a stale build indefinitely and nothing says so.

The capability defined **two** version markers and built a comparison for one.
`# shim-contract:` got `project-hook-conformance.sh`, which is the tool that
turns a marker into "a property someone can observe". `# <hook>-version:` was
defined in the same change and no check ever reads it against core. That is the
capability's own argument — "a marker with no check makes nothing detectable" —
left unapplied to its own second marker.

## What Changes

- Add a third axis, **currency**, to the per-machine state: `current` / `stale` /
  `unknown`. It is independent of the existing two for the same reason
  completeness and integrity were split from each other — a reviewer showed a
  flat list whose members overlap cannot classify a machine, and "how much is
  installed", "does it match what was installed", and "is what was installed
  still what the authority ships" are three questions, not two.
- **`unknown` is a first-class value, not a failure.** An installed machine need
  not have core checked out, so currency is often uncomputable. It is then
  reported `unknown` and **never** silently `current` — the same honesty rule the
  override scan already applies with "no known vector found", which is a
  statement about what was searched rather than about the machine.
- **BREAKING (to the spec's claim, not to any interface):** the "running as
  documented" clause is weakened. It requires `complete` + `attested` +
  `current`, and `attested` alone no longer licenses it. Nothing that passes
  today starts failing; a machine that was quietly wrong stops being described as
  right.
- `tools/provisioning-check.sh` reports the axis, names each stale artifact with
  both versions and the direction, and counts currency toward `--strict`.
- The remedy is named in the report, because a check that detects a condition
  nobody knows how to clear is a check people learn to ignore: re-run
  `install-project-hooks.sh`.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `project-hook-binding`: the per-machine state gains a third axis; the
  "running as documented" clause is narrowed from `attested` to
  `attested` + `current`; the implementation version marker gains the
  comparison rule and check that the shim marker already has.

## Impact

- `tools/provisioning-check.sh` — the axis, the per-artifact report, `--strict`.
- `tools/project-hook-provisioning.test.sh` — cases for `current`, `stale` and
  `unknown`, including that `unknown` never reports as `current`.
- `reference-implementations/project-hooks/README.md` — the state vocabulary is
  documented there and becomes a triple.
- No change to the installer, the shims, the manifest format, or any published
  artifact. Nothing in the fleet's eight repositories is touched: this is a
  reporting defect in core's own tooling.
- Every machine that has ever run the installer is affected in the sense that
  matters — it may be stale right now and cannot currently find out.
