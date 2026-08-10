## MODIFIED Requirements

### Requirement: The shared instruction file carries one link per installed agent

The shared instruction file SHALL carry one link per installed agent, each
pointing at that agent's own file in its own directory, as a frontmatter list
keyed by agent identifier. Adding an agent SHALL add its entry; removing an
agent SHALL remove its entry. No add or remove SHALL change any other agent's
entry.

**Where the repository carries the shared file under both names, every write
required here SHALL be applied to both copies in the same operation**, leaving
them byte-identical. A writer that touches one name is a writer that produces
divergence, which the gate then fails.

This was implicit while the two names were one inode: writing "the shared
instruction file" reached both by construction, and the singular in this
requirement was accurate. Two regular files make the singular ambiguous, and an
add or remove that resolved it to one name would break every repository it ran
in — silently at write time, loudly at the next commit.

The link is the only host-specific content permitted in the shared file, so it
is also the only thing an add or remove may write there.

Because the entries share one frontmatter block, an add or remove rewrites that
block. "Unchanged" for another agent's entry therefore means its identifier and
path are unchanged — not that its bytes were untouched. The byte-identical
claim is made only of the host-neutral section, where it is both achievable and
the property that matters, since that section is the content every agent reads.

The three scenarios below are carried through unchanged. A MODIFIED block
replaces the requirement whole, so omitting them would delete them — which is
what `openspec archive` refused to do, correctly, when this delta first named
only the new one.

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

#### Scenario: Adding an agent in a repository carrying both names

- **GIVEN** a repository carrying the shared file as `AGENTS.md` and `CLAUDE.md`
- **WHEN** an agent is added
- **THEN** its entry SHALL be written to both names
- **AND** the two files SHALL be byte-identical afterwards
