# agent-lifecycle-management Specification

## Purpose
TBD - created by archiving change host-neutral-agents-md. Update Purpose after archive.
## Requirements
### Requirement: Adding an agent is idempotent

Provisioning an agent into a repo SHALL be safely re-runnable. Running it twice
in a row SHALL produce one actual provision and one no-op.

Idempotence is defined against the *complete* provisioned state, not against
the agent's directory alone. An agent is fully present when its directory
exists, its entry is in the shared instruction file, and the host-neutral
section is present. Provisioning SHALL bring a repo to that state from any
starting point, and SHALL report a no-op only when it was already there.

Treating the directory's existence as sufficient makes a half-provisioned repo
permanent: the directory is found, "already present" is reported, and the
missing entry is never added by any number of re-runs. That is the state both
vestigial hosts in `factiv/cparx` were actually in.

#### Scenario: Agent not yet present

- **WHEN** an agent is provisioned into a repo that does not have it
- **THEN** the agent's own directory SHALL be created
- **AND** the agent's link SHALL be added to the shared instruction file
- **AND** the host-neutral workflow section SHALL be added if and only if the
  file does not already carry it

#### Scenario: Agent fully present

- **WHEN** the same agent is provisioned again and every part of its
  provisioned state is present
- **THEN** the operation SHALL report that the agent is already present
- **AND** SHALL leave every file byte-identical

#### Scenario: Agent partially present

- **WHEN** an agent is provisioned into a repo where some but not all of its
  provisioned state exists — for example its directory is present but its entry
  is missing from the shared instruction file, or the reverse
- **THEN** the operation SHALL add only the missing parts
- **AND** SHALL report what it reconciled
- **AND** SHALL NOT report the agent as already present, since it was not

### Requirement: Removing an agent is supported and bounded

Removing an agent from a repo SHALL be a supported operation, bounded to that
agent's own directory and its entry in the shared instruction file. It SHALL
NOT touch any other agent's files.

Within that directory, removal SHALL delete the files the workflow provisioned,
and SHALL then remove the directory itself **only if it is empty**. Anything
remaining SHALL be left in place and named in the report, together with the
reason it was kept.

This ordering is the whole reconciliation between "removal is the deletion of
one directory rather than a search" and "tool-owned state is reported, not
deleted". The two read as contradictory unless the directory's removal is
stated as conditional on being empty: in the ordinary case nothing else is
there and removal *is* a single directory deletion, and in the case that
motivated the tool-owned-state rule the directory survives because something
the workflow did not install is still in it.

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
pointing at that agent's own file in its own directory, as a frontmatter list
keyed by agent identifier. Adding an agent SHALL add its entry; removing an
agent SHALL remove its entry. No add or remove SHALL change any other agent's
entry.

The link is the only host-specific content permitted in the shared file, so it
is also the only thing an add or remove may write there.

Because the entries share one frontmatter block, an add or remove rewrites that
block. "Unchanged" for another agent's entry therefore means its identifier and
path are unchanged — not that its bytes were untouched. The byte-identical
claim is made only of the host-neutral section, where it is both achievable and
the property that matters, since that section is the content every agent reads.

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
so that removal is bounded to one directory rather than being a search of the
repository.

Containment is what this requirement buys, and it is weaker than "removal is
one `rm -rf`" — the directory survives when tool-owned state is in it. The
guarantee is that removal never has to look anywhere else.

Anything an agent needs that cannot live there is a shared concern and belongs
in the host-neutral section instead.

#### Scenario: Removal completeness is checkable

- **WHEN** an agent has been removed
- **THEN** no **workflow-provisioned** file SHALL still be attributable to that
  agent
- **AND** any file remaining in that agent's directory SHALL be state the
  workflow did not install, and SHALL be named in the removal report

#### Scenario: Tool-owned state is not workflow state

- **WHEN** an agent's directory also holds state owned by the agent's own CLI
  rather than by the workflow provisioning — for example a `package.json` and
  `node_modules` the tool manages itself
- **THEN** removal SHALL remove the workflow-provisioned files
- **AND** SHALL report, rather than silently delete, state it did not install
- **AND** the directory SHALL remain, because it is not empty

#### Scenario: Nothing but workflow files remain

- **WHEN** removal deletes the workflow-provisioned files and the agent's
  directory is then empty
- **THEN** the directory SHALL be removed

### Requirement: Workflow-provisioned files are identifiable without a manifest

An implementation SHALL be able to determine which files in an agent's
directory it provisioned, and SHALL treat every file it cannot so attribute as
tool-owned state to be preserved and reported.

Removal has to distinguish what it installed from what the agent's own CLI
manages, and this design rejects a per-host manifest — it is new state that can
itself drift from disk, and a manifest disagreeing with the directory is harder
to reason about than a directory that is merely incomplete. The obligation is
therefore on the implementation to know its own output, by a fixed set of
provisioned paths or an equivalent rule it can state.

Defaulting the unknown case to *preserve* rather than *delete* is what makes
the absence of a manifest safe: an implementation that has lost track of a file
it installed leaves a stray file behind, which is reported and recoverable,
rather than deleting a file it did not install, which is not.

#### Scenario: A file cannot be attributed to the workflow

- **WHEN** removal encounters a file in the agent's directory that it cannot
  attribute to its own provisioning
- **THEN** it SHALL preserve the file
- **AND** SHALL report it as state of unknown origin that was kept

#### Scenario: The provisioned set is stated

- **WHEN** an implementation claims conformance with this capability
- **THEN** it SHALL document which paths within an agent's directory it
  provisions
- **AND** that set SHALL be what removal deletes

