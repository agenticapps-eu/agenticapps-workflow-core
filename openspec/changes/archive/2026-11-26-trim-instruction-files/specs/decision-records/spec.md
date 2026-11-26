## MODIFIED Requirements

### Requirement: The instruction file names the decision home

The section the initializer writes between the workflow markers SHALL name the
repository's decision home, and SHALL state that a record is append-only once
merged to the default branch: a merged record is corrected by a new record,
never edited. A record still on its change branch may be revised. The home is resolved when
the initializer runs, by the rule in *A repository has one home for decision
records*. Where more than one candidate holds records the initializer SHALL
refuse before any write and name every one. The initializer SHALL name the home
and SHALL NOT create it.

This carries the one fact a bound skill otherwise gets wrong into the file every
host loads on every turn, which the workflow skill is not. Append-only rides with
it for the same reason: a record is edited on a turn that touches no code, and
the skill is not loaded on that turn. It is a pointer to where the records are,
not a copy of the rules for writing them; those stay in the skill.

The section SHALL NOT name the glossary. `CONTEXT.md` is the same file in every
repository, so it is not a fact about this one, and the workflow skill states it
on the turns that write it.

Because the section's prose changed, its `section-version` SHALL advance, and a
re-run SHALL update an earlier section in place without changing any byte
outside the markers. That re-run is how existing repositories receive the line.

#### Scenario: A repository with no records

- **WHEN** the initializer runs where no candidate holds a record
- **THEN** the section SHALL name `docs/decisions/`
- **AND** SHALL state that merged records are append-only
- **AND** SHALL NOT name `CONTEXT.md`
- **AND** no `docs/` directory SHALL be created

#### Scenario: A repository whose records live in docs/adr/ or adrs/

- **WHEN** only `docs/adr/`, or only `adrs/`, holds records
- **THEN** the section SHALL name that directory
- **AND** SHALL NOT name `docs/decisions/`

#### Scenario: A README is not a record

- **GIVEN** a `docs/adr/` holding only `README.md`, and records in
  `docs/decisions/`
- **WHEN** the initializer runs
- **THEN** it SHALL name `docs/decisions/` and SHALL NOT refuse

#### Scenario: A repository with two homes

- **WHEN** two candidates both hold records
- **THEN** the initializer SHALL exit non-zero naming both
- **AND** SHALL write nothing

#### Scenario: A repository carrying an earlier section

- **GIVEN** a repository whose section carries `section-version: 1.0.0` or
  `1.1.0`
- **WHEN** the initializer is re-run
- **THEN** the section SHALL name the decision home
- **AND** SHALL carry the current section version
- **AND** no byte outside the markers SHALL change
