## ADDED Requirements

### Requirement: The shared instruction file carries exactly one workflow section

A project's shared agent instruction file (`AGENTS.md`) SHALL contain at most
one AgenticApps workflow section, regardless of how many agents are installed.
The section SHALL be host-neutral: it describes the workflow, not the agent
reading it.

This file is read by every agent that opens it. A second copy is not additional
information — it is the same instruction stated twice, and the two copies drift.

#### Scenario: One agent installed

- **WHEN** a repo has exactly one agent provisioned
- **THEN** `AGENTS.md` contains exactly one workflow section
- **AND** that section names no specific host

#### Scenario: Two agents installed

- **WHEN** a second agent is provisioned into a repo that already has the
  workflow section
- **THEN** `AGENTS.md` still contains exactly one workflow section
- **AND** its content is byte-identical to what it was before the second agent
  was added

#### Scenario: A duplicate section is present from a prior install

- **WHEN** the shared instruction file is found to contain more than one
  workflow section
- **THEN** the condition SHALL be reported as a violation naming every
  duplicate section found
- **AND** the report SHALL NOT silently collapse them, because the copies may
  have drifted and choosing between them is not mechanical

### Requirement: Host-specific detail lives in the host's own directory

Content that differs between agents SHALL live in that agent's own directory
(`.codex/`, `.opencode/`, `.pi/` or equivalent), not in the shared instruction
file.

The measured host-specific surface is small — the binding repo name, the host
config path, and the skill or prompt invocation syntax. Everything else in the
observed duplicate blocks was identical after host names were normalised out.

#### Scenario: Invocation syntax differs between agents

- **WHEN** two agents invoke the same workflow step with different syntax
  (for example `/gsd-discuss-phase` versus `/prompts:gsd-discuss-phase`)
- **THEN** the shared instruction file SHALL name the step host-neutrally
- **AND** each agent's own directory SHALL carry that agent's invocation form

#### Scenario: A host attempts to write host-specific content to the shared file

- **WHEN** a host's provisioning writes host-specific content into the shared
  instruction file
- **THEN** the condition SHALL be reported as a violation identifying the host
  and the content

### Requirement: The shared instruction file is delimited and machine-removable

The workflow section SHALL be enclosed in begin and end markers so that it can
be located and removed without reading its prose.

Removing the two host blocks from `factiv/cparx` was mechanical only because
those hosts happened to write markers. Nothing required it, so nothing
guaranteed it for the next host.

#### Scenario: Locating the section

- **WHEN** tooling needs to find the workflow section
- **THEN** it SHALL locate it by its markers alone
- **AND** SHALL NOT depend on any heading text, ordering, or wording inside the
  section

#### Scenario: Content outside the markers is preserved

- **WHEN** the workflow section is removed from a shared instruction file that
  also carries unrelated content
- **THEN** every byte outside the markers SHALL be unchanged

### Requirement: The Claude instruction file is out of scope

`CLAUDE.md` SHALL NOT be subject to these requirements.

Claude is its only reader, so there is no second agent to coordinate with and
nothing to deduplicate. A marker convention there would carry cost with no
corresponding failure mode.

#### Scenario: Claude-only project

- **WHEN** a repo is provisioned for Claude alone
- **THEN** no requirement in this capability applies to `CLAUDE.md`
- **AND** the absence of markers in `CLAUDE.md` SHALL NOT be reported as a
  violation
