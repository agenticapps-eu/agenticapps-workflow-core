## ADDED Requirements

### Requirement: Adding an agent is idempotent

Provisioning an agent into a repo SHALL be safely re-runnable. Running it twice
in a row SHALL produce one actual provision and one no-op.

#### Scenario: Agent not yet present

- **WHEN** an agent is provisioned into a repo that does not have it
- **THEN** the agent's own directory SHALL be created
- **AND** the shared workflow section SHALL be added if and only if no agent
  was present before

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
- **AND** the shared workflow section SHALL be left in place
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

### Requirement: The shared instruction file is touched only at the boundaries

The shared workflow section SHALL be added when the first agent arrives and
removed when the last agent leaves. No other add or remove SHALL modify it.

#### Scenario: First agent arrives

- **WHEN** an agent is provisioned into a repo with no agents
- **THEN** the shared workflow section SHALL be added

#### Scenario: Last agent leaves

- **WHEN** the only remaining agent is removed
- **THEN** the shared workflow section SHALL be removed
- **AND** all other content in the file SHALL be preserved

#### Scenario: Neither boundary

- **WHEN** an agent is added to a repo that already has one, or removed from a
  repo that will still have one
- **THEN** the shared instruction file SHALL be byte-identical before and after

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
