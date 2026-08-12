## REMOVED Requirements

### Requirement: A roster entry resolvable from a pin SHALL be reported as such

**Reason**: The requirement governs how a harness reports a roster entry that is
absent *because its host vendors nothing and resolves the artifact from a pinned
commit*. It fires only for an entry that is absent **and** whose host directory
holds both `bin/resolve-core-artifact.sh` and `tools/core-vendor.manifest`. Every
roster entry that could ever satisfy that conjunction was one of the four host
repositories, and this change removes all four from both rosters — the four
checkouts were deleted on 2026-08-12 and their remotes archived on 2026-08-05.

The two entries that remain cannot reach it by construction, not by accident.
`core` is this repository's own working-tree reference implementation, which is
present whenever the harness itself is; `shared-install` is the copy
`install.sh` publishes into `~/.agenticapps/bin/`, which is a plain installed
file with no resolver and no manifest beside it. Neither is a host directory, so
neither has the shape the branch tests for.

Measured 2026-08-12 before removal: no `core-vendor.manifest` and no
`resolve-core-artifact.sh` exists anywhere under `~/Sourcecode` outside this
repository. There is no pin-and-resolve consumer on the machine.

A SHALL that nothing can reach is worse than no rule. It cannot be violated, so
it never fails; it cannot be satisfied, so conformance to it is unobservable;
and it goes on describing an instrument's behaviour to every reader who does not
independently discover that the branch is dead. That is the condition
`vestigial-surface-removal` names — retention on the strength of a name — applied
to prose rather than to a flag.

The substantive claim survives where it still has a subject. **"Not vendored"
and "unscoreable" are different facts** was the argument, and the requirement
that carries it forward is *Deliberate and accidental roster absence are NOT
distinguished*, which remains in force: a harness must still not claim to know
*why* an entry is missing. What is withdrawn is the one exception to that — the
single case where the harness could read a host's resolver and manifest and say
so.

**Migration**: The `--resolve` flag on `change-gate-conformance.sh` is removed
with the requirement, as is the resolvable-but-not-attempted reason string in
both `change-gate-conformance.sh` and `reviewer-cli-conformance.sh`. An entry
absent for any reason is now reported as not scored with its screening reason,
under the requirements that already govern absence. No host, template, installer
or project reads `--resolve`; the sweep for callers found none outside this
repository's own test suite, where assertion J3 of
`tools/conformance-harness-reporting.test.sh` is removed alongside it.

The security rules that constrained the resolve — that it run into a scratch
directory the harness owns, that the returned path be rejected unless it lands
inside it, and that cleanup remove the harness's own location rather than one
the resolver chose — are removed with the capability they constrained. They
governed the act of executing a path chosen by a script in another repository,
and no such act remains. Should pin-and-resolve ever return to a roster, those
constraints must return with it and SHALL NOT be reconstructed from memory:
`spec/20-conformance-harness-reporting.md` at commit `a15de90` carries them in
full, and this block is the pointer to that.

## MODIFIED Requirements

### Requirement: Harness shapes and counting terms are defined

This capability governs the conformance harnesses in core's `tools/`, which
measure host implementations of the gate, the producer and the reviewer
wrapper. It does not govern host implementations themselves, and satisfying it
forms no part of any host's conformance claim.

It therefore ships as a section of type `core-tooling-contract`, not
`declarative-contract`. §00 states that host requirements "live in the
canonical-prose and declarative-contract sections"; a declarative contract that
no host is expected to satisfy would make that sentence false, and would
present hosts with a section they must read to discover it does not apply to
them.

`tools/drift-report.sh` was the sixth instrument and is **retired**, deleted on
2026-08-12 with `tools/drift-report.test.sh`. It compared canonical-prose blocks
in `spec/` against the instruction files of host clones, and its `HOSTS` array
declared exactly the four host repositories whose checkouts were deleted the same
day. Its last run scored `OK: 0 · DRIFT: 0 · SKIP: 60` — it had no subject left,
and nothing in this repository invoked it. It is named here, still, for the
reason it was named here before: so that the next reader who meets its SKIP
semantics in the git history does not file them as an instance of the false-green
defect this capability exists to close. Its exit code was unconditionally 0, so
it certified nothing and could corrupt nothing.

Two shapes exist and are treated differently throughout:

- A **multi-target harness** accepts one or more targets, scores each, and
  computes its exit code from a tally at the end. `change-gate-conformance.sh`,
  `run-plan-review-conformance.sh` and `reviewer-cli-conformance.sh` are of
  this shape.
- A **single-target harness** accepts exactly one target and aborts on a target
  it cannot use. `shared-install-conformance.sh` is of this shape.
  `resolve-core-artifact-conformance.sh` was the other and is retired, with the
  published `resolve-core-artifact.sh` it scored.

**What a roster sweep proves changed with the fleet, and the harnesses SHALL NOT
overstate it.** With the four host repositories retired, `--family` scores
`core` — this repository's working-tree reference implementation — and
`shared-install`, the copy `install.sh` publishes to `~/.agenticapps/bin/`. That
is a real and continuing measurement, and it is **publish drift**: whether the
bytes this repository ships are the bytes an installed machine runs. It is not
coverage of a fleet of independent implementations, because after 2026-08-12
there are none. A sweep SHALL NOT present its coverage line as evidence about
host implementations, and the flag name `--family` is retained for its callers
rather than as a claim about what is scored.

A harness SHALL treat a row as **scored** only when that row reached a verdict
of pass or fail, and SHALL compute its **scored total** as its passed count
plus its failed count.

A target reported unscoreable under the requirements below SHALL count as one
**synthetic failed row**, and therefore toward the scored total. Without this
the two rules contradict: a named target that cannot be scored is required to
be a counted failure, while a run consisting only of such targets would have a
scored total of zero and would be indistinguishable from a run that did
nothing. It is a real determination — the harness established that this target
cannot be certified — so it is evidence, and the run is red on its merits
rather than on the backstop.

An inconclusive row SHALL NOT count toward the scored total. A harness reports
a row inconclusive precisely when it could not determine the answer, and
counting it as evidence gathered would turn "I could not tell" into "I
checked".

#### Scenario: A run reaches only inconclusive verdicts

- **WHEN** a run ends `0 passed, 0 failed, 5 inconclusive`
- **THEN** its scored total is zero

## ADDED Requirements

### Requirement: A roster declares only targets that can exist

A **roster** is any list of targets declared in this repository and read by an
instrument that reports on them — `--family` in the conformance harnesses,
`FLEET` and `SHIMMED-HOOKS` in `reference-implementations/project-hooks/`, and
any future list of the same shape. A roster SHALL NOT declare a target whose
subject has been retired. When a repository or artifact is retired, every roster
naming it SHALL be trimmed in the same act, and the removal SHALL be recorded in
the roster itself as a dated comment naming what left and when.

The rule is stated over **targets**, not repositories, because a roster entry is
not always one. After this change the two conformance rosters hold `core` — this
repository's working-tree reference implementation — and `shared-install`, the
copy `install.sh` publishes to `~/.agenticapps/bin/`. Neither is a repository,
and a rule phrased over repositories would not reach the entries that remain
while claiming to govern them.

A roster is a declaration, and its whole value is that a member missing from the
set is detectable. A member that cannot exist inverts that: it produces the same
absence on every run forever, which is indistinguishable in the output from a
member that is temporarily uncloned and materially different in what it means.
Read enough times, a permanent absence trains the operator to discount the
absence line — and the next real gap arrives on a surface that has already
taught its reader to look past it.

This does **not** reintroduce a rule that absence fails a run. Absence remains
non-fatal under the requirement that governs it, and a harness still SHALL NOT
claim to distinguish deliberate absence from accidental. The obligation here is
on the *declaration*, discharged when the roster is edited, not on the harness at
run time — an instrument cannot tell a retired target from an uncloned one, which
is precisely why the roster has to.

The dated comment is required because a bare deletion leaves the next reader
unable to tell a retirement from an accident, and the diff that would answer it
is the one place nobody looks. `reference-implementations/project-hooks/FLEET`
sets the form.

#### Scenario: A target is retired while rosters name it

- **WHEN** a repository or published artifact is retired and one or more rosters
  in this repository declare it
- **THEN** every roster naming it is trimmed in the same change, each keeping a
  dated comment naming the removed target

#### Scenario: A declared target is merely not present

- **WHEN** a roster declares a target that still exists but is not present on
  this machine
- **THEN** it stays declared and is reported as absent, because that absence is
  the finding the declaration exists to produce

#### Scenario: Trimming would empty a roster

- **WHEN** trimming would leave a roster with no entry that can exist
- **THEN** the roster is trimmed regardless, and whether the instrument reading
  it is retired is decided under `vestigial-surface-removal` — which requires
  that the instrument have no remaining subject through any other input, an
  empty roster alone being insufficient
