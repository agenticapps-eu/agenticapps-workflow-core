## ADDED Requirements

### Requirement: A non-zero exit always carries a message

A shim SHALL NOT exit non-zero having written nothing to stderr. The exit code
and the message are one signal, not two: this capability requires a non-blocking
error code **because** it is the only thing that surfaces stderr to the operator,
so an exit code with no accompanying line invokes the mechanism and supplies
none of its content.

**This binds the shim's own exits, before `exec`, and no others.** Once a shim
`exec`s, the process is the implementation and its exit code is the
implementation's to choose; a shim that tried to constrain it would have to stop
`exec`ing and start wrapping, which the behaviour-free rule forbids. A stderr
write that itself fails is likewise outside the rule — the shim SHALL attempt the
line, not guarantee its delivery through a broken descriptor.

**It binds an event class only where that class's channel is verified.** This
capability records a verified warning channel for `PreToolUse` and requires the
exit rule to "be re-established per event class, not assumed to generalise". The
invariant is argued from `PreToolUse` rendering — a non-zero exit surfacing the
first stderr line — so it is claimed for `PreToolUse` and for any class whose
channel is later verified and recorded. For a class whose channel is unverified,
`normalize-claude-md`'s `PostToolUse` being the live instance, a shim SHALL still
write its line before exiting non-zero, and no report SHALL claim the operator
sees it. Writing the line costs nothing and is what makes the claim available the
day the channel is verified; claiming the operator was warned is what this
capability forbids.

The host renders such a call as `hook error — No stderr output`. That notice
costs the operator exactly what a real report costs — it interrupts, it names a
hook, it implies something is wrong — and returns nothing they can act on. It is
strictly worse than either alternative: worse than reporting, which at least
says what broke, and worse than silence, which at least does not interrupt.

This is stated as an invariant rather than as a fix to one code path because it
binds every future report a shim learns to make, including ones whose rate
limit, filter or guard has not been written yet. The rule is: **whatever
suppresses a report SHALL also be asked what the exit code should be**, and the
answer SHALL NOT be "leave it non-zero and say nothing".

#### Scenario: A report is suppressed but the call still fails to resolve

- **WHEN** a shim's repetition policy suppresses the full report for a call whose
  implementation is still unresolvable
- **THEN** the shim writes at least one line to stderr before exiting non-zero,
  so the operator sees a notice that names the hook and its state rather than an
  empty one

#### Scenario: A shim is audited for contentless exits

- **WHEN** a shim's pre-`exec` exit paths are enumerated
- **THEN** every path that exits non-zero is shown to write at least one stderr
  line first

#### Scenario: An exit path has nothing to say

- **WHEN** a pre-`exec` path would exit non-zero with nothing to report
- **THEN** it exits 0 **only if** it carries no announcement obligation — a path
  that fails open and loses protection SHALL be given a message rather than a
  zero exit, because exit 0 discards stderr entirely and converts the announced
  fail-open into the silent one this capability rejects

#### Scenario: The class's channel is not verified

- **WHEN** a shim binds an event class for which no warning channel is recorded
- **THEN** it writes its line and exits by the contract anyway, and every report
  of it says the channel is unestablished rather than that the operator was
  warned

### Requirement: A rate limit governs verbosity, not the operator's notice

A repetition policy of **once per interval** SHALL reduce what a suppressed
report says, not whether it says anything. On a call inside the suppression
window the shim SHALL emit a single line naming the hook and its unchanged
state, and SHALL retain the exit code the unsuppressed report would have used.

The reason is that the two halves of the report are not equally suppressible. The
message can be shortened at no cost to the guarantee; the exit code cannot be
withheld without converting an *announced* fail-open into a silent one, which is
the posture this capability rejected when it rejected fail-closed. A policy
written as though both were suppressible produces neither outcome: it suppresses
the half that carries meaning and keeps the half that carries only interruption.

**The saving a once-per-interval policy actually delivers is therefore verbosity,
and it SHALL be described as that.** It does not reduce how often the operator is
interrupted, because the exit code interrupts on every matched call regardless.
An interval policy that claims to reduce frequency is claiming a saving the exit
code takes back.

A shim MAY still choose **per invocation** and repeat the full report. What it
SHALL NOT do is claim an interval policy and deliver a contentless notice for the
rest of the interval.

**The suppressed line SHALL carry four things**, so that "a line was written" is
not discharged by a line that says nothing: the hook's name, that the condition
is unchanged, that the call was allowed, and a reference to the full notice
already made. A suppressed line that merely repeats the first line of the full
report is non-conformant — the operator could not then tell a repeat from a fresh
failure, which is the one fact the suppressed line exists to add.

**The interval SHALL be described in the units the marker actually keeps.** A
marker holding `epoch/3600` is a wall-clock **hour bucket**, not a rolling hour:
two calls four seconds apart can fall in different buckets and both report in
full. The suppressed line SHALL therefore say *this hour* rather than imply a
rolling window, and any documentation of the policy SHALL do the same.

**The report SHALL be emitted before the marker is written**, so that a failure
between the two leaves the next call reporting in full rather than claiming a
notice nobody received. Ordering it the other way makes the suppressed line's
reference to an earlier notice a claim the shim cannot support.

**A marker that cannot be written SHALL NOT suppress anything.** If the state
directory or the marker file cannot be created, every matched call reports in
full. The failure is loud rather than silent because an unwritable marker means
the shim has no memory at all, and a policy that silently degrades to suppression
would suppress on the basis of a state it never recorded.

#### Scenario: A second unresolvable call arrives within the interval

- **WHEN** a shim reported in full earlier this hour and matches another call
  whose implementation is still unresolvable
- **THEN** it emits one line naming the hook, stating that the condition is
  unchanged and that the call was allowed, referring to the full notice already
  made, and exits with the same non-blocking code

#### Scenario: The marker cannot be written

- **WHEN** the state directory or marker file cannot be created
- **THEN** every matched call reports in full, rather than the policy degrading
  to suppression on the basis of a state that was never recorded

#### Scenario: An interval policy is described in a report or document

- **WHEN** the effect of a once-per-interval policy is stated
- **THEN** it is stated as a reduction in verbosity, not in how often the
  operator is interrupted, because the exit code is not subject to the interval

### Requirement: The authority's own binder is scored, never assumed

A fleet check that excludes the authority repository SHALL NOT be cited as
evidence that the authority conforms. `--fleet` resolves the declared binders and
deliberately omits core, because comparing the template against itself would
score nothing — a correct exclusion that becomes a false clearance the moment a
change reports "the fleet is clean" and means "every repo except the one holding
the authority".

A contract change SHALL therefore score the self-hosting binder explicitly, by
naming it, and SHALL report its version and conformance beside the fleet's rather
than inside a total that structurally cannot contain it.

**This is not hypothetical.** At contract 1.1.0 the authority repo's own binder
failed open by printing a warning to stderr and exiting **0** — the exact
construction this capability names as warning nobody, since a `PreToolUse` hook
exiting 0 has its stderr discarded. It sat in the repository that publishes the
rule, and no run of the instrument could report it, because the instrument
excludes core by design and the change that would have caught it accepted a
fleet-wide zero as proof.

#### Scenario: A contract change reports its propagation

- **WHEN** a change states that every binder has been reached
- **THEN** the self-hosting binder is named with its version and conformance
  alongside the declared fleet, and a fleet-scoped zero is never presented as
  covering it

#### Scenario: The authority's binder violates a rule the authority publishes

- **WHEN** the self-hosting binder is scored against the fail-open-and-report rule
- **THEN** it is held to that rule exactly as a published-resolution shim is, its
  exemption reaching only the resolution-order clauses, and a violation is a
  finding rather than a profile difference

## MODIFIED Requirements

### Requirement: The shim contract itself has a propagation path

A shim is duplicated across every project that binds the hook, so a change to
the **shim contract** — resolution order, exit behaviour, identification,
reporting — is a change to N files, not one. Such a change SHALL name the
projects it must reach and SHALL be verified per project.

The one-authoritative-place rule covers implementations, not shims: shims are
deliberately copies, which is what makes them cheap and what makes a contract
change a fleet-wide edit. This change is itself an instance — it edits the
change-gate shim in the seven projects **and** in core, which gained its own
copy on 2026-08-02. Core's copy resolves its working-tree reference
implementation rather than the published one (ADR-0028's deliberate inversion),
which is the **self-hosting** profile defined two requirements below: the
resolution-order clauses do not reach it, while the version marker, the
behaviour-free rule and the fail-open-and-report rule do. Eight files, not
seven, and the count is not uniform in what it owes — which is why this
requirement says a contract change SHALL name the projects it must reach rather
than assume the set.

A contract change SHALL also name **which profile each binder implements**, for
the same reason it names the binders: a change that reaches all eight files and
applies one profile's clauses to both has not been verified, it has been
assumed uniform.

A shim SHALL carry a version marker for the contract it implements, so a project
running an older shim is detectable rather than discovered when it behaves
differently from its siblings.

**A marker alone does not make anything detectable, and the previous revision
stopped at the marker.** A reviewer noted that it defined no format, no
authoritative expected value, no comparison procedure and no check — so nothing
could ever read a marker and conclude "this project is stale". All four are
specified:

- **Format** — a comment line `# shim-contract: <major>.<minor>.<patch>` within
  the shim's first 10 lines, semver, matching `^[0-9]+\.[0-9]+\.[0-9]+$`. Same
  shape and placement convention as the gate's `# gate-version:` marker, so one
  reading rule covers both.
- **Authority** — the expected version is the one recorded in the shim template
  under `reference-implementations/project-hooks/`. The template in core is the
  authority; a shim in a project is a copy that either matches it or is stale.
  No project-local file is authoritative for its own conformance.
- **Comparison** — a shim is **current** when its marker equals the template's,
  **stale** when it is lower, and **unrecognised** when it is absent, malformed
  or higher than the template's. Higher is not "newer and fine": it means the
  project carries a shim the tracked template cannot account for, which is the
  drift this marker exists to surface.
- **Check** — a conformance tool SHALL enumerate every project binding a shimmed
  hook, read each marker, and report each project's state. The marker's purpose
  is discharged by that report existing, not by the marker being present.

Bumping the contract version SHALL accompany any change to resolution order,
exit behaviour, identification or **reporting** — the same four things this
requirement's first paragraph calls a contract change.

**Reporting was added to that list by an instance, not by symmetry.** A change
altering what every shim writes when its report is suppressed touched none of
the other three: resolution order, exit codes and identification were all
byte-unchanged. Under the previous wording no bump was owed, so every deployed
shim would have differed from the template in what it says with no marker
difference to surface it — the blindness the marker exists to remove, reached
through the marker's own rule.

**A shim's behaviour is not confined to what it hands over to; what it says is
part of the contract**, because the report is the whole of what an unresolvable
shim delivers. On a machine where resolution fails, the message is the only
output the operator ever sees from that hook.

#### Scenario: The shim contract changes

- **WHEN** the resolution order, exit behaviour or reporting required of shims is
  revised
- **THEN** every project binding an affected hook is enumerated and updated, and
  each is verified rather than assumed to have been reached

#### Scenario: Only what shims say is changed

- **WHEN** a change alters a shim's report while leaving resolution order, exit
  codes and identification untouched
- **THEN** the contract version is bumped and the change propagates like any
  other contract change, rather than being treated as a documentation edit
  because no resolution or exit path moved

#### Scenario: The binders are enumerated from a declaration

- **WHEN** a contract change names the projects it must reach
- **THEN** the set comes from the declared fleet rather than from the projects
  the change happened to notice, because a binder omitted from an ad-hoc list is
  indistinguishable from one that passed

#### Scenario: A project carries a shim from before a contract change

- **WHEN** the conformance check reads a shim whose marker is lower than the
  template's
- **THEN** that project is reported stale by name, rather than the discrepancy
  surfacing later as one repo behaving unlike its siblings

#### Scenario: A shim carries no marker or a malformed one

- **WHEN** a shim has no `# shim-contract:` line in its first 10 lines, or one
  that is not semver
- **THEN** it is reported unrecognised — it is not treated as current by default,
  because an unmarked shim is exactly the pre-marker shim the check exists to find

#### Scenario: A shim's marker is higher than the template's

- **WHEN** a project's marker exceeds the version recorded in core's template
- **THEN** it is reported unrecognised rather than passed as up-to-date, because
  the tracked template is the authority and cannot account for that version
