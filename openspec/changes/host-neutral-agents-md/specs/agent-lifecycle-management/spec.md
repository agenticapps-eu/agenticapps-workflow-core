## ADDED Requirements

### Requirement: Adding an agent is idempotent

Provisioning an agent into a repo SHALL be safely re-runnable. Running it twice
in a row SHALL produce one actual provision and one no-op.

#### Scenario: Agent not yet present

- **WHEN** an agent is provisioned into a repo that does not have it
- **THEN** the agent's own directory SHALL be created
- **AND** the agent's link SHALL be added to the shared instruction file
- **AND** the host-neutral workflow section SHALL be added if and only if the
  file does not already carry it

#### Scenario: Agent already present

- **WHEN** the same agent is provisioned again
- **THEN** the operation SHALL report that the agent is already present
- **AND** SHALL leave every file byte-identical

### Requirement: Removing an agent is supported and bounded

Removing an agent from a repo SHALL be a supported operation. It SHALL delete
that agent's own directory and SHALL NOT touch any other agent's files.

Taking an agent back out was previously unsupported. Doing it by hand in
`factiv/cparx` required locating tracked files, untracked files, and a section
of a shared file, with nothing to say when the job was complete.

#### Scenario: Removing one of several agents

- **WHEN** an agent is removed from a repo that has other agents provisioned
- **THEN** only that agent's own directory SHALL be deleted
- **AND** only that agent's link SHALL be removed from the shared instruction
  file
- **AND** the host-neutral workflow section SHALL be left in place
- **AND** every other agent's directory SHALL be unchanged

#### Scenario: Removing an agent that is not present

- **WHEN** removal is requested for an agent the repo does not have
- **THEN** the operation SHALL report that the agent is not present
- **AND** SHALL change nothing

#### Scenario: Partially-present agent

- **WHEN** removal encounters an agent whose provisioning is incomplete — for
  example a config file present but no skills, or files never committed
- **THEN** removal SHALL remove what is present
- **AND** SHALL report which expected artifacts were absent, rather than
  failing

This is the state both vestigial hosts in `factiv/cparx` were actually in:
`.opencode/` had a config and a version stamp but no skills, and `.codex/` was
never committed at all.

### Requirement: The shared instruction file carries one link per installed agent

The shared instruction file SHALL carry one link per installed agent, each
pointing at that agent's own file in its own directory. Adding an agent SHALL
add its link; removing an agent SHALL remove its link. No add or remove SHALL
change any other agent's link.

The link is the only host-specific content permitted in the shared file, so it
is also the only thing an add or remove may write there.

#### Scenario: First agent arrives

- **WHEN** an agent is provisioned into a repo with no agents
- **THEN** the host-neutral workflow section SHALL be added
- **AND** that agent's link SHALL be added

#### Scenario: Second agent arrives

- **WHEN** a second agent is provisioned
- **THEN** only that agent's link SHALL be added
- **AND** the host-neutral workflow section SHALL be byte-identical before and
  after
- **AND** the first agent's link SHALL be unchanged

#### Scenario: One of several agents leaves

- **WHEN** an agent is removed from a repo that will still have agents
- **THEN** only that agent's link SHALL be removed
- **AND** the host-neutral workflow section SHALL be byte-identical before and
  after
- **AND** every remaining agent's link SHALL be unchanged

### Requirement: The host-neutral section survives the last agent leaving

The host-neutral workflow section SHALL be written when the first agent arrives
and SHALL NOT be removed when the last agent leaves. Only the departing agent's
link is removed.

Removal would be symmetric, and symmetry is the wrong goal here: a repo that
briefly has no agent provisioned would lose the workflow documentation it is
about to want back, and re-adding an agent would have to reconstruct prose that
was never the agent's to own.

#### Scenario: Last agent leaves

- **WHEN** the only remaining agent is removed
- **THEN** that agent's link SHALL be removed
- **AND** the host-neutral workflow section SHALL remain
- **AND** all other content in the file SHALL be preserved

#### Scenario: An agent is re-added to a repo that has none

- **WHEN** an agent is provisioned into a repo that has the workflow section
  but no agents
- **THEN** only that agent's link SHALL be added
- **AND** the workflow section SHALL be byte-identical before and after

### Requirement: An agent's own directory is the unit of removal

Each agent's provisioned state SHALL be confined to that agent's own directory,
so that removal is the deletion of one directory rather than a search.

Anything an agent needs that cannot live there is a shared concern and belongs
in the host-neutral section instead.

#### Scenario: Removal completeness is checkable

- **WHEN** an agent has been removed
- **THEN** no file outside the shared instruction file SHALL still be
  attributable to that agent

#### Scenario: Tool-owned state is not workflow state

- **WHEN** an agent's directory also holds state owned by the agent's own CLI
  rather than by the workflow provisioning — for example a `package.json` and
  `node_modules` the tool manages itself
- **THEN** removal SHALL remove the workflow-provisioned files
- **AND** SHALL report, rather than silently delete, state it did not install
