## ADDED Requirements

### Requirement: The gate fails a commit whose two instruction files differ

Where a repository carries both `AGENTS.md` and `CLAUDE.md`, the gate SHALL
compare them and SHALL fail the commit when they are not byte-identical. It
SHALL also fail when either name is unreadable, and when either is a symlink.

**The comparison SHALL read the staged index — blob and mode — and never the
working tree.** A pre-commit check that compares worktree files asserts
something other than what is about to be committed: an unstaged edit to one
name can make a genuinely divergent pair look equal, and an unstaged edit can
fail a commit whose staged content is fine. Both failure directions are worse
than no check, because both teach the operator that the check is noise.

**Where the repository is enrolled, both names SHALL be present.** The gate
SHALL fail a commit that stages the deletion of either one. Enrolment is the
existing predicate `agenticapps.workflow.enrolled` in the repository's local
git config, which the initializer writes and the floor already resolves — so
the check needs no new state to decide whether a repository ever had two names
to keep.

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

#### Scenario: Only one name is present, and the repository is not enrolled

- **GIVEN** a repository carrying exactly one of the two names
- **AND** `agenticapps.workflow.enrolled` is not set in its local git config
- **WHEN** a commit is attempted
- **THEN** the gate SHALL NOT fail on this check

Not every repository uses this workflow, and one that never ran the initializer
has nothing to compare. The gate does not create work for repositories that
never opted in.

#### Scenario: An enrolled repository stages the deletion of one name

- **GIVEN** an enrolled repository carrying both names
- **WHEN** a commit stages the deletion of either one
- **THEN** the gate SHALL fail
- **AND** it SHALL name the file being removed

Without this, the pair is trivially escapable: delete one name and the equality
check has nothing to compare, so the strictest requirement in this capability is
satisfied by removing its subject. The staged-deletion case is the one an
ordinary `git rm` reaches by accident.

#### Scenario: A staged divergence hidden by an unstaged edit

- **GIVEN** an enrolled repository whose staged `AGENTS.md` and `CLAUDE.md`
  differ
- **AND** a working-tree edit that makes the two paths equal on disk
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail, because the staged blobs differ

#### Scenario: An unreadable instruction file

- **GIVEN** a repository where either name cannot be read
- **WHEN** a commit is attempted
- **THEN** the gate SHALL fail, reporting which name could not be read

A read is the only check that catches this. Structural inspection reports a
plausible file for both halves of a symlink cycle, which is how two repositories
carried unreadable instruction files for about 36 hours with every check green.
