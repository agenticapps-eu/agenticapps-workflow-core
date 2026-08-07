## ADDED Requirements

### Requirement: The gate carries no review escape hatch

The gate SHALL NOT read `GSD_SKIP_REVIEWS`, and SHALL NOT provide any other
environment variable whose purpose is to suppress or bypass the review report.
After this change the name SHALL be absent from the gate's source: it is not
read, not defaulted, and not named in its documentation.

A hatch made sense while reviews blocked. Since 2.0.0 they do not, so there is
nothing to escape and the variable's only remaining effect is to hide the NOTE
lines — reviewer count, verdicts, independence, and the names of objectors. That
inverts its stated purpose: it is presented as a way to proceed despite missing
evidence, and it operates as a way to not be shown evidence that is present.

Removing it is not a loss of control. The operator retains the decision the hatch
appeared to offer, because nothing blocks: the gate reports, and the operator
proceeds or does not.

**On not specifying behaviour-when-set.** An earlier revision required the gate to
"behave as if unset" when the variable was present, and separately forbade a test
asserting exactly that. Both cannot hold: guaranteeing behaviour for a name is
keeping the name in the interface. The requirement is absence, and absence is
verified by reading the source, not by exercising a variable the gate does not
know about.

#### Scenario: The gate's source is inspected

- **WHEN** the gate implementation and its documentation are searched for
  `GSD_SKIP_REVIEWS`
- **THEN** there SHALL be no occurrence

#### Scenario: An operator wants to proceed without a review

- **WHEN** an active change carries no review, `openspec validate --all` is green,
  and the operator intends to write code anyway
- **THEN** the gate SHALL allow the edit and report the absence, requiring no flag

#### Scenario: Validation is not green and no review exists

- **WHEN** `openspec validate --all` fails and no review exists
- **THEN** the gate SHALL block, on the validation condition alone, with no
  environment variable able to alter that outcome

#### Scenario: Conformance rows assert the hatch

- **WHEN** the conformance harness or migration tests carry rows asserting hatch
  behaviour
- **THEN** those rows SHALL be removed with the hatch rather than retained
  against an interface that no longer exists

#### Scenario: A shipped code path recommends the hatch

- **WHEN** any shipped executable advises an operator to set `GSD_SKIP_REVIEWS`,
  including at a failure path where too few reviewers responded
- **THEN** that recommendation SHALL be removed, and the failure path SHALL state
  what actually follows — that reviews do not block and the operator may proceed

#### Scenario: A specification still describes the hatch

- **WHEN** `spec/18-retargeted-change-gate.md` carries a truth-table row or prose
  stating the gate keeps the hatch
- **THEN** those statements SHALL be removed, because a spec describing a removed
  interface is how the stale claim survived the last time

### Requirement: The gate documents its thresholds as what they are

The gate's own header and inline documentation SHALL describe `MIN_REVIEWERS` and
`PREFERRED_REVIEWERS` as governing what is reported. Neither SHALL be described as
blocking, as a floor that fails a surface, or as a MUST that gates an edit.

The gate currently documents `MIN_REVIEWERS` as a "blocking floor (spec 1.1.0
MUST)" and applies it, five lines later, only to select which NOTE prints — under
a comment reading `REPORTED, NOT BLOCKED`. A reader who stops at the header leaves
with the model the capability was rewritten to remove.

#### Scenario: A reader consults the gate's header

- **WHEN** a reader looks up what `MIN_REVIEWERS` does
- **THEN** the header SHALL state that it selects which NOTE is emitted, and SHALL
  NOT describe it as blocking

#### Scenario: An operator raises the threshold expecting enforcement

- **WHEN** an operator sets `MIN_REVIEWERS=2` intending to restore blocking
- **THEN** the documentation SHALL state plainly that no value of it blocks, so
  the expectation fails at the point of reading rather than at a missed block

#### Scenario: Header and code disagree

- **WHEN** the gate's documentation and the code beneath it describe different
  behaviour for the same variable
- **THEN** this SHALL be treated as a defect and the documentation corrected

### Requirement: No published copy of the gate contradicts this capability

This repository SHALL NOT ship a copy of the gate that enforces a review
threshold, or that provides an escape hatch from one. A copy that no installer,
tool, or hook resolves SHALL be removed rather than brought into line.

`gate/openspec-change-gate.sh` is such a copy. It defaults `MIN_REVIEWERS=2`,
returns a blocking exit when reviewers are insufficient, treats
`GSD_SKIP_REVIEWS=1` as a live bypass of that live block, and reports *"BLOCKED —
no code edits until validate is GREEN and every active change has >= N
reviewers"*. `gate/README.md` documents this as contract. It has been superseded
since 2.0.0 and nothing points at it: `resolve-core-artifact.sh` maps the shared
install to the reference implementation, and `~/.agenticapps/bin/` holds a
byte-identical copy of that.

#### Scenario: A published copy enforces a withdrawn threshold

- **WHEN** a shipped copy of the gate blocks on reviewer count
- **THEN** it SHALL be removed, and its removal SHALL record which installer or
  hook resolved it, or that none did

#### Scenario: A reader consults a published copy for the gate's contract

- **WHEN** a reader opens a published gate or its README to learn what blocks
- **THEN** what they find SHALL agree with the reference implementation, or SHALL
  not exist

#### Scenario: The resolution path is asserted rather than assumed

- **WHEN** a published copy is removed on the grounds that nothing resolves it
- **THEN** the resolver mapping SHALL be read and named, and the installed
  artifact compared against the implementation it claims to publish
