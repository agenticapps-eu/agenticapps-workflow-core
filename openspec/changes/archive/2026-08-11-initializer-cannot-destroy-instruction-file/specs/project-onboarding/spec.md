## ADDED Requirements

### Requirement: The arrangement is verified by reading, not by inspecting links

Before reporting success, the initializer SHALL read both instruction-file names
and confirm each returns the same non-empty content. Structural checks — `-f`,
`-L`, `readlink`, the git index mode — SHALL NOT be the only evidence that the
arrangement is sound.

Every structural assertion the initializer's own suite made was satisfied by two
repositories whose instruction files could not be read at all. `-L` reports true
for both halves of a symlink cycle and `readlink` reports a plausible target for
each, so the pair looked correct to every check either side of it while every
read returned `ELOOP`. The state lasted about 36 hours and no host, hook or CI
job noticed, because an unreadable instruction file is indistinguishable from an
absent one.

**A read is the last thing the initializer does, and it is the only check that
can fail on an arrangement the initializer itself just wrote.** Everything before
it tests the starting state; this tests the result.

#### Scenario: A structurally plausible arrangement that cannot be read

- **GIVEN** a repository where the two names cannot be read — a symlink cycle is
  the case that occurred, but the requirement is about the read, not the cause
- **WHEN** the arrangement is verified
- **THEN** verification SHALL fail, naming the name that could not be read
- **AND** the initializer SHALL NOT report success

#### Scenario: A correct arrangement passes the read check

- **GIVEN** a repository where `AGENTS.md` and `CLAUDE.md` are both regular,
  non-empty files
- **WHEN** the arrangement is verified
- **THEN** verification SHALL succeed
- **AND** reading either name SHALL return the same non-empty content

#### Scenario: The two names disagree after a write

- **GIVEN** an initializer run that wrote one name successfully and the other
  not, leaving the two different
- **WHEN** the arrangement is verified
- **THEN** verification SHALL fail rather than report a partial success
- **AND** the operator SHALL be told the two names now differ, because the
  commit gate will fail on exactly that and the cause belongs with the run that
  caused it
