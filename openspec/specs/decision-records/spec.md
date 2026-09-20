# decision-records Specification

## Purpose
Where a repository's decision records live, when one is required and what it
holds — and how a bound skill that defaults elsewhere is overridden without any
per-repository configuration. Bound planning skills write records on their own;
this capability makes them write to one home per repository, named in the
instruction file every host loads on every turn.
## Requirements
### Requirement: A repository has one home for decision records

A repository's decision records SHALL live in exactly one home, chosen from the
recognised candidates `docs/decisions/`, `docs/adr/` and `adrs/`. The home is the
candidate that holds records; `docs/decisions/` when none does. A record is a
markdown file directly in the directory other than `README.md` and `index.md`.
A repository SHALL NOT gain a second home.

A bound skill whose default is another directory SHALL read and write the
repository's home instead. The instruction file names the home (see *The
instruction file names the decision home*); the workflow skill states the
override, and its statement wins over the bound skill's default.

A new record SHALL follow the numbering scheme already present in the home —
sequential `NNNN-slug.md` or date-based `ADR-YYYY-MM-DD-slug.md`. Only an empty
home takes `0001-slug.md`.

Multi-context layouts (a root `CONTEXT-MAP.md` with per-context records) are out
of scope for this requirement; no repository in the fleet uses one. A nested
sub-project with its own records (for example `tokentelemetry/docs/adr/`) is a
separate repository for this purpose and is not a second home of its parent.

#### Scenario: A bound skill that defaults to docs/adr/ records a decision

- **GIVEN** a repository whose instruction file names `docs/decisions/`
- **WHEN** a bound skill whose default home is `docs/adr/` records a decision
- **THEN** the record SHALL be written to `docs/decisions/`
- **AND** `docs/adr/` SHALL NOT be created

#### Scenario: A bound skill reads records before proposing a change

- **WHEN** a bound skill reads existing records to avoid re-proposing a rejected
  decision
- **THEN** it SHALL read the repository's home, so a decision recorded there is
  found

#### Scenario: The home numbers records by date

- **GIVEN** a home whose records are named `ADR-YYYY-MM-DD-slug.md`
- **WHEN** a new record is written
- **THEN** it SHALL be named by the same scheme, not `NNNN-slug.md`

#### Scenario: A repository already uses docs/adr/

- **GIVEN** a repository with records in `docs/adr/` and none in the other
  candidates
- **WHEN** a decision is recorded
- **THEN** it SHALL be written to `docs/adr/`
- **AND** `docs/decisions/` SHALL NOT be created

### Requirement: When a record is required, and what it holds

A Medium or Large change SHALL record every locked decision it makes. A decision
is locked when it is **hard to reverse** and the **outcome of a real trade-off**
— there were genuine alternatives, and one was chosen for stated reasons. A
decision that would surprise a reader without context is the strongest case for
a record, but surprise is guidance, not a condition: "use Postgres" is recorded
even though nobody is surprised by it.

On a Medium or Large change, a decision that is not locked SHALL be stated in the
change's `design.md` instead. Small and Tiny changes have no record requirement.

A record MAY be one paragraph. It SHALL state the context, the decision and the
reason, and it SHALL name at least one rejected alternative.

#### Scenario: An easily reversed decision on a Medium change

- **WHEN** a Medium change makes a decision that is easy to reverse
- **THEN** it SHALL appear in the change's `design.md`
- **AND** no record SHALL be written for it

#### Scenario: A record names no alternative

- **WHEN** code-review reads a record in the diff that names no rejected
  alternative
- **THEN** the review SHALL report the record as incomplete

#### Scenario: A Small change

- **WHEN** a Small change makes a decision
- **THEN** neither a record nor a `design.md` SHALL be required for it

### Requirement: The overrides need no per-repository configuration

The override of a bound skill's defaults SHALL be carried machine-level, by the
workflow skill, and by the section the initializer writes. A repository SHALL NOT
need a bound skill's per-repository configurator to be run, and the workflow
skill SHALL say not to run one that writes configuration files into the
repository or edits one instruction file name without the other.

The glossary SHALL be `CONTEXT.md` at the repository root. It holds terms and
their meanings, not implementation. It is distinct from the per-phase
`CONTEXT.md` of the retired GSD layout, which survives only under
`docs/legacy-planning/`.

A bound skill that needs an issue tracker and finds none configured SHALL use the
local-markdown tracker under `.scratch/`, and `.scratch/` SHALL be excluded
through the repository's local exclude file — the path `git rev-parse --git-path
info/exclude` resolves, which also holds in a linked worktree — before the first
file is written there. It SHALL never be excluded through a tracked `.gitignore`,
which would be a repository artifact, and if anything under `.scratch/` is
already tracked the skill SHALL stop and report it.

#### Scenario: A bound skill asks for its configurator

- **WHEN** a bound skill finds its per-repository configuration absent and
  suggests running its configurator
- **THEN** the configurator SHALL NOT be run
- **AND** the skill SHALL proceed on the workflow skill's overrides and its own
  documented defaults

#### Scenario: A clone whose section names the home

- **GIVEN** a repository whose instruction-file section carries
  `section-version: 1.1.0` or later
- **WHEN** it is cloned onto a machine where the workflow is installed and a
  bound planning skill records a decision
- **THEN** the record lands in the named home with no further per-repository step

#### Scenario: A bound skill needs an issue tracker

- **WHEN** a bound skill needs an issue tracker and none is configured
- **THEN** it SHALL use the local-markdown tracker under `.scratch/`
- **AND** `.scratch/` SHALL be listed in the exclude file `git rev-parse
  --git-path info/exclude` resolves, before the first file is written there
- **AND** nothing under `.scratch/` SHALL be committed

### Requirement: The instruction file names the decision home

The section the initializer writes between the workflow markers SHALL name the
repository's decision home and its glossary, `CONTEXT.md`. The home is resolved
when the initializer runs, by the rule in *A repository has one home for decision
records*. Where more than one candidate holds records the initializer SHALL
refuse before any write and name every one. The initializer SHALL name the home
and SHALL NOT create it.

This carries the one fact a bound skill otherwise gets wrong into the file every
host loads on every turn, which the workflow skill is not. It is a pointer to
where the records are, not a copy of the rules for writing them; those stay in
the skill.

Because the section's prose changed, its `section-version` SHALL advance, and a
re-run SHALL update an earlier section in place without changing any byte
outside the markers. That re-run is how existing repositories receive the line.

#### Scenario: A repository with no records

- **WHEN** the initializer runs where no candidate holds a record
- **THEN** the section SHALL name `docs/decisions/` and `CONTEXT.md`
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

- **GIVEN** a repository whose section carries `section-version: 1.0.0`
- **WHEN** the initializer is re-run
- **THEN** the section SHALL name the decision home
- **AND** no byte outside the markers SHALL change

