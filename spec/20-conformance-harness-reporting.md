---
id: 20-conformance-harness-reporting
section_type: core-tooling-contract
spec_version: 1.4.0
---

# 20 — Conformance harness reporting

**Section type**: core-tooling-contract. This section binds the conformance
harnesses shipped in this repository's `tools/`. It does **not** bind host
implementations, and satisfying it forms no part of any host's conformance
claim at any level (see §09). The keywords MUST, MUST NOT, SHALL, SHALL NOT,
SHOULD and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

> **Why a new section type.** §00 states that host requirements "live in the
> canonical-prose and declarative-contract sections that follow". Filing this
> contract as declarative would either make that sentence false or silently
> conscript every host into satisfying a contract about core's own tooling. A
> host reading the spec should not have to read a section to discover it does
> not apply.

## Why this section exists

The harnesses are the instruments that decide whether a host's gate, producer
or reviewer wrapper conforms. Two of the five certified **nothing** while
reporting success:

```
$ bash tools/change-gate-conformance.sh /nonexistent/gate.sh
  SKIP  /nonexistent/gate.sh (not found)

═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
$ echo $?
0
```

§18 requires a gate be "demonstrable by direct script invocation with simulated
payloads". A host CI that wires such a harness and sees green has demonstrated
nothing, and cannot tell that apart from a gate that scored 71 of 71.

Before this section, five harnesses had three different behaviours on a target
they could not score — count it, abort on it, or skip it silently. Nobody
decided that; it accumulated. This section decides it.

## Shapes and counting terms

Two shapes exist and are bound differently:

- A **multi-target harness** accepts one or more targets, scores each, and
  computes its exit status from a tally at the end.
- A **single-target harness** accepts exactly one target and aborts on a target
  it cannot use.

A row is **scored** only when it reached a verdict of pass or fail. A harness's
**scored total** is its passed count plus its failed count. A target reported
unscoreable counts as one **synthetic failed row** and therefore toward the
scored total — the harness did determine something, namely that this target
cannot be certified, so the run is red on its merits rather than on the
backstop. An inconclusive row
MUST NOT count toward the scored total: a harness reports a row inconclusive
precisely when it could not determine the answer, and counting it as evidence
gathered would turn "I could not tell" into "I checked".

## Requirements

A conformance harness in this repository:

- **MUST NOT** exit 0 when its scored total is zero, irrespective of the route
  by which that happened. `0 passed, 0 failed` is not a passing result; it is
  the absence of a result. A single-target harness satisfies this by aborting
  non-zero before any row runs and is not required to grow a tally.
- **MUST** treat inability to score an **explicitly named** target as a failure
  and exit non-zero. Naming a target is the caller asserting it should be
  there; downgrading that to "nothing to say" converts the caller's claim into
  the harness's silence and returns a green exit the caller reads as
  confirmation. A multi-target harness records the failure and continues to its
  remaining targets; a single-target harness aborts with a message naming the
  target and the reason.
- **MUST** treat a target as unscoreable when it does not exist, OR is not a
  regular file, OR is empty, OR is not readable, testing each independently and
  naming which held. Precedence is fixed — not-found, not-a-regular-file,
  empty, unreadable — so the report is reproducible across platforms whose
  `test` builtins short-circuit differently. A dangling symlink is reported as
  not-a-regular-file rather than not-found, since something is present at the
  path.
- **MUST NOT** test the executable bit. Targets are invoked as `bash <path>`,
  which requires read and not execute permission, so a readable
  non-executable script is fully scoreable.
- **MUST** report a target it could not score distinguishably from one it
  scored and found non-conformant. Both make the run red and they call for
  different responses.
- **MUST** render control characters and newlines in any echoed target path
  inert. A path is attacker-influenceable in the general case, and output that
  can be forged with an embedded newline can be made to print a line that reads
  like a PASS.

A harness offering a roster (`--family`) mode additionally:

- **MUST** report how many roster entries it scored out of how many it knows
  about, and name every entry it did not score together with the reason. The
  report is emitted on **every** roster run, complete ones included: a line
  that appears only when something is wrong becomes the signal, and its absence
  then has to be noticed to mean anything.
- **MUST** count an entry as scored only if it contributed at least one scored
  row, so a full-coverage claim is unreachable over a run that determined
  nothing.
- **MUST** identify entries by a stable logical label throughout roster output —
  the coverage line and every per-entry heading and result line — rather than a
  resolved absolute path. An absolute path differs per machine, so two complete
  sweeps produce output that cannot be diffed; it also carries `$HOME` and
  workspace roots into CI logs.
- **MUST** print its coverage report rather than a usage error when every
  roster entry is absent. The exit is non-zero either way, which is what makes
  this worth stating: an operator told their command line was malformed, when
  in fact their fleet is missing, will debug the wrong thing.
- **MUST** exit with a usage error, naming the conflict, when invoked with both
  a roster flag and explicit target paths. Silently discarding the paths is the
  same defect this section closes, reached through argument parsing.
- **MUST NOT** fail the run solely because a roster entry is absent. A host that
  stopped vendoring an artifact because it now resolves it from a pinned commit
  is conformant, and a harness that went red for it would punish the correct
  architecture and become a check nobody reads.
- **MUST NOT** maintain a list of roster entries whose absence is expected, and
  MUST NOT claim to distinguish deliberate absence from accidental. Such a list
  is state that must track architectural decisions taken in other repositories;
  it was already stale twice inside one week as two hosts moved to
  pin-and-resolve. A stale allowlist does not fail safe — it re-creates the
  silent narrowing this section closes, while looking more rigorous than the
  coverage line it replaced. Whether an absence was intended is a question for
  the reader, and the report's job is to ensure they are asked it.

## Withdrawn on 2026-08-12: the pin-and-resolve rules

Two rules stood here and are withdrawn, not relaxed. A harness **MUST** have
reported an entry whose host shipped both a resolver and a pin manifest as
resolvable-but-not-attempted; a harness offering the opt-in resolving mode
**MUST NOT** have treated the resolver's output as an arbitrary filesystem path,
and had to confine the resolve to a scratch location it owned.

Both had exactly one class of subject: a roster entry that was absent *and*
whose directory held `bin/resolve-core-artifact.sh` and
`tools/core-vendor.manifest`. Only the four host repositories could ever satisfy
that, and they were archived on 2026-08-05 and deleted on 2026-08-12. The rosters
now hold `core` and `shared-install` — a working tree and an installed file,
neither of them a host directory — so neither rule has anything left to bind.
`resolve-core-artifact.sh` was retired in the same change; core's own
`install.sh` never used it.

The confinement rule governed **executing a path chosen by a script in another
repository**, and no such act remains. If pin-and-resolve ever returns to a
roster, that rule MUST return with it and MUST NOT be reconstructed from memory:
it is recorded in full at commit `a15de90`.

`tools/drift-report.sh` was named here as out of scope — a sixth instrument with
similar SKIP semantics but advisory by contract, its exit status unconditionally
0, so it certified nothing a false green could corrupt. It was retired on
2026-08-12 with the same four repositories, which were its entire declared
subject. It is still named, for the same reason it was named before: so that a
reader meeting its SKIP semantics in the history does not file them as an
instance of the defect this section closes.

## Conformance

Demonstrable by `tools/conformance-harness-reporting.test.sh`, which scores
every harness in `tools/` against this section. That test is itself subject to
the first requirement: a run that scores nothing exits non-zero.
