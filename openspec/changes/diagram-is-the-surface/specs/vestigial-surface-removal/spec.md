## ADDED Requirements

### Requirement: This capability governs shipped enforcement and interface surface only

This capability SHALL apply only to **shipped enforcement and interface
artifacts**: executables that gate, block, or permit an action; environment
variables and flags that alter their behaviour; and published copies of either.

**Deletion** SHALL NOT reach records, tests, tooling, or authored prose.
Specifically exempt from deletion: `adrs/`, `openspec/`, `CHANGELOG.md`, `docs/`,
`prompts/`, `tools/`, `spec/`, and every test harness.

**Correction** reaches further than deletion, and the two must not be conflated.
A statement instructing an operator to use a removed interface SHALL be corrected
wherever it appears, including inside an exempt file. Correcting a sentence in
`docs/` is not deleting `docs/`.

*An earlier revision put "the documentation that instructs an operator to use
them" inside the governed class while simultaneously exempting every file such
documentation lives in, so the same artifact was both required and forbidden.
Separating the deletion scope from the correction scope is what resolves it —
the exemption was always about not deleting records, never about leaving false
instructions standing in them.*

**An earlier revision stated the rule over all artifacts** — *"an artifact SHALL
belong in this repository only if it appears on the diagram or is required to
make a step on it work"* — and three reviewers independently observed that this
literally condemns `adrs/`, `tools/`, `docs/`, `publish/`, `prompts/` and
`CHANGELOG.md`, none of which are drawn and none of which make a step run. It
also contradicted this capability's own requirement that decision records be
retained. A rule that mandates deleting most of the repository is not a strict
rule; it is an unusable one, and it would have been read down to whatever its
author happened to intend.

#### Scenario: An artifact is a record rather than an interface

- **WHEN** an artifact is a decision record, an archived change, a changelog
  entry, a test, or authored documentation
- **THEN** it SHALL NOT be deleted by this capability, whatever the diagram shows

#### Scenario: A record contains an instruction to use a removed interface

- **WHEN** an exempt file contains a statement telling an operator to set a flag
  or run an executable that this capability removed
- **THEN** that statement SHALL be corrected in place, and the file SHALL NOT be
  deleted

#### Scenario: An artifact gates an action

- **WHEN** an artifact can block, permit, or alter the outcome of an operation, or
  documents how to make it do so
- **THEN** this capability SHALL apply to it

#### Scenario: The class is unclear

- **WHEN** it cannot be determined whether an artifact is enforcement surface or a
  record
- **THEN** it SHALL be treated as a record and retained, because the cost of
  keeping a dead file is bounded and the cost of deleting a reason is not

### Requirement: A vestigial enforcement artifact is removed, not annotated

An enforcement or interface artifact whose behaviour has been withdrawn SHALL be
removed. It SHALL NOT be retained alongside a comment recording that it no longer
does anything.

Retention with an explanatory comment is the failure mode this exists to prevent.
It reads as deliberate, so nobody removes it; and the comment is not visible at
the point of use, so the artifact continues to be reached for on the strength of
its name. `GSD_SKIP_REVIEWS` is the worked example: named as an escape hatch,
documented as one in twenty files, recommended as one by `run-plan-review.sh` at
a failure path, and escaping nothing since gate 2.0.0.

#### Scenario: A flag no longer changes any blocking outcome

- **WHEN** an environment variable's every remaining effect is on what is
  reported rather than on what is permitted, **and** its documented purpose is to
  alter what is permitted
- **THEN** it SHALL be removed from the interface, not retained as inert

#### Scenario: A reporting control is not thereby vestigial

- **WHEN** a variable's purpose is and always was to govern verbosity, log
  destination, or diagnostic output
- **THEN** it SHALL NOT be removed by this requirement, which reaches only
  controls whose stated purpose has been withdrawn

#### Scenario: A failure path recommends the artifact

- **WHEN** any shipped code path advises an operator to set a variable being
  removed
- **THEN** that recommendation SHALL be removed with it, because advice at a
  failure point is where an operator is most likely to follow it

### Requirement: A published copy may not contradict what it publishes

Where this repository publishes a copy of an enforcement artifact, that copy SHALL
match the implementation it publishes, or SHALL be removed. A published copy that
nothing resolves SHALL be removed rather than corrected.

`gate/openspec-change-gate.sh` is the worked example. It defaults
`MIN_REVIEWERS=2`, returns a blocking exit on insufficient reviewers, and treats
`GSD_SKIP_REVIEWS` as a live bypass of that live block, with `gate/README.md`
documenting it as contract. Nothing resolves it — `resolve-core-artifact.sh` maps
the shared install to the reference implementation, and the installed copy is
byte-identical to that. So it enforces nothing and misinforms everyone.

#### Scenario: A published copy is stale and unresolved

- **WHEN** a published copy of an enforcement artifact is resolved by no
  installer, tool, or hook, and states behaviour the implementation no longer has
- **THEN** it SHALL be removed rather than updated, because a copy that nothing
  reads has no reader to serve

#### Scenario: A published copy is live

- **WHEN** an installer or hook does resolve a published copy
- **THEN** it SHALL be kept synchronised with the implementation, and the
  resolution path SHALL be recorded so the question is answerable without a sweep

### Requirement: A removal reaches the installed copy, not only the source

Removing a shipped enforcement artifact SHALL remove every installed copy of it
in the same change. A removal that deletes the source while an installed copy
survives in the shared install directory SHALL NOT be recorded as complete.

This is the failure mode this capability exists to name, found inside this very
change. `reference-implementations/project-hooks/database-sentinel.sh` was
scheduled for deletion while `~/.agenticapps/bin/database-sentinel.sh` — the copy
the shims actually invoke — was not, so the hook would have kept running with its
source gone. Measured on the same directory:
`~/.agenticapps/bin/normalize-claude-md.sh` is **still installed** after PR #87
retired it, which is the same defect one removal earlier and nothing detected it.

#### Scenario: An installed copy outlives the implementation it was removed from

- **WHEN** an enforcement artifact is deleted from this repository and a copy of
  it exists in the shared install directory
- **THEN** the installed copy SHALL be removed in the same change, because an
  artifact deleted from source but surviving where it executes has not been
  removed

#### Scenario: The shared install directory is enumerated at removal time

- **WHEN** any enforcement artifact is removed
- **THEN** the shared install directory SHALL be listed and compared against what
  the repository still publishes, and every orphan SHALL be reported

#### Scenario: An orphan predates this change

- **WHEN** the comparison finds an installed artifact whose source was removed by
  an earlier change
- **THEN** it SHALL be reported rather than silently swept, because it is evidence
  the earlier removal was recorded complete when it was not

### Requirement: Retention on compatibility grounds is evidenced

Where an artifact is retained because existing configuration depends on it, that
dependency SHALL be named — the file, the setting, or the caller. A retention
SHALL NOT rest on the possibility of an unobserved consumer.

Where the search for such a dependency is bounded by what is observable, the
removal SHALL state that bound rather than assert that none exists.

#### Scenario: A compatibility claim is made

- **WHEN** an artifact's retention is justified by existing configuration
- **THEN** that configuration SHALL be located and named, and the artifact SHALL
  be removed if it cannot be

#### Scenario: Consumers outside the searched scope may exist

- **WHEN** the search covers only this machine or this fleet, and other consumers
  are possible but unobservable
- **THEN** the removal SHALL record what was searched and what was not, and SHALL
  NOT claim that no consumer exists

### Requirement: An implementation's own documentation states its behaviour

Where an implementation documents its own interface, that documentation SHALL
describe what the implementation does. A description that overstates enforcement
SHALL be treated as a defect of the same kind as an incorrect enforcement.

The gate's header documents `MIN_REVIEWERS` as a "blocking floor (spec 1.1.0
MUST)". Five lines below, the code that reads it is commented `REPORTED, NOT
BLOCKED` and only selects which NOTE is printed. Both ship in one file, and the
wrong one is the one a reader meets first.

#### Scenario: A header contradicts the code beneath it

- **WHEN** an implementation's own comments describe a threshold as blocking and
  the code applies it only to reporting
- **THEN** the documentation SHALL be corrected to match the code

#### Scenario: A withdrawn enforcement is described as live

- **WHEN** any shipped text states a condition blocks that has not blocked since
  a released version
- **THEN** that text SHALL be corrected and the version at which the behaviour
  changed SHALL be named

### Requirement: The diagram and the specification are reconciled, not overwritten

`workflow.mmd` is the drawn specification of the loop. Where it disagrees with the
implementation, the disagreement SHALL be resolved against the normative
requirements and the recorded decisions — not by editing the diagram to match
whatever the code currently does.

**An earlier revision said the diagram SHALL be corrected to match the
implementation.** That reverses spec-first authority: the implementation is as
likely to be the defect, and a diagram that automatically yields to code is not a
specification. In this change both diagram statements are wrong because ADR-0027
and `change-gate-enforcement` withdrew the enforcement they describe — the
decision is the authority, and the diagram is stale against it.

#### Scenario: The diagram states a rule the implementation does not enforce

- **WHEN** the diagram and the implementation disagree
- **THEN** the normative requirement and its decision record SHALL be consulted,
  and whichever of the two contradicts them SHALL be corrected

#### Scenario: The decision record supports the diagram

- **WHEN** the diagram matches a recorded decision and the implementation does not
- **THEN** the implementation SHALL be treated as the defect

### Requirement: Removal preserves the record of the decision

Removing an artifact SHALL NOT remove the record of why it existed or why it went.
Decision records, archived changes, and the changelog SHALL be retained unedited.

Deleting the reasoning is not minimizing; it is discarding the only defence
against reintroducing the artifact.

#### Scenario: An artifact removed here is recorded in an ADR

- **WHEN** an artifact being removed is the subject of a decision record
- **THEN** the ADR SHALL be left unedited, and the removal SHALL be recorded by a
  new ADR rather than by amending the old one

#### Scenario: A reader asks why a removed thing existed

- **WHEN** a reader looks for the reasoning behind an artifact removed by this
  change
- **THEN** the archived change, the ADR, and the changelog entry SHALL still
  answer, without reference to the removed artifact itself
