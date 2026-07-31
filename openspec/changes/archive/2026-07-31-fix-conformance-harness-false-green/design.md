## Context

Five conformance harnesses live in `tools/`. They already disagree with each
other about what to do with a target they cannot score, and the disagreement is
the bug — nobody decided it, it accumulated.

| Harness | Shape | Missing explicit target | Exit |
|---|---|---|---|
| `change-gate-conformance.sh` | multi-target | `SKIP … (not found)`, `continue` | **0** |
| `run-plan-review-conformance.sh` | multi-target | `SKIP … (not found)`, `continue` | **0** |
| `reviewer-cli-conformance.sh` | multi-target | `FAIL file not found`, counted | 1 |
| `resolve-core-artifact-conformance.sh` | single-target | `no such resolver:` | 2 |
| `shared-install-conformance.sh` | single-target | `not found:` | 2 |

Three behaviours, five tools, one job. `reviewer-cli-conformance.sh:169` is the
one that gets it right, and it gets it right by scoring absence as a row rather
than by guarding the entry point:

```bash
[ -f "$CLI" ] || { echo "  FAIL  file not found"; fail=$((fail + 1)); return; }
```

That single line is the whole fix for the multi-target shape, and the reason it
is right is that it puts the absence *inside* the tally the exit code is
computed from.

Roster (`--family`) mode exists on exactly **two** of them —
`change-gate-conformance.sh:868` and `reviewer-cli-conformance.sh:224`.
`run-plan-review-conformance.sh` takes explicit paths only (usage at line 762).
An earlier draft of this note said three; that was wrong, and it mattered,
because it implied a task against a builder that does not exist.

## Goals / Non-Goals

**Goals**

- No harness ever exits 0 having scored nothing.
- A named-but-unscoreable target is a failure in both shapes.
- A roster sweep states its coverage every time, so narrowing is visible.
- One *rule* across all five harnesses, expressed differently per shape, so the
  next harness written copies a settled convention instead of picking from
  three.

**Non-Goals**

- Distinguishing deliberate from accidental roster absence. Now a written
  requirement rather than an omission — see Decision 5.
- Making roster absence fatal. See Decision 1.
- Removing the `test -s` / `--check` workarounds already in host CIs. They
  become redundant, but they live in other repositories.
- Touching what the gate, producer or wrapper *do*. Only the instruments move.
- `tools/drift-report.sh`. It has similar SKIP semantics but is advisory by
  contract — `exit 0` unconditionally at `:257` — so it certifies nothing a
  false green could corrupt. Named in the delta so the next reader does not
  file it as the same bug.

## Decisions

### Decision 1 — Named absence fails; roster absence reports

The two absence sites look identical in the code and are not the same thing.

An **explicitly named** target is a caller assertion: `bash
change-gate-conformance.sh path/to/gate.sh` says *this file is a gate, score
it*. If it is not there, the assertion is false and the run is a failure. This
is the case a CI job hits, and the case that produced the false green.

A **roster** entry is the harness's own guess about where hosts keep things.
Two of six entries are absent right now, both deliberately: `claude-workflow`
and `codex-workflow` stopped vendoring `bin/openspec-change-gate.sh` when they
moved to resolving it from a pinned commit. Failing on their absence would make
`--family` permanently red for an architecture that is correct, and a
permanently red check is one nobody reads.

So the roster keeps skipping — but it SHALL print `scored N of M`, name what it
skipped and why, on every run including complete ones.

**Rejected: make roster absence fatal.** Simplest rule, and wrong. It would
have gone red the moment claude-workflow did the right thing, and the fix would
have been to delete the entry from the roster — losing the coverage information
entirely and re-creating this bug in a slower form.

### Decision 2 — Two shapes, one rule, stated per shape

A reviewer pass found that the first draft's blanket "a conformance harness
SHALL count the failure in its tally" made
`resolve-core-artifact-conformance.sh` and `shared-install-conformance.sh`
non-conformant the moment it landed — both abort with `exit 2` and have no
tally at all. The draft parked that in "Open Questions", which is the wrong
place for a contradiction between a spec and the tools it governs: the spec
would have shipped condemning two tools it intended to leave alone.

Resolved by naming the two shapes normatively and giving each its own
discharge. A single-target harness aborts non-zero; a multi-target harness
counts and continues. Both satisfy the same rule — *never exit 0 having scored
nothing* — and the rule is what is uniform, not the mechanism.

**Rejected: unify all five on the tally.** One reviewer argued the change is
already breaking, so this is the moment to make all five identical. It buys
consistency of implementation at the cost of churning two tools that are
already correct, to add a tally whose only entry would be the abort they
already perform. Consistency of *contract* is what callers depend on, and that
is achieved without touching them.

**Rejected: keep `exit 2` on the multi-target tools too.** It avoids the false
green, but aborts the run — with several targets named, one missing target
denies the caller results for the rest.

### Decision 3 — Unscoreable means three independent things

`[ -f ]` is true for a zero-byte file, and `[ -s ]` is true for a directory, so
neither test alone is sufficient. The check becomes regular **and** non-empty
**and** readable, tested separately so the reported reason can name which one
held.

Each condition earns its place differently, and only one of the three is a
false-green risk:

- **Empty** is the false green. An empty script exits 0, so it passes every row
  expecting 0 — verified: `bash` on a zero-byte file exits 0.
- **Not a regular file** is the same hazard reached via a directory, which
  reports a non-zero size on the filesystems this repository is developed and
  tested on (APFS, ext4). POSIX does not guarantee it, so the condition is
  specified as *not a regular file* rather than as *`[ -s ]` is unreliable* —
  the requirement holds regardless of what any given filesystem reports for a
  directory's size.
- **Not readable** is *not* a false-green risk. Verified: `bash` on an
  unreadable file exits **126**, and no row expects 126, so such a target fails
  its rows loudly. One reviewer asserted it "passes every expect-2 row"; that
  is incorrect, since 126 ≠ 2. The fix is still worth making, for a different
  reason — legibility. An operator shown "this gate failed forty rows" when the
  truth is a file mode will debug the gate.

  A second reviewer noted that `test -r` is true for root regardless of mode,
  so this condition is a no-op in a root CI container. Correct, and now stated
  in the requirement itself. It is kept because a workstation is where file-mode
  accidents happen, but a check that vanishes under the commonest CI
  configuration must not be presented as a guarantee.

**Rejected: test the executable bit instead of readability.** One reviewer
proposed `[ -x ]`, on the reasoning that a non-executable script could still be
run and would exit 0 if empty. The harness invokes targets as `bash <path>`,
which needs read permission, not execute. Verified: a mode-644 script run as
`bash file` executes normally and returns its own exit status. Requiring `-x`
would reject a fully scoreable target — a false *red*, and the emptiness case
the reviewer was reaching for is already covered independently by the non-empty
condition.

### Decision 4 — "Scored" is passed + failed; inconclusive is neither

Two harnesses already track an `inconclusive` counter, and
`run-plan-review-conformance.sh:256` emits INCONCLUSIVE precisely when a
neighbouring artifact is absent. So a run can end `0 passed, 0 failed, 5
inconclusive` — rows ran, nothing was determined. Left undefined, the backstop's
key observable would be ambiguous in exactly the situation it exists for.

An inconclusive row is reported when the harness could not determine the
answer. Counting it as evidence gathered would turn "I could not tell" into "I
checked". So scored = passed + failed, and an all-inconclusive run trips the
backstop.

### Decision 5 — Do not try to distinguish deliberate from accidental absence

A reviewer proposed encoding expected absence in roster metadata, so that an
entry missing without a declaration fails. Rejected, and the rejection is
written into the spec rather than left as a judgement call, because the idea is
attractive enough to be re-proposed.

Such an allowlist is state that must be updated in lockstep with architectural
decisions taken in five other repositories. It would already have been stale
twice inside one week, as claude-workflow and then codex-workflow moved to
pin-and-resolve. A stale allowlist does not fail safe: it re-creates the silent
narrowing this change exists to close, while looking more rigorous than the
coverage line it replaced.

The filesystem cannot answer "was this meant to be here". The coverage line
makes sure a person is asked.

### Decision 6 — The backstop is redundant on purpose

Both the per-site scoring and a terminal "scored nothing → non-zero" check are
implemented. Every instance of this defect so far arrived by a route the
previous fix did not anticipate — the explicit-path skip, then the roster
filter. Scoring each known site fixes the routes we can see; the terminal check
keys on the observable every route shares. It costs three lines.

### Decision 7 — Logical roster labels across all roster output

Roster mode names entries as `claude-workflow`, `~/.agenticapps` and so on, not
as resolved absolute paths — in the coverage line **and** in every per-entry
heading and result line.

The first draft applied this to the coverage line only and justified it on
CI-log hygiene. A reviewer verified that `score_gate` already prints
`═══ $GATE` — the fully resolved absolute path — for every scored entry
(`change-gate-conformance.sh:306`), so `$HOME` reaches the log on every run
regardless. Logicalising one line while leaving that in place would have shipped
a privacy claim the change does not deliver.

So the scope is widened and the rationale is reordered: **comparability** is the
primary reason — two complete sweeps on different machines should produce
diffable output — and log hygiene is a secondary benefit that is now actually
obtained.

Separately, any echoed path has control characters and newlines rendered inert.
A harness whose output can be forged with an embedded newline can be made to
print something that reads like a PASS line.

### Decision 8 — Exit 1 for a scored failure in the multi-target shape

`change-gate-conformance.sh` already spends exit 2 on its usage error and 1 on
a scored failure. An unscoreable named target is a scored failure under
Decision 1, so it takes 1.

The first draft claimed `[ "$fail" -eq 0 ]` "stays the single place the exit
code is computed", which contradicted Decision 6's terminal backstop — a second
computation. Reconciled by folding the backstop *into* that expression rather
than adding a branch beside it: the terminal test becomes "no failures **and**
scored total non-zero", which stays one place and one line.

The single-target tools keep `exit 2`. They have no usage collision, because
their absence message and their usage message are distinct strings and their
callers pass exactly one argument.

### Decision 9 — Resolving a pinned entry is opt-in, never default

A reviewer objected that recording claude-workflow and codex-workflow as
unscoreable "confuses not-vendored with unscoreable", since both ship a
resolver and a pin manifest and could be fetched and scored. The objection is
right about the facts: both `bin/resolve-core-artifact.sh` and
`tools/core-vendor.manifest` are present in each.

But `resolve-core-artifact.sh` reaches a remote commit and fails closed on an
unreachable source. Making resolution the default would put a network
dependency inside the one tool whose whole value is deciding conformance
deterministically — a fetch failure would turn a sweep red for a reason
unrelated to any gate, and the harness would stop working offline.

So: default `--family` stays hermetic and reports those entries as *resolvable
from pin, not attempted* — which answers the objection where it lands, in the
wording, by no longer calling them merely absent. An opt-in resolving mode
scores all six for a caller who wants full coverage and has a network.

**Rejected: always resolve.** Best coverage, worst instrument. A conformance
harness that cannot run without the network is weaker than one that reports
honestly on what it could reach.

**Rejected: leave the wording as "absent".** Cheapest, and it was the first
draft. It institutionalises a permanent `4 of 6` and teaches the reader that
the number is as high as it can go, when it is only as high as the default mode
chose to make it.

### Decision 10 — A new section type, not a declarative contract

§00 states that host requirements "live in the canonical-prose and
declarative-contract sections that follow". A reviewer pointed out that filing
this capability as a declarative contract therefore either makes that sentence
false or silently conscripts every host into satisfying a contract about core's
own tooling.

The requirement ships as `section_type: core-tooling-contract`, with deltas to
§00's framing sentence and to §09's conformance levels stating that
core-tooling-contract sections form no part of a host's conformance claim.

**Rejected: put it in §09.** §09 is `section_type: framing`; normative SHALL
text does not belong there, which is what the first draft got wrong.

**Rejected: state the scope in the section body and keep the declarative type.**
Cheaper, and it half-works — but the taxonomy is what a host reads to decide
what binds it, and a contract that opts itself out in prose is exactly the kind
of exception this repo keeps discovering as drift.

## Risks / Trade-offs

- **Host CIs that are green because of a silent skip will go red.** Intended,
  and the point — but it will land as a surprise on whoever next pushes to
  `codex-workflow`, whose `bin/` is a gitignored cache that is empty on a fresh
  clone. Mitigation: the failure names the file and the reason, which points at
  `materialise-core-artifacts.sh`. Flagged in the proposal's Impact.
- **`--family` output grows by one line.** Accepted.
- **Two shapes is more spec text than one rule.** The alternative was a rule
  that condemned two conformant tools, which a reviewer caught before code
  existed. More text, fewer contradictions.
- **The rule is stated over the whole run, not per call site.** A harness could
  satisfy "scored ≥1 row" while still dropping a target silently. That is why
  Decision 1 exists and Decision 6 is only a backstop; neither alone suffices.

## A note on ordering, for the archive record

This design and the spec delta were written and reviewed BEFORE the code, over
three rounds of other-vendor review. The implementation then landed against
them. A reviewer in the third round observed that the line citations in the
Context table no longer match the working tree — `reviewer-cli-conformance.sh:169`
has moved, the `═══` heading is no longer at `:306`, and so on.

That is correct, and the citations are left as they were on purpose. They
describe the code **as it stood when the defect was found**, which is what the
Context section is for. Rewriting them to point at the fixed code would make
the record describe a problem that, by then, did not exist. The change is a
fix proposed against a real prior state, not a spec retrofitted onto shipped
code.

## Migration Plan

1. Fix the explicit-path site in `change-gate-conformance.sh` and
   `run-plan-review-conformance.sh`, matching `reviewer-cli-conformance.sh:169`.
2. Add the coverage line to the **two** roster builders
   (`change-gate-conformance.sh:868`, `reviewer-cli-conformance.sh:224`).
3. Add the terminal backstop to all five.
4. Land in core. Hosts pick it up on their next re-vendor at the new pin. No
   host action is required, and no host is broken by *not* taking it.

## Open Questions

None. The exit-code question the first draft left open is resolved by
Decisions 2 and 8: shape determines the mechanism, and neither shape may exit
0 having scored nothing.
