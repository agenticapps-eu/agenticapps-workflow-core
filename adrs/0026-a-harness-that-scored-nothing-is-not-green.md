# ADR-0026: A harness that scored nothing is not green

**Status**: Accepted  **Date**: 2026-07-31  **Spec**: 1.4.0 (§20)

## Context

Five conformance harnesses live in `tools/`. They decide whether a host's
change-gate, review producer or reviewer wrapper conforms. Asked to score a
target that does not exist, they did three different things:

| Harness | Behaviour | Exit |
|---|---|---|
| `change-gate-conformance.sh` | `SKIP … (not found)`, continue | **0** |
| `run-plan-review-conformance.sh` | `SKIP … (not found)`, continue | **0** |
| `reviewer-cli-conformance.sh` | counted as a failure row | 1 |
| `resolve-core-artifact-conformance.sh` | abort, "no such resolver" | 2 |
| `shared-install-conformance.sh` | abort, "not found" | 2 |

Three behaviours, five tools, one job. Nobody chose that; it accumulated one
harness at a time.

The first two produce a **false green**:

```
$ bash tools/change-gate-conformance.sh /nonexistent/gate.sh
  SKIP  /nonexistent/gate.sh (not found)

═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
$ echo $?
0
```

§18 requires a gate be "demonstrable by direct script invocation with simulated
payloads". A host CI wiring this harness and seeing green has demonstrated
nothing — and cannot distinguish that from a gate scoring 71 of 71.

The `--family` roster made it worse in a way that leaves no trace. It filtered
absent hosts out of the roster *before* scoring. When `claude-workflow` and then
`codex-workflow` stopped vendoring `bin/openspec-change-gate.sh` — correctly,
having moved to resolving it from a pinned commit — the sweep began scoring 4
of 6 and printing the same success line as a full sweep. Nothing broke. The
certification just quietly got narrower.

Both host CIs had already grown hand-rolled `test -s` / `--check` workarounds.
The workaround was in the wrong repository: core owns the harnesses, so every
host wiring one inherits the defect until core fixes it.

## Decision

**Never exit 0 having scored nothing.** Stated over the whole run rather than
per absence path, because every instance of this defect so far arrived by a
route the previous fix did not anticipate — first the explicit-path skip, then
the roster filter. A scored total of zero is the observable every route shares.

Four decisions carry it:

1. **Named absence fails; roster absence reports.** An explicitly named target
   is a caller assertion that the target should be there — if it is not, the
   run failed. A roster entry is the harness's own guess about where hosts keep
   things, and a host that legitimately stopped vendoring is conformant.
   Failing on roster absence would have gone red the moment `claude-workflow`
   did the right thing.

2. **Two shapes, one rule.** Multi-target harnesses count the failure and
   continue; single-target harnesses abort non-zero. Both satisfy the rule. The
   rule is uniform, the mechanism is not — an earlier draft made it uniform and
   thereby declared two already-correct tools non-conformant.

3. **Coverage is declared on every roster run.** Including complete ones. A
   line printed only when something is wrong becomes the signal, and its
   absence then has to be noticed to mean anything.

4. **Resolution is opt-in.** A pin-and-resolve host is reported as *resolvable,
   not attempted* rather than absent, and `--resolve` will fetch and score it.
   Not the default: resolution reaches a remote commit and fails closed, so a
   network fault would turn a conformance sweep red for a reason unrelated to
   conformance.

## Alternatives Rejected

**Make roster absence fatal.** Simplest rule. It would have gone red the moment
a host adopted pin-and-resolve, and the natural fix — deleting the entry from
the roster — destroys the coverage information entirely and re-creates this bug
in a slower form.

**Unify all five harnesses on a tally.** Consistency of implementation, at the
cost of churning two correct tools to add a tally whose only entry is the abort
they already perform. Callers depend on consistency of *contract*, which is
achieved without touching them.

**An "expected absence" allowlist**, so an undeclared missing entry fails. This
is the attractive one, and it is why the rejection is written into §20 rather
than left as judgement. Such a list is state that must track architectural
decisions taken in five other repositories; it would already have been stale
twice inside one week. A stale allowlist does not fail safe — it re-creates the
silent narrowing while looking more rigorous than the coverage line it
replaced. The filesystem cannot answer "was this meant to be here"; the
coverage line makes sure a person is asked.

**Test the executable bit rather than readability.** Proposed on the reasoning
that a non-executable script could still be run. Targets are invoked as `bash
<path>`, which needs read and not execute; verified that a mode-644 script runs
normally. Requiring `-x` would reject a working target — a false red.

## Consequences

- A host CI green *because* a target was missing goes red. Intended.
  `codex-workflow`'s `bin/` is a gitignored cache, empty on a fresh clone, and
  must be materialised before the harness runs.
- §20 introduces `core-tooling-contract`, a section type that is normative for
  this repository and binds no host. §00 and §09 are amended to say so, because
  filing it as a declarative contract would have conscripted every host into a
  contract about somebody else's tools.
- The harness output gains a structured `UNSCOREABLE <label> — <reason>` marker
  and logical roster labels. Two complete sweeps on different machines now
  produce diffable output, and `$HOME` stops reaching CI logs.
- No conformance verdict moved: core scored 71/71 before and after.

## Note on how this was found and fixed

The change was reviewed by three other-vendor agents before any code existed,
twice. The first round killed a spec delta that would have declared two correct
harnesses non-conformant. The second caught that a fully-absent roster reaches
the usage-error path before printing coverage, and that logicalising the
coverage line alone leaves absolute paths in the per-entry heading.

The test then caught itself twice. Rows asserting that a harness *explains* an
unscoreable target passed against unfixed code, because the fixtures were named
`empty.sh`, `a-directory` and `unreadable.sh` and every harness echoes the
target path — so the rows were asserting the operator had named the file
helpfully. Renaming to `t1`..`t5` exposed a second collision: `/empty/` matched
change-gate's own row description "empty stdin", and `/permission/` matched the
shell's "Permission denied". Both were fixed by requiring a structured marker
no existing output can emit.

That a test for false greens twice scored itself green is the strongest
argument available for the rule it enforces.
