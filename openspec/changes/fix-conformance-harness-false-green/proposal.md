## Why

Core's conformance harnesses are the instruments that decide whether a host's
gate, producer or wrapper conforms. Two of the five certify **nothing** while
reporting success: given a target that does not exist they print `SKIP`, score
zero rows, and exit 0.

```
$ bash tools/change-gate-conformance.sh /nonexistent/gate.sh
  SKIP  /nonexistent/gate.sh (not found)

═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
$ echo $?
0
```

A measurement tool that returns "pass" when it measured nothing is the exact
failure it exists to prevent. §18 requires a gate be "demonstrable by direct
script invocation with simulated payloads"; a host CI that wires this harness
and sees green has demonstrated nothing, and cannot tell that apart from a gate
that scored 71/71.

**Why now.** The blast radius just grew. `--family` filters absent hosts out of
its roster before scoring, and as of the pin-and-resolve migration **two of six
roster entries no longer exist on disk** — `claude-workflow` and
`codex-workflow` stopped vendoring `bin/openspec-change-gate.sh` because they
now resolve it from a pinned commit. The sweep silently scores 4 of 6 and
reports success. Nothing is broken; the certification just quietly got
narrower, which is worse, because narrowing leaves no trace.

Both host CIs already carry hand-rolled `test -s` / `--check` workarounds for
this. The workaround is in the wrong place: core owns the harnesses, so every
host that wires one inherits the defect until core fixes it.

## What Changes

- **BREAKING (for callers that relied on exit 0):** a conformance harness given
  an explicitly-named target it cannot score now **fails** instead of skipping.
  Naming a target is the caller asserting it should be there.
- A harness that completes having scored **zero rows** exits non-zero
  regardless of how it got there. This is the backstop: it holds even for an
  absence path nobody anticipated.
- `--family` gains an explicit **coverage line** — `scored N of M roster
  entries`, naming every entry it did not score **and the reason**. Roster
  absence stays non-fatal (claude and codex are absent *by design* now), but it
  can no longer be invisible.
- The same fix lands in `run-plan-review-conformance.sh`, which carries the
  identical defect at the identical line.
- A target that is not a regular file, is **empty**, or is **unreadable** is
  reported as unscoreable rather than fed to the row engine — where a zero-byte
  file passes every `expect 0` row, and an unreadable one fails forty rows
  while the actual fault is a file mode.
- Core gains a normative requirement for how its own harnesses report — the gap
  that let this drift. It lands as a new **declarative-contract** section, not
  in §09: §09 is `section_type: framing` and governs *host* conformance claims,
  so normative SHALL text about core's own instruments does not belong there.

## Capabilities

### New Capabilities
- `conformance-harness-reporting`: what a conformance harness must do when it
  cannot score a target — the distinction between a scored failure, a declared
  non-scoring, and a result that may be reported as success at all.

### Modified Capabilities
<!-- None. `change-gate-enforcement` and `plan-review-production` describe what
     the gate and producer must DO; this change alters only how the harnesses
     that measure them REPORT. No requirement about gate or producer behaviour
     moves. -->

## Impact

- `tools/change-gate-conformance.sh` — entry point, both absence sites.
- `tools/run-plan-review-conformance.sh` — entry point, same defect. Explicit
  paths only; it has no roster mode.
- `tools/reviewer-cli-conformance.sh` — already correct at the explicit-path
  site (it is the reference for this fix); its `--family` builder gains the
  coverage line. Roster mode exists on exactly these two harnesses.
- `tools/resolve-core-artifact-conformance.sh`, `tools/shared-install-conformance.sh`
  — single-target tools that already abort non-zero on absence. Their behaviour
  is declared conformant by the delta rather than changed.
- `spec/` — a new declarative-contract section carrying the requirement, plus
  the `spec_version` bump and CHANGELOG entry.
- **Downstream, deliberately:** host CIs currently green *because* a target was
  missing will go red. That is the change working. `codex-workflow` must
  materialise `bin/` before invoking the harness rather than relying on the
  silent skip; the `test -s` / `--check` workarounds in host CIs become
  redundant and should be removed in follow-up, not here.
