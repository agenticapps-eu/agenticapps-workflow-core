## ADDED Requirements

### Requirement: A tool SHALL NOT create a symlink cycle between the instruction-file names

A tool that establishes the instruction-file arrangement SHALL refuse any
starting state in which `AGENTS.md` is a symlink. It SHALL NOT create a link at
`CLAUDE.md` while `AGENTS.md` is one, because that closes a cycle and destroys
the content both names were carrying.

The refusal SHALL name what `AGENTS.md` points at and SHALL name what the
operator has to do to proceed. It SHALL leave both paths' types, link targets
and contents exactly as it found them.

This constrains **what a tool may do to a repository**. It does not subject
`CLAUDE.md` to the content conventions this capability places on the shared
file — markers, frontmatter, the section version — and the carve-out exempting
it from those is untouched. A rule that a tool may not destroy a file is not a
rule about what that file must contain.

An `ELOOP` on the instruction file is worse than a missing one. A missing file
is visible to anyone who looks; a cycle reads as "no instruction file" to every
host, on every read, while both names appear in `git ls-files` and in a
directory listing. Two repositories carried this state for about 36 hours and
no host, hook or CI job noticed.

#### Scenario: AGENTS.md is already a symlink to CLAUDE.md

- **GIVEN** a repository where `CLAUDE.md` is a regular file
- **AND** `AGENTS.md` is a symlink to `CLAUDE.md`
- **WHEN** the initializer runs
- **THEN** it SHALL exit non-zero
- **AND** its message SHALL name `AGENTS.md`'s link target
- **AND** its message SHALL name what the operator must do to proceed
- **AND** `CLAUDE.md` SHALL still be a regular file, byte-identical to before
- **AND** `AGENTS.md` SHALL still be a symlink to the same target as before

#### Scenario: AGENTS.md is a symlink to somewhere else entirely

- **GIVEN** a repository where `AGENTS.md` is a symlink to a path outside the
  repository
- **WHEN** the initializer runs
- **THEN** it SHALL exit non-zero
- **AND** it SHALL write nothing through that link

#### Scenario: A content comparison never mistakes a link for a second file

- **GIVEN** a repository where one instruction-file name is a symlink that
  resolves to the other
- **WHEN** the tool compares the two names to decide whether they may be
  collapsed into one file
- **THEN** it SHALL NOT treat the comparison as evidence that two independent
  files hold identical content
- **AND** it SHALL refuse rather than proceed on that evidence

The condition is an unexpected symlink topology, not inode identity. After a
correct run the two names *do* resolve to the same inode — that is the intended
end state, and so is a pair of hard-linked regular files. Neither is what this
scenario forbids.

### Requirement: The arrangement is verified by reading, not by inspecting links

Before reporting success, a tool that establishes or checks the instruction-file
arrangement SHALL read both names and confirm each returns the same non-empty
content. Structural checks — `-f`, `-L`, `readlink`, the git index mode — SHALL
NOT be the only evidence that the arrangement is sound.

`-L` reports true for both halves of a symlink cycle and `readlink` reports a
plausible target for each. Every structural assertion the initializer's own
suite made was satisfied by two repositories whose instruction files could not
be read at all. Only a read distinguishes a working link from a loop.

#### Scenario: A structurally plausible arrangement that cannot be read

- **GIVEN** a repository where `AGENTS.md` and `CLAUDE.md` are both symlinks
  pointing at each other
- **WHEN** the arrangement is verified
- **THEN** verification SHALL fail
- **AND** it SHALL report that the instruction file could not be read

#### Scenario: A correct arrangement passes the read check

- **GIVEN** a repository where `AGENTS.md` is a regular non-empty file
- **AND** `CLAUDE.md` is a symlink to `AGENTS.md`
- **WHEN** the arrangement is verified
- **THEN** verification SHALL succeed
- **AND** reading either name SHALL return the same non-empty content
