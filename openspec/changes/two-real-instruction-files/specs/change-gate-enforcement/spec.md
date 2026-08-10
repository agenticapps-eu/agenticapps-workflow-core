## ADDED Requirements

### Requirement: The gate fails a commit whose two instruction files differ

Where a repository carries both `AGENTS.md` and `CLAUDE.md`, the gate SHALL
compare them and SHALL fail the commit when they are not byte-identical. It
SHALL also fail when either name is unreadable, and when either is a symlink.

This is the only enforcement in this workflow that **blocks** besides
`openspec validate --all`, and it earns that by replacing a guarantee rather
than adding one. Until now the two names were the same inode, so divergence was
impossible by construction; two regular files make it possible, and a check that
merely reported would leave the fleet exactly where the previous synced-block
mechanism left it.

That precedent is the reason for the strength. Six "auto-synced" blocks lived in
fleet instruction files under a syncer that was retired on 2026-07-28; the blocks
went on declaring themselves auto-synced for months while nothing synced them,
and nothing reported it because nothing was looking. A writer without a blocking
check reproduces that outcome with a different marker.

Symlinks are rejected rather than resolved. A resolved link compares equal to
itself and would pass this check while reintroducing the arrangement the
initializer no longer produces.

#### Scenario: The two names have diverged

- **GIVEN** a repository where `AGENTS.md` and `CLAUDE.md` differ
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail
- **AND** it SHALL name both files and report that they must be identical

#### Scenario: One name is a symlink to the other

- **GIVEN** a repository where either name is a symlink
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail
- **AND** it SHALL report that both names must be regular files

#### Scenario: Only one name is present

- **GIVEN** a repository carrying exactly one of the two names
- **WHEN** a commit is attempted
- **THEN** the gate SHALL NOT fail on this check

Not every repository uses this workflow, and a repository with a single
instruction file has nothing to compare. The initializer establishes the second
name; the gate does not create work for repositories that never ran it.

#### Scenario: An unreadable instruction file

- **GIVEN** a repository where either name cannot be read
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail, reporting which name could not be read

A read is the only check that catches this. Structural inspection reports a
plausible file for both halves of a symlink cycle, which is how two repositories
carried unreadable instruction files for about 36 hours with every check green.
