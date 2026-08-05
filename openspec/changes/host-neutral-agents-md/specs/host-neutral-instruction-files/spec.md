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
- **AND** the section's content is byte-identical to what it was before the
  second agent was added
- **AND** the only addition to the file is that agent's link

#### Scenario: A duplicate section is present from a prior install

- **WHEN** the shared instruction file is found to contain more than one
  workflow section
- **THEN** the condition SHALL be reported as a violation naming every
  duplicate section found
- **AND** the report SHALL NOT silently collapse them, because the copies may
  have drifted and choosing between them is not mechanical

### Requirement: A link is the only host-specific content in the shared file

The only host-specific content an installer SHALL write into the shared
instruction file is one link per installed agent, pointing at that agent's own
file in that agent's own directory. Everything else that differs between agents
SHALL live in that agent's directory (`.codex/`, `.opencode/`, `.pi/` or
equivalent).

The links SHALL be carried as a frontmatter list keyed by agent identifier,
whose value is the path to that agent's own file:

```yaml
---
agents:
  codex: .codex/AGENTS.md
  pi: .pi/AGENTS.md
---
```

Each entry's value SHALL be a path. A bare identifier is an inventory of what
is installed, not a pointer to where its instructions are, and an agent reading
the shared file would have no way to reach its own.

The measured host-specific surface is small. Across the three live host
templates, four values carry it: the host directory, the binding repo, the
invocation syntax for skills and prompts, and the trigger-skill install root.
Everything else in the observed blocks was identical once host names were
normalised out. A link is enough to reach all of it, and is the smallest thing
that can be added and removed per agent without touching prose any other agent
reads.

#### Scenario: Invocation syntax differs between agents

- **WHEN** two agents invoke the same workflow step with different syntax
  (for example `/gsd-discuss-phase` versus `/prompts:gsd-discuss-phase`)
- **THEN** the shared instruction file SHALL name the step host-neutrally
- **AND** each agent's own file, reached through its link, SHALL carry that
  agent's invocation form

#### Scenario: A host writes host-specific content beyond its link

- **WHEN** a host's provisioning writes host-specific content into the shared
  instruction file other than its own link
- **THEN** the condition SHALL be reported as a violation identifying the host
  and the content

#### Scenario: A host writes its link

- **WHEN** a host's provisioning adds its link to the shared instruction file
- **THEN** this SHALL NOT be reported as a violation

#### Scenario: An entry names an agent without pointing at its file

- **WHEN** a frontmatter agent entry carries a bare identifier rather than a
  path to that agent's own file
- **THEN** the condition SHALL be reported as a violation
- **AND** the report SHALL state that the entry is an inventory rather than a
  link, since nothing in the shared file then reaches that agent's instructions

### Requirement: A host identifier inside the workflow section is a warning

A host identifier appearing inside the host-neutral workflow section SHALL be
reported at warning severity, not as a failure. The per-agent links SHALL be
exempt from this check.

The check is a denylist of known host identifiers and cannot recognise novel
phrasing, so it will both miss cases and occasionally fire on prose that merely
mentions a host in passing. Failing on it would make a partial heuristic
blocking. Exempting the links is not a refinement but a correctness
requirement: the links are host-specific by design, and a check that flagged
them would fire on the one thing this capability explicitly permits.

#### Scenario: A host name appears in the section body

- **WHEN** a known host identifier is found inside the workflow section
- **THEN** a warning SHALL be reported naming the identifier and its location
- **AND** the check SHALL NOT fail

#### Scenario: A host name appears in a link

- **WHEN** a known host identifier appears within a per-agent link
- **THEN** no warning SHALL be reported for it

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
