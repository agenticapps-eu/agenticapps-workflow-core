## ADDED Requirements

### Requirement: The shared instruction file carries exactly one workflow section

A project's shared agent instruction file (`AGENTS.md`) SHALL contain at most
one AgenticApps workflow section, regardless of how many agents are installed,
and SHALL contain exactly one whenever at least one agent is provisioned. The
section SHALL be host-neutral: it describes the workflow, not the agent reading
it.

"At most one" and "exactly one" are both required and they bind different
states. A repo with no agents may legitimately carry no section — nothing has
been provisioned. A repo that lists an agent and carries no section is broken:
its agents are pointed at a workflow the file does not describe.

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

The frontmatter SHALL sit at the top of the file, **outside** the marker-
delimited workflow section. The two are disjoint surfaces: the section carries
host-neutral prose and never changes when an agent is added or removed, while
the frontmatter carries the per-agent entries and changes on exactly those
operations. Placing the entries inside the markers would make "the section is
byte-identical before and after" unsatisfiable for every add — the two
requirements would contradict each other on the first second agent.

This separation is also what makes the link exemption below meaningful rather
than a special case: an entry is not inside the section, so a check scoped to
the section body cannot reach it.

#### Scenario: The file already has frontmatter with other keys

- **WHEN** an agent's entry is added to a file whose frontmatter already
  carries unrelated keys
- **THEN** the `agents:` key SHALL be merged into the existing frontmatter
- **AND** every other key and its value SHALL be preserved unchanged

#### Scenario: The file has no frontmatter

- **WHEN** an agent's entry is added to a file that has no frontmatter
- **THEN** frontmatter SHALL be created at the top of the file containing only
  the `agents:` key
- **AND** every byte of the file's existing content SHALL be preserved below it

### Requirement: An agent entry's path is repository-relative and bounded

An agent entry's value SHALL be a repository-relative path that resolves inside
that agent's own directory. An implementation SHALL reject an entry whose path
is absolute, traverses upward (`..`), is a URL, or resolves outside the
repository, and SHALL reject a duplicate agent identifier.

This is a safety requirement, not a tidiness one. These paths are consumed by
tooling that deletes, and by agents that read; a path that escapes the
repository turns removal into deletion of something the operator never
provisioned. An absolute path additionally embeds the machine's directory
layout — a home directory carries a username — into a file that is committed
and shared.

#### Scenario: A path escapes the repository

- **WHEN** an agent entry's path is absolute, contains `..`, or otherwise
  resolves outside the repository
- **THEN** the entry SHALL be reported as a violation
- **AND** no removal SHALL act on that path

#### Scenario: An agent identifier appears twice

- **WHEN** the `agents:` key carries the same identifier more than once
- **THEN** the condition SHALL be reported as a violation
- **AND** the entries SHALL NOT be silently deduplicated, since they may name
  different paths and choosing between them is not mechanical

### Requirement: The section carries a version so stale content can be repaired

The workflow section SHALL carry a version identifier for its content, and a
host provisioning into a repo whose section is older than the one it ships
SHALL report that the section is out of date and offer to update it.

Without this, the first host to provision a repo fixes its workflow prose
forever. Adding an agent is a no-op when the agent is present, and the
byte-identical requirement forbids a later host from rewriting the section — so
a repo provisioned from a template that cited GSD keeps citing GSD after GSD is
deleted, and no supported operation can repair it.

That is the exact failure this capability was opened to fix, reproduced one
level up: the original problem was two copies of the prose drifting apart, and
a first-writer-wins rule replaces it with one copy that can never move. A
version identifier is the smallest thing that makes staleness *visible*; the
update itself is offered rather than silent, because rewriting shared prose
that every agent reads is not a side effect any single agent should apply
unannounced.

#### Scenario: A newer section is available

- **WHEN** a host provisions into a repo whose section version is older than
  the version that host ships
- **THEN** the host SHALL report that the section is out of date, naming both
  versions
- **AND** SHALL update it only with the operator's acceptance

#### Scenario: The section is current

- **WHEN** the repo's section version matches the host's
- **THEN** no update SHALL be offered
- **AND** the section SHALL be left byte-identical

#### Scenario: The operator declines the update

- **WHEN** the operator declines a section update
- **THEN** provisioning SHALL continue
- **AND** the section SHALL be left byte-identical

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

#### Scenario: Host-specific content beyond a link is present

- **WHEN** the shared instruction file carries host-specific content other than
  the frontmatter agent entries
- **THEN** the condition SHALL be reported as a violation identifying the
  content and its location
- **AND** the report SHALL NOT be required to name which host wrote it, because
  the file records no provenance — every host writes the same marker, and that
  is precisely why a duplicate cannot be attributed either

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
reported at warning severity, not as a failure. The per-agent entries SHALL be
exempt from this check.

The denylist SHALL contain at least these identifiers:

| Identifier | Why |
|---|---|
| `codex` | host name |
| `opencode` | host name |
| `claude` | host name |
| `codex-workflow` | binding repo |
| `opencode-workflow` | binding repo |
| `claude-workflow` | binding repo |
| `pi-agentic-apps-workflow` | binding repo |

Enumerating the list is what makes the requirement implementable. "Known host
identifiers" with the list deferred lets two hosts ship different denylists and
both claim conformance — which is the drift this capability exists to prevent,
reproduced inside its own check.

The bare identifier `pi` is deliberately **excluded**. Two letters match
"pipeline", "typing", "pick" and most prose containing them, so including it
would fire on ordinary text far more often than on a host reference. The
binding repo name stands in for it. The consequence is concrete and stated
rather than hidden: a section reading "on the Pi host" is not caught.

An implementation MAY extend the list, and SHALL NOT shrink it. A host whose
identifier is not on the list cannot be detected — and since the set of hosts
is expected to change, that is the normal case for any new host rather than an
edge case. This is the principal reason the check warns instead of failing: a
denylist is a lower bound on detection, and a lower bound must not be the thing
that blocks.

Exempting the entries is not a refinement but a correctness requirement: they
are host-specific by design, and a check that flagged them would fire on the
one thing this capability explicitly permits. Because the frontmatter sits
outside the markers, a check scoped to the section body satisfies this
structurally.

#### Scenario: A host name appears in the section body

- **WHEN** a known host identifier is found inside the workflow section
- **THEN** a warning SHALL be reported naming the identifier and its location
- **AND** the check SHALL NOT fail

#### Scenario: A host name appears in a link

- **WHEN** a known host identifier appears within a per-agent link
- **THEN** no warning SHALL be reported for it

### Requirement: The shared instruction file is delimited and machine-removable

The workflow section SHALL be enclosed in begin and end markers so that it can
be located and removed without reading its prose. The markers SHALL be exactly:

```
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
<!-- END: agentic-apps-workflow sections -->
```

The literal strings are normative. A contract whose whole purpose is to be
machine-checkable by a host repo without core executing it cannot leave the one
string that detection depends on to a design narrative — a host implementing
from this requirement alone would have to invent it, and two hosts inventing
separately is the duplication this capability exists to prevent.

This is not a new marker. All three live host templates already write exactly
this, which is why hosts collide in one file: the name is shared and none of
them looks for it first.

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
