# conformance-harness-reporting Specification

## Purpose
TBD - created by archiving change fix-conformance-harness-false-green. Update Purpose after archive.
## Requirements
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

### Requirement: A harness that scored nothing SHALL NOT report success

A conformance harness SHALL exit non-zero whenever it terminates with a scored
total of zero, irrespective of the reason. Success is a claim about evidence
gathered, and a harness that gathered none has no claim to make.

This is stated as a floor over the harness's whole run rather than as a
property of any one absence path, deliberately. Every defect of this class so
far — a missing file, a filtered roster, an unreadable target — reached the
same terminal condition by a different route, and each was fixed one route at a
time. A scored total of zero is the observable every route shares, so a route
nobody has thought of yet is covered on the day it appears.

`0 passed, 0 failed` is not a passing result. It is the absence of a result.

A single-target harness satisfies this requirement by aborting non-zero before
any row runs; it is not required to grow a tally to do so.

#### Scenario: Every target was unscoreable

- **WHEN** a multi-target harness finishes with a scored total of zero
- **THEN** it exits non-zero and reports on stderr that it certified nothing

#### Scenario: Only inconclusive rows ran

- **WHEN** a run's rows were all inconclusive
- **THEN** the harness exits non-zero, because its scored total is zero

#### Scenario: No target and no roster flag is given

- **WHEN** a harness is invoked with no arguments at all
- **THEN** it exits non-zero with a usage error, having scored nothing

#### Scenario: Some targets scored and all rows passed

- **WHEN** a harness has a scored total of at least one and no failed row
- **THEN** it exits zero

### Requirement: An explicitly named target that cannot be scored is a failure

When a caller names a target on the command line, a harness SHALL treat
inability to score that target as a failure and exit non-zero. It SHALL NOT
skip the target and exit zero.

Naming a target is an assertion by the caller that the target should be there.
A harness that silently downgrades that assertion to "nothing to say" converts
the caller's claim into the harness's own silence, and returns a green exit
that the caller reads as confirmation.

The two shapes discharge this differently, and both are conformant:

- A **multi-target** harness SHALL record the failure against that target in
  its tally, continue to its remaining targets, and score them in full. It
  SHALL NOT abort, because one absent target must not deny the caller the
  results for the others.
- A **single-target** harness SHALL abort with a non-zero status and a message
  naming the target and the reason.

#### Scenario: A named target does not exist

- **WHEN** a harness is invoked with a path to a file that is not present
- **THEN** it reports a failure naming that target and exits non-zero

#### Scenario: One named target of several is missing

- **WHEN** a multi-target harness is given three targets and the second is
  absent
- **THEN** it scores the first and third in full, records a failure for the
  second, and exits non-zero

### Requirement: Unscoreable is defined by three independent conditions

A target SHALL be treated as unscoreable when it does not exist, OR is not a
regular file, OR is empty, OR is not readable. The conditions SHALL be tested
independently, and the reported reason SHALL name which one held. A target that
does not exist SHALL be reported as **not found** and not as
not-a-regular-file: the two are different facts and lead an operator to
different places.

The conditions can hold together — a dangling symlink neither exists nor is a
regular file nor is readable — so the reported reason SHALL be the first that
holds in the order **not-found, not-a-regular-file, empty, unreadable**, with a
dangling symlink reported as not-a-regular-file rather than not-found, since
something is present at the path. A fixed precedence makes
the report reproducible across platforms whose `test` builtins short-circuit
differently, and puts the most structural explanation first.

A harness SHALL NOT test for the executable bit. Targets are invoked as
`bash <path>`, which requires read permission and not execute permission, so a
readable non-executable script is fully scoreable and rejecting it would fail a
working target. Verified: `bash` on a mode-644 script runs it and returns the
script's own exit status.

Each is a distinct real failure and no one test covers the others:

- **Not a regular file.** A directory reports a non-zero size, so an
  existence-and-size test alone accepts one.
- **Empty.** A zero-byte script exits 0 on every invocation and therefore
  passes every row that expects 0, manufacturing partial credit out of a file
  containing no code. This is what a truncated download or a half-finished
  artifact-materialisation step leaves behind.
- **Not readable.** An unreadable file is not a false-green risk — the shell
  refuses it with 126 and the rows fail loudly. It is a **legibility** failure:
  the operator is shown a target that failed forty rows when the truth is a
  file-mode problem, and will debug the wrong thing.

  This condition is a no-op when the harness runs as root, which is the default
  in many CI containers: `test -r` is true for root regardless of mode, and the
  shell reads the file anyway. The check is therefore an aid to a developer on
  a workstation and SHALL NOT be relied on as a guarantee. It is specified
  rather than dropped because that is where file-mode accidents actually
  happen, but a requirement whose enforcement silently vanishes under the
  commonest CI configuration must say so rather than imply a coverage it does
  not have.

#### Scenario: A named target is a zero-byte file

- **WHEN** a harness is invoked with a path to an empty file
- **THEN** it reports that target unscoreable for emptiness rather than scoring
  rows against it

#### Scenario: A named target is not readable

- **WHEN** a harness is invoked with a non-empty file it lacks permission to
  read
- **THEN** it reports that target unscoreable for unreadability, and does not
  report it as having failed rows

#### Scenario: A named target is a directory

- **WHEN** a harness is invoked with a path to a directory
- **THEN** it reports that target unscoreable rather than scoring rows

### Requirement: A roster sweep SHALL declare its coverage

A harness offering a `--family` (or equivalent roster) mode SHALL report how
many roster entries it scored out of how many it knows about, and SHALL name
every entry it did not score together with the reason it was not scored.

A roster entry that is absent SHALL NOT by itself fail the run. A host that has
stopped vendoring an artifact because it now resolves that artifact from a
pinned commit is conformant, and a harness that went red for it would punish
the correct architecture and become a check nobody reads. What the harness
SHALL NOT do is narrow its coverage without saying so. The failure being closed
is not "scored fewer hosts" — it is "scored fewer hosts and printed the same
success line as a full sweep".

The coverage report SHALL be emitted on every roster run, including runs where
every entry was scored. A line that appears only when something is wrong
becomes the signal, and its absence then has to be noticed to mean anything.

A roster entry SHALL count as scored only if it contributed at least one scored
row. Counting an entry as scored because the harness reached it would permit
`scored 6 of 6` over a run whose scored total is zero — the coverage line
asserting complete coverage of nothing.

Roster entries SHALL be identified throughout roster-mode output — the coverage
line and every per-entry heading and result line — by a stable logical label
rather than a resolved absolute path. The primary reason is comparability: an
absolute path differs per machine, so two runs of a complete sweep produce
output that cannot be diffed. A secondary benefit is that `$HOME` and workspace
roots stop reaching CI logs; this is stated as secondary deliberately, because
logicalising the coverage line alone would leave the existing per-entry
headings printing absolute paths and the privacy claim would be false.

Any target path a harness echoes SHALL have control characters and newlines
rendered inert. A path is attacker-influenceable in the general case, and a
harness whose output can be forged with an embedded newline can be made to
print a line that reads like a PASS.

An empty or unreadable roster entry SHALL be reported as not scored, with its
reason, exactly as an absent one is. A half-materialised cache is the commonest
way for a vendored artifact to be present and useless, and treating it as a
hard failure would make a legitimately-absent-then-partially-restored entry
noisier than a cleanly absent one for no gain in information.

#### Scenario: Part of the roster is absent

- **WHEN** a roster sweep knows six entries and two are not present on disk
- **THEN** it scores the four that are present, reports `scored 4 of 6` naming
  the two it did not score and why, and exits on the merits of the four

#### Scenario: The whole roster is present

- **WHEN** every roster entry is present and every row passes
- **THEN** the harness still reports `scored 6 of 6` and exits zero

#### Scenario: The whole roster is absent

- **WHEN** no roster entry is present on disk
- **THEN** the harness prints its coverage line reporting `scored 0 of M` and
  naming every entry with its reason, then exits non-zero because its scored
  total is zero — and NOT with a usage error

Stated as an explicit prohibition because the current builders reach the
usage-error path here: they filter absent entries out of the argument list
before it is checked, so a fully-absent roster collapses to zero arguments and
is reported as though the operator had invoked the tool wrongly. The exit code
is non-zero either way, which is what makes this worth pinning — an
implementation that kept the usage error would satisfy a requirement written
only about exit codes, while telling the operator their command line was
malformed when in fact their fleet was missing.

#### Scenario: A roster entry is present but empty

- **WHEN** a roster entry exists as a zero-byte file
- **THEN** it is reported as not scored with emptiness as the reason, and does
  not by itself fail the run

### Requirement: Roster mode and explicit targets SHALL NOT be combined silently

A harness invoked with both a roster flag and explicit target paths SHALL exit
with a usage error naming the conflict. It SHALL NOT silently discard either.

The current roster builders discard every other argument when the roster flag
is seen, so `--family extra-gate.sh` scores the roster and says nothing about
`extra-gate.sh`. That is the same defect as the one this capability closes — a
caller's named target dropped without a word — reached through argument parsing
instead of a file check.

#### Scenario: Both a roster flag and a path are given

- **WHEN** a harness is invoked with a roster flag and one or more explicit
  target paths
- **THEN** it exits with a usage error naming the conflict and scores nothing

### Requirement: The distinction between an absent target and a failing target SHALL be legible

A harness SHALL report a target it could not score distinguishably from a
target it scored and found non-conformant. Both make the run red; they call for
different responses, and an operator who cannot tell them apart will debug the
wrong one.

#### Scenario: An operator reads a red run

- **WHEN** a run contains both an unscoreable target and a target that failed
  rows
- **THEN** the output states which target could not be scored and for which
  reason, and which target failed which rows

### Requirement: Deliberate and accidental roster absence are NOT distinguished

A harness SHALL NOT claim to distinguish a roster entry that is absent by
design from one that is absent by accident, and SHALL NOT maintain a list of
entries whose absence is expected.

This is recorded as a requirement rather than left unsaid because the
alternative is attractive and wrong. An "expected absent" allowlist is state
that must be updated in lockstep with architectural decisions taken in five
other repositories; it was already stale twice within one week as
`claude-workflow` and then `codex-workflow` moved to pin-and-resolve. A stale
allowlist does not fail safe — it re-creates precisely the silent narrowing
this capability exists to close, while carrying the appearance of rigour.

The coverage report names what was not scored and why it could not be scored
from the filesystem's evidence alone. Whether that absence was intended is a
question for the person reading the report, and the report's job is to make
sure they are asked it.

#### Scenario: An artifact is deleted by mistake

- **WHEN** a roster entry is absent because someone deleted it in error
- **THEN** the harness reports it as not scored with the same reason it would
  give for a deliberate removal, and the run's coverage line shows the reduced
  count

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

