## ADDED Requirements

### Requirement: A rule set is read at the step that uses it

The workflow SHALL name, per step, which book rule sets are read and at which
size. Rule sets SHALL be bound skills, named unprefixed, never vendored or
re-worded into this repository.

- Grilling and propose: `the-pragmatic-programmer` and
  `domain-driven-design-distilled`, `mini`.
- Plan-review: `the-pragmatic-programmer`, `mini`.
- Code-review: `the-pragmatic-programmer` and `refactoring`, `mini`.
- A change that adds or alters an external integration SHOULD additionally read
  `release-it`, `mini`; a change that alters storage, a schema or a data
  pipeline SHOULD additionally read `designing-data-intensive-applications`,
  `mini`. The author decides at propose, states the choice in `design.md`, and
  neither book is installed today, so both resolve to the report-and-continue
  rule above.
- Apply: the workflow SHALL NOT load a book rule set for the implementing step.
  A rule set the operator invokes explicitly is their call and is not governed
  here. The implementing step carries the most context pressure, and the rule
  sets have already shaped the spec delta and tasks.

A rule set that is not installed SHALL be reported **by the step that reads it
on this machine**. A third-party reviewer is outside that rule: the producer
requests a status line and counts the verdict either way. Its absence alone SHALL
NOT block the step. Any other failure of that step — a red validation, a failing
command — blocks as it always did. No gate SHALL block on a missing rule set.

Two rule sets that push the same decision SHALL NOT be loaded together:
`clean-code` with `the-pragmatic-programmer`, or
`a-philosophy-of-software-design` with `codebase-design`.

#### Scenario: An interface is designed during propose

- **WHEN** a change's `design.md` places a seam or specifies a module's
  interface
- **THEN** `the-pragmatic-programmer` is read at `mini`

#### Scenario: A rule set is not installed

- **WHEN** a step names a rule set that does not resolve on this machine
- **THEN** its absence SHALL be reported
- **AND** that absence alone SHALL NOT block the step

#### Scenario: Only one of two named rule sets resolves

- **WHEN** a step names two rule sets and one of them does not resolve
- **THEN** the one that resolves SHALL be read
- **AND** the missing one SHALL be reported by name

#### Scenario: Terms are sharpened during grilling

- **WHEN** a grilling session builds or sharpens the domain model
- **THEN** `domain-driven-design-distilled` is read at `mini` alongside
  `the-pragmatic-programmer`

#### Scenario: A change touches an integration

- **WHEN** a change adds or alters an external integration
- **THEN** `release-it` SHOULD additionally be read at `mini`
- **AND** the choice SHALL be stated in the change's `design.md`
- **AND** its absence SHALL NOT block the change

#### Scenario: A change touches storage or a data pipeline

- **WHEN** a change alters storage, a schema or a data pipeline
- **THEN** `designing-data-intensive-applications` SHOULD additionally be read
  at `mini`
- **AND** the choice SHALL be stated in the change's `design.md`
- **AND** its absence SHALL NOT block the change

#### Scenario: Two rule sets that push the same decision

- **WHEN** `clean-code` and `the-pragmatic-programmer` are both available
- **THEN** only one SHALL be loaded for a given step

#### Scenario: A book that duplicates a design skill

- **WHEN** `a-philosophy-of-software-design` is available and `codebase-design`
  is already in reach
- **THEN** `codebase-design` SHALL be the one used
- **AND** the book SHALL NOT be loaded alongside it

#### Scenario: Implementation runs

- **WHEN** the apply step builds the tasks
- **THEN** the workflow SHALL NOT load a book rule set for it
- **AND** a rule set the operator names explicitly SHALL still be honoured

### Requirement: The plan-review lens travels in the prompt

The review producer SHALL **request** the plan-review lens in the prompt it hands
each reviewer, naming `the-pragmatic-programmer`, and SHALL ask each reviewer to
state whether it read it. Whether a third-party CLI obeys is outside this
workflow's reach: what is required here is that the request is made, reaches the
reviewer ahead of the artifacts, and asks for its own status back. The reviewers are separate agent
CLIs that never loaded the workflow skill, so no instruction elsewhere reaches
them. The **instruction block** SHALL NOT name `refactoring`: this step reads a
spec delta, and that rule set reads diffs, so sending it here would state a
second, different mapping from the one the workflow skill holds. The prohibition
is on the instruction block only — the artifacts below the `--- CHANGE:` marker
are the author's text and may say anything.

The lens SHALL sit in the instruction block, above the change artifacts, and
SHALL NOT enter the digest set: it is instruction, not evidence, and a review
already written SHALL NOT become stale because the lens changed.

The lens SHALL instruct a reviewer that cannot read the rule sets to review
without them and to say so in its reply.

#### Scenario: A reviewer that resolves the rule sets

- **WHEN** the producer builds the prompt
- **THEN** the prompt SHALL name `the-pragmatic-programmer`
- **AND** the naming SHALL appear before the change artifacts
- **AND** the prompt's instruction block SHALL NOT name `refactoring`, whatever
  the artifacts below the marker say

#### Scenario: A reviewer that cannot resolve it

- **WHEN** a vendor CLI has no access to the rule set
- **THEN** the prompt SHALL direct it to review without it and say so
- **AND** its verdict SHALL still count

#### Scenario: A reviewer ignores the request

- **WHEN** a reviewer neither reads the rule set nor says it could not
- **THEN** its verdict SHALL still count
- **AND** the producer SHALL NOT claim the review was made through the lens

#### Scenario: A review written before the lens existed

- **WHEN** the lens is added to the producer's instruction block
- **THEN** the digest of an unchanged change SHALL be unchanged
- **AND** the existing review SHALL still read as describing that change

### Requirement: Code-review's lens is passed by the invoker

The code-review step's rule sets SHALL be named by whoever invokes the upstream
review skill, because that skill is bound, not owned, and takes no lens. The
workflow SHALL state this asymmetry rather than imply that code-review is wired
like plan-review.

#### Scenario: Code-review is requested

- **WHEN** the reviewer is invoked on the diff
- **THEN** `the-pragmatic-programmer` and `refactoring` SHALL be named to it
- **AND** the upstream skill SHALL NOT be modified to carry them

#### Scenario: Code-review's rule sets are not installed

- **WHEN** neither book resolves on the machine running code-review
- **THEN** the review SHALL proceed on the repository's documented standards
- **AND** the absence SHALL be reported in the review

### Requirement: Lens provenance is not recorded, and that is stated

Review evidence SHALL NOT claim which version of a rule set a reviewer read. The
rule sets are upstream skills that update independently of this repository, so an
upstream edit can change the lens while the change digest and the producer
version both stay identical.

This is an accepted limitation rather than an oversight: the digest binds the
**artifacts reviewed**, which is what a stale review would misdescribe, and
binding a third-party skill's bytes would make every upstream update stale every
open review. Anyone auditing a review reads its verdict and its findings, not a
claim about the reviewer's reading list.

#### Scenario: A rule set is updated upstream

- **WHEN** a rule set changes upstream after a review was written
- **THEN** the review SHALL remain valid evidence for the artifacts it names
- **AND** nothing SHALL claim the review used the earlier or the later text
