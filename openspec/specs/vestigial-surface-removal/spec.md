# vestigial-surface-removal Specification

## Purpose
TBD - created by archiving change diagram-is-the-surface. Update Purpose after archive.
## Requirements
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

**One artifact in `tools/` is not a record: an instrument whose declared subject
is gone.** A **record** documents what was true — a test pinning behaviour, a
changelog entry, a decision. An **instrument** measures a subject it declares,
and its declaration is what makes it an instrument rather than a script. When
every entry in an instrument's declared subject has been retired, it documents
nothing and measures nothing: it is not a record of a past measurement, it is a
present claim to be measuring something that does not exist. Such an instrument,
together with the test harness that exists only to exercise it, SHALL be retired
with its subject rather than retained under the `tools/` exemption.

Three conditions, all required, and the conjunction is what keeps this narrow:

1. the instrument **declares** its subject, in a roster or equivalent list this
   repository can read;
2. **every** entry in that declared subject has been retired, so no entry can be
   restored by cloning something that still exists; and
3. the instrument has no remaining subject through **any other input** — not a
   positional argument, not a default target, not a second roster.

Failing any one of the three, the `tools/` exemption stands and the artifact is
retained. This does not reach a tool that is merely unused, unloved, or between
subjects; "nobody runs it" is not this condition, and neither is an empty roster
on an instrument that also takes arguments.

**Where this and the record rule both describe the same file, this one governs,
and only here.** A test harness is a record *and* — when it exists solely to
exercise a qualifying instrument — part of that instrument, so the two scenarios
below would otherwise both apply and disagree. The narrower rule wins because it
is the one with conditions: a test harness escapes the record rule only by
meeting all three, and any test that does not is a record like any other. Stating
the precedence rather than leaving it to be inferred is the point — an unresolved
overlap is decided by whoever reads it, differently each time.

The tiebreaker below is unchanged and still decides genuine ambiguity toward
retention. This carve-out applies only where the three conditions are
*established by measurement and recorded*, which is a determination, not an
uncertainty — so it does not compete with the tiebreaker, which governs the case
where no determination could be reached.

#### Scenario: An artifact is a record rather than an interface

- **WHEN** an artifact is a decision record, an archived change, a changelog
  entry, a test, or authored documentation, **and** it is not a test harness
  meeting all three conditions of the scenario below
- **THEN** it SHALL NOT be deleted by this capability, whatever the diagram shows

#### Scenario: An instrument's declared subject is entirely retired

- **WHEN** an instrument in `tools/` declares its subject, every entry in that
  declared subject has been retired, and the instrument has no remaining subject
  through any other input
- **THEN** it and the test harness that exists only to exercise it SHALL be
  retired with the subject, and the three conditions SHALL be recorded as
  measured rather than asserted

#### Scenario: An instrument's roster is empty but it takes other input

- **WHEN** an instrument's roster is empty, but it also scores positional targets
  or a default target
- **THEN** the `tools/` exemption stands and it SHALL be retained, because a
  roster is one of its inputs and not its subject

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
documenting it as contract. Nothing resolves it — `install.sh` publishes the
reference implementation into `~/.agenticapps/bin/` through
`install-shared-artifact.sh`, and the installed copy is byte-identical to that.
So it enforces nothing and misinforms everyone.

*This paragraph named `resolve-core-artifact.sh` as the thing that mapped the
shared install to the reference implementation until 2026-08-12. That was never
true of core's own installer, which has always published directly; the resolver
served a **host** repository's installer, letting it publish core's artifacts
from a pin instead of vendoring their bytes. With all four host repositories
deleted it had no caller and was retired, and the sentence is corrected to name
the mechanism that actually runs. The conclusion it supports is untouched:
nothing resolves the published gate copy, and that was as true before the
correction as after.*

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

### Requirement: A gate binding names only a skill that exists

Core SHALL bind a skill to a gate only while a skill declaring that canonical
name is installed. When every copy is removed, the binding SHALL be removed with
it.

Existence is judged by the **declared name**, never by a directory basename. A
skill packaged as `gstack-qa` declares `qa` and satisfies a binding of that name;
a directory named `qa` declaring something else does not. Two separate proposals
in one day reached false conclusions by enumerating directories, and both would
have passed a basename check.

A stale binding never fails. An absent gate skill is reported and work continues,
which is the property that lets a binding name a deleted skill indefinitely with
nothing going red. It is caught by reading, or not at all.

#### Scenario: The bound skill is removed from every host

- **WHEN** no host declares the canonical name a gate binds
- **THEN** the binding SHALL be removed from the gate table
- **AND** any rule making that skill's findings blocking SHALL be removed with it

#### Scenario: The skill is present under a prefixed directory name

- **WHEN** a bound skill is installed in a directory carrying a provider prefix
  whose `SKILL.md` declares the canonical name
- **THEN** the binding SHALL be satisfied and SHALL NOT be removed

### Requirement: A skill wanted on demand is not bound to a gate

Core SHALL NOT bind a skill to a gate when the skill is to be invoked at the
operator's choice rather than on the gate's trigger, however useful the skill is.

Availability and binding are different things. A skill installed on every host is
callable on every host; binding it to a gate additionally fires it automatically,
which for an on-demand tool is the opposite of what is wanted. Removing a binding
removes the automatic invocation and changes nothing about whether the skill can
be called.

Unbinding a skill that still exists is a **policy change, not a cleanup**, and
SHALL be stated as one rather than grouped with the removal of dead surface.

#### Scenario: An installed skill is unbound

- **WHEN** an installed skill is to be invoked on demand rather than on a trigger
- **THEN** no gate SHALL bind it
- **AND** the skill SHALL remain installed and callable by canonical name on
  every host
- **AND** the change SHALL describe the unbinding as a policy change

### Requirement: A gate left unbound stays defined, and the removal is breaking

Removing core's binding SHALL NOT remove the gate from §02's taxonomy. The gate
SHALL keep its trigger and evidence definitions so any host with a suitable skill
can bind it.

The version consequence SHALL be taken from §09 against the **behaviour** that
changes, not from whether a taxonomy row survives. A gate that stops firing and a
normative section that is deleted are breaking to every consumer, and SHALL be
released as a major version. A change SHALL NOT declare its own version
consequence inside its spec delta; §09 is the sole authority and a requirement
that classifies the change introducing it is circular.

#### Scenario: Core removes a binding

- **WHEN** core removes the skill bound to a gate
- **THEN** the gate SHALL remain defined in §02 with its trigger and evidence
  unchanged
- **AND** the release SHALL be classified under §09 by the behaviour lost

#### Scenario: A delta attempts to classify itself

- **WHEN** a spec delta states the version increment its own change is entitled to
- **THEN** that statement SHALL be removed and the classification taken from §09

### Requirement: A local artifact is not evidence about a normative section

A spec section SHALL NOT be retired, nor its obligations weakened, on evidence
drawn from one machine's state — a skills directory listing, a symlink, or an
installer variable.

Where a section leaves the concrete implementation name to the host's
discretion, no directory's presence or absence says anything about it. Three
separate attempts to retire §13 failed on exactly this: the first read
`~/.claude/skills`, the second read a deleted symlink, the third read
`install.sh`'s `ARCHIVED` variable — which identifies legacy symlink targets and
states in its own comment that it is "not a dependency". Measured 2026-08-09,
every host repository it names had a live remote and a commit four days old.

Retiring a section SHALL require an argument about repository lifecycle and
deployed consumers: a deprecation window, or evidence that no host ships an
implementation.

#### Scenario: A retirement is argued from local state

- **WHEN** a proposal argues to retire a section from a directory listing, a
  symlink, or an installer variable naming repositories
- **THEN** that argument SHALL NOT be sufficient
- **AND** the section SHALL be retained until a lifecycle argument is made

#### Scenario: A section names its implementation at the host's discretion

- **WHEN** a section states that the implementing skill's name is the host's
  choice
- **THEN** the absence of any particular skill name SHALL NOT be read as the
  section being unimplemented

### Requirement: A tool's failure-path recommendation is governed surface

Where a shipped tool recommends an artifact to an operator on a failure path,
that recommendation SHALL be treated as part of the governed interface and SHALL
be removed together with the artifact it names.

A removed artifact that a tool still tells an operator to reach for has not been
removed from the operator's point of view; it has been made unavailable while
still being advertised, which is worse than either state alone.

#### Scenario: A failure path recommends a removed artifact

- **WHEN** an artifact is removed and a shipped tool recommends it in a failure
  message
- **THEN** the recommendation SHALL be removed in the same change
- **AND** the removal SHALL be verified against the tool's output, not only its
  source

