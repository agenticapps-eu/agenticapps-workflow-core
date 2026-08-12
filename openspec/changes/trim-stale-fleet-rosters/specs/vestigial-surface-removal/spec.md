## MODIFIED Requirements

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

The tiebreaker below is unchanged and still decides genuine ambiguity toward
retention. This carve-out applies only where the three conditions are
*established by measurement and recorded*, which is a determination, not an
uncertainty — so it does not compete with the tiebreaker, which governs the case
where no determination could be reached.

#### Scenario: An artifact is a record rather than an interface

- **WHEN** an artifact is a decision record, an archived change, a changelog
  entry, a test, or authored documentation
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
