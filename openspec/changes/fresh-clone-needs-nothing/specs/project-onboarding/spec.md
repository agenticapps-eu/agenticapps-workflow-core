## ADDED Requirements

### Requirement: A repository carries its truth and nothing more

A repository that uses this workflow SHALL carry exactly two workflow artifacts:
an `openspec/` directory, and one instruction file. Both SHALL be committed.

It SHALL NOT carry skills, hooks, hook shims, host settings written by this
workflow, workflow configuration files, or command definitions. Those are
machine-level and are established by `install.sh`.

The division is what makes a fresh clone work: the repository carries what is
true *about this repository*, which no other machine can supply, and the machine
carries how to work, which no repository should duplicate. A repository that
carried behaviour would carry a version of it, and versions in repositories are
the drift this workflow spent its history removing.

#### Scenario: A repository is cloned onto a machine with the workflow installed

- **WHEN** a repository carrying `openspec/` and its instruction file is cloned
  onto a machine where `install.sh` has run
- **THEN** the workflow is usable with no further per-repository step

#### Scenario: A repository is cloned onto a machine without the workflow

- **WHEN** the same repository is cloned where the workflow is not installed
- **THEN** `openspec/` remains readable as the repository's specification, and the
  absence of enforcement is the machine's condition rather than the repository's

#### Scenario: A workflow artifact is found in a repository

- **WHEN** a repository holds a skill, hook, shim, or workflow configuration file
  this workflow publishes
- **THEN** it is reported as a defect, because it is a copy of something the
  machine already provides

### Requirement: The instruction file is one file under two names

A repository's instruction file SHALL be `AGENTS.md`, with `CLAUDE.md` a symlink
to it. Where either already exists as a regular file, the workflow's section
SHALL be appended behind a provenance marker and the existing content SHALL be
preserved.

`AGENTS.md` is the cross-host surface — codex, opencode, pi and omp all read it.
Claude reads `CLAUDE.md`. Two real files would be two versions of one rule, which
is the failure this workflow names everywhere else; a symlink makes them the same
bytes by construction. Core already does this with its own `AGENTS.md`.

#### Scenario: Neither file exists

- **WHEN** the initializer runs in a repository with no instruction file
- **THEN** `AGENTS.md` is created and `CLAUDE.md` is created as a symlink to it

#### Scenario: An instruction file already exists

- **WHEN** `CLAUDE.md` or `AGENTS.md` exists as a regular file with content
- **THEN** the workflow's section is appended behind a provenance marker
- **AND** no existing line is removed or rewritten

#### Scenario: Both exist as separate regular files

- **WHEN** both exist independently and their contents differ
- **THEN** the initializer SHALL report the divergence and SHALL NOT silently
  choose one, because collapsing them is a decision about which rule survives

### Requirement: The initializer is idempotent and adds nothing on a second run

Running the initializer twice SHALL leave the repository as running it once did.
It SHALL NOT append its section a second time, re-create an existing symlink, or
re-initialize an existing `openspec/`.

#### Scenario: The initializer runs on an already-initialized repository

- **WHEN** it runs where `openspec/` and the instruction file already exist
- **THEN** it reports what it found, changes nothing, and exits zero

#### Scenario: The instruction file already carries the workflow section

- **WHEN** the provenance marker is present
- **THEN** the section is not appended again

### Requirement: The initializer is installed with the machine, never carried by the repository

The initializer SHALL be a published executable, installed by `install.sh` into
the shared bin directory through the same versioned install path as every other
published executable that is not a project hook, and SHALL be invoked from within
the repository it initializes.

It SHALL NOT be a file the repository carries. The first requirement in this
capability says a repository carries `openspec/` and one instruction file and no
executables, so an initializer living in the repository would be the first thing
the initializer is required to remove.

It SHALL NOT be a subcommand of the machine installer, which is documented as
putting the workflow on a *machine* and has no notion of a current repository.

The shared bin directory SHALL NOT be added to `PATH` by the installer, because
that means writing shell configuration and the installer writes none. Onboarding
SHALL therefore name the absolute path.

#### Scenario: The initializer is published

- **WHEN** `install.sh` runs
- **THEN** the initializer is published through the versioned install path with
  its own version-marker key, and a destination holding a strictly newer version
  is left intact and reported as satisfied

#### Scenario: An operator looks for the initializer after cloning a repository

- **WHEN** a repository is cloned onto a machine where `install.sh` has run
- **THEN** the initializer is already present on the machine, and the clone
  contains no copy of it

#### Scenario: The shared bin directory is not on PATH

- **WHEN** an operator invokes the initializer
- **THEN** the documented invocation is the absolute path, and the installer has
  modified no shell configuration to shorten it

### Requirement: Onboarding establishes the two local surfaces, and says so

Onboarding SHALL establish the surfaces `install.sh` establishes — bound skills
and the enforcement floor — and SHALL NOT generate a CI workflow file.

"A fresh clone needs nothing" is therefore a claim about those two surfaces. CI
is the third enforcement surface and the only one that survives a machine without
the workflow installed, which is precisely why it is not established here: it is
a per-repository choice about a forge, and this capability's first requirement
holds a repository to two artifacts. Stating the limit is the point — a claim
that quietly meant "two of three surfaces" would be read as covering all three.

#### Scenario: A repository is initialized

- **WHEN** the initializer runs
- **THEN** no CI workflow file is created, and the repository still carries
  exactly the two artifacts this capability names

#### Scenario: A repository wants enforcement that survives an unequipped machine

- **WHEN** a repository needs the workflow enforced where it is not installed
- **THEN** that is a CI configuration the repository owns, established
  separately, and its absence is not a defect in onboarding

### Requirement: The initializer is short enough to be read before it is trusted

The initializer SHALL do only what this capability names. It SHALL NOT write host
configuration, install hooks, publish artifacts, or contact the network.

`install.sh` carries this rule and the reason applies with more force here: this
runs inside someone's repository, against files they already own.

#### Scenario: The initializer is asked to do more

- **WHEN** a step would write host configuration, a hook, a skill, or a CI
  workflow file into the repository
- **THEN** it is not part of this initializer, and the capability is the reason

#### Scenario: An operator reads it before running it

- **WHEN** an operator opens the initializer to decide whether to trust it
- **THEN** its whole behaviour is apparent from reading it once

### Requirement: Existing repositories are swept once, not migrated through versions

A repository provisioned by a retired host scaffolder SHALL be brought to the
shape above by a single removal-and-write, not by a versioned chain.

There are no versions to walk. The four scaffolders that defined the chains are
archived, the end state is the two artifacts above, and a repository is either in
that shape or not. A chain exists to keep "what does v1.3.0 look like on disk"
single-sourced across many versions; one target state has no such problem.

Rollback SHALL be `git revert`. No copy of the removed files SHALL be retained in
the repository — they are committed, so history already holds them, and a
retained copy is the duplication this workflow removes.

#### Scenario: A repository provisioned by a retired scaffolder is swept

- **WHEN** the sweep runs on a repository carrying scaffolder-installed skills,
  hooks, and configuration
- **THEN** those are removed, `openspec/` is preserved, and the instruction file
  is written

#### Scenario: The sweep would remove protection nothing replaces

- **WHEN** the machine-level skill binding or enforcement floor is not yet in
  place
- **THEN** the sweep SHALL refuse, because removing a repository's hooks before
  the floor exists leaves it unprotected rather than differently protected

#### Scenario: An operator wants the previous state back

- **WHEN** a swept repository must be restored
- **THEN** `git revert` of the sweep commit SHALL restore it, with no archived
  copy consulted
