## ADDED Requirements

### Requirement: A repository carries its truth and nothing more

A repository that uses this workflow SHALL carry exactly two workflow artifacts:
an `openspec/` directory, and one instruction file. Both SHALL be committed.

It SHALL NOT carry **any artifact this workflow publishes** — skills, hooks, hook
shims, host settings written by this workflow, workflow configuration files, or
command definitions. Those are machine-level and are established by `install.sh`.

**The prohibition is scoped by publisher, not by file type.** Artifacts another
tool installs per-project remain that tool's business: the `openspec-*` skills are
written by the `openspec` CLI, are required for its commands to resolve, and are
neither published nor swept by this workflow. A rule phrased as "no skills in a
repository" would order the deletion of files this workflow does not own and
whose removal breaks the CLI the rest of this capability depends on.

#### Scenario: A repository carries skills installed by another tool

- **WHEN** a repository carries the `openspec-*` skills written by the `openspec`
  CLI
- **THEN** they are not a violation of this requirement, because this workflow
  neither publishes nor removes them

The division is what makes a fresh clone work: the repository carries what is
true *about this repository*, which no other machine can supply, and the machine
carries how to work, which no repository should duplicate. A repository that
carried behaviour would carry a version of it, and versions in repositories are
the drift this workflow spent its history removing.

#### Scenario: A repository is cloned onto a machine with the workflow installed

- **WHEN** a repository carrying `openspec/` and its instruction file is cloned
  onto a machine where the skill resolves for the host in use, the enforcement
  floor is effective for that clone, and `openspec` is present
- **THEN** the workflow is usable with no further per-repository step
- **AND** the condition is those three effects, not the fact that `install.sh`
  exited zero — an install can complete with `openspec` missing, with a host's
  binding unconfirmed, and a clone can set `core.hooksPath` locally and bypass a
  floor that is otherwise active

#### Scenario: The machine is equipped but the clone bypasses the floor

- **WHEN** a cloned repository configures its own hooks path, so the machine-level
  floor does not apply to it
- **THEN** this SHALL be reported as the clone's condition rather than counted as
  a satisfied fresh-clone claim

#### Scenario: A repository is cloned onto a machine without the workflow

- **WHEN** the same repository is cloned where the workflow is not installed
- **THEN** `openspec/` remains readable as the repository's specification, and the
  absence of enforcement is the machine's condition rather than the repository's

#### Scenario: A workflow artifact is found in a repository

- **WHEN** a repository holds a skill, hook, shim, or workflow configuration file
  this workflow publishes
- **THEN** the initializer's check mode SHALL name it and the file it duplicates,
  because it is a copy of something the machine already provides
- **AND** the check mode SHALL be the named reporter, so this is verifiable
  against an implementation rather than an obligation with no holder

### Requirement: The instruction file is one file under two names

A repository's instruction file SHALL be `AGENTS.md`, with `CLAUDE.md` a symlink
to it. Where either already exists as a regular file, the workflow's section
SHALL be appended behind the markers `host-neutral-instruction-files` makes
normative — never a marker of this capability's own — and the existing content
SHALL be preserved.

**Every starting state is defined, because the interesting ones are the states
that can silently produce two real files.** Appending to an existing `CLAUDE.md`
and separately creating `AGENTS.md` is the obvious implementation and it is
forbidden: it produces exactly the two divergent copies this requirement exists
to prevent.

Symlinks are assumed to work. This workflow runs on one machine, and a
filesystem without symlinks would require a two-real-file fallback — reintroducing
the failure mode deliberately, for a platform with no user here. If that changes,
it is a new decision and not a fallback smuggled in as robustness.

`AGENTS.md` is the cross-host surface — codex, opencode, pi and omp all read it.
Claude reads `CLAUDE.md`. Two real files would be two versions of one rule, which
is the failure this workflow names everywhere else; a symlink makes them the same
bytes by construction. Core already does this with its own `AGENTS.md`.

#### Scenario: Neither file exists

- **WHEN** the initializer runs in a repository with no instruction file
- **THEN** `AGENTS.md` is created and `CLAUDE.md` is created as a symlink to it

#### Scenario: Only `AGENTS.md` exists

- **WHEN** `AGENTS.md` exists as a regular file with content and `CLAUDE.md` does
  not exist
- **THEN** the workflow's section is appended to `AGENTS.md` behind the normative
  markers, `CLAUDE.md` is created as a symlink to it, and no existing line is
  removed or rewritten

#### Scenario: Only `CLAUDE.md` exists

- **WHEN** `CLAUDE.md` exists as a regular file with content and `AGENTS.md` does
  not exist
- **THEN** its content SHALL become `AGENTS.md`, and `CLAUDE.md` SHALL be replaced
  by a symlink to it, preserving every existing line
- **AND** the initializer SHALL NOT append to `CLAUDE.md` while creating a
  separate `AGENTS.md`, because that produces the two real files this requirement
  exists to prevent
- **AND** the operator SHALL be told that content previously read only by Claude
  is now read by every host that reads `AGENTS.md`, because that is a disclosure,
  not a rename

#### Scenario: Both exist as separate regular files and differ

- **WHEN** both exist independently and their contents differ
- **THEN** the initializer SHALL report the divergence and SHALL NOT silently
  choose one, because collapsing them is a decision about which rule survives

#### Scenario: Both exist as separate regular files and are identical

- **WHEN** both exist independently with byte-identical content
- **THEN** `AGENTS.md` is kept and `CLAUDE.md` is replaced by a symlink to it,
  because there is no rule to choose between and no content to lose

#### Scenario: `CLAUDE.md` is already a symlink to something else

- **WHEN** `CLAUDE.md` is a symlink whose target is not the repository's
  `AGENTS.md`
- **THEN** the initializer SHALL refuse and report the target, and SHALL NOT
  rewrite the link
- **AND** it SHALL NOT follow the link to write through it, because the target may
  lie outside the repository

#### Scenario: An instruction path is a directory or a dangling link

- **WHEN** either name exists as a directory, or as a symlink with no target
- **THEN** the initializer SHALL refuse and report what it found, changing nothing

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

#### Scenario: `openspec` is not installed

- **WHEN** the initializer runs on a machine where `openspec` is unavailable
- **THEN** it SHALL refuse before writing anything, and SHALL name `openspec` as
  the missing prerequisite
- **AND** this state is reachable by design: the same change declares `openspec` a
  *reported*, non-blocking prerequisite of `install.sh`, so "installed
  successfully, `openspec` absent" is a state the machine can be in

#### Scenario: The initializer is run from a subdirectory

- **WHEN** it is invoked below the repository root
- **THEN** it SHALL resolve the root and write there, or refuse if there is no
  repository, and SHALL NOT create a second `openspec/` beside the first

#### Scenario: A step fails part-way through

- **WHEN** any write fails after another has succeeded
- **THEN** the initializer SHALL report what was written and what was not
- **AND** SHALL check every target before writing any of them, so the common
  refusals happen before the first change rather than half-way through

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

**The sweep is a distinct operation from the initializer and SHALL be named as
one.** The initializer writes two artifacts and removes nothing; the sweep
removes. Folding removal into the initializer would break its "does only what
this capability names" and "short enough to be read" requirements, so they are
two things with two names.

**The sweep SHALL remove only from an exact manifest of artifacts this workflow
published**, and SHALL refuse rather than delete when it meets anything else. It
SHALL refuse on a repository whose worktree is not clean. It SHALL operate on an
enumerated list of repositories, never on a directory glob.

Ownership has to be proven because the rollback does not cover the alternative:
`git revert` restores committed files, and it restores nothing that was untracked
or locally modified. A sweep that deleted a directory wholesale would be
irreversible for exactly the files nobody had committed yet. The enumeration
matters for the same reason in a different direction — a glob over the family
directory would reach `agenticapps-dashboard-add-agent-board`, a stray worktree
with its own gate whose disposition is undecided.

Rollback SHALL be `git revert` of **one commit per repository**, which the sweep
SHALL produce. No copy of the removed files SHALL be retained in the repository —
they are committed, so history already holds them, and a retained copy is the
duplication this workflow removes.

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
- **AND** the precondition SHALL be checked by observing the effect on this
  machine — the skill resolving, and the floor being active for this repository —
  never by inspecting whether a change in core's history has been merged, which
  is a fact about a different repository than the one being swept

#### Scenario: The sweep meets a file it does not own

- **WHEN** a path scheduled for removal holds content outside the manifest of
  artifacts this workflow published
- **THEN** the sweep SHALL refuse for that repository and report the path,
  because removal is justified by ownership and nothing else

#### Scenario: The sweep meets uncommitted work

- **WHEN** the repository's worktree is not clean
- **THEN** the sweep SHALL refuse, because `git revert` cannot restore untracked
  or modified files and the rollback would be a false promise

#### Scenario: The sweep is pointed at a set of repositories

- **WHEN** the sweep runs across the fleet
- **THEN** it SHALL act on an enumerated list, and a repository absent from that
  list SHALL NOT be swept because it happened to be found on disk

#### Scenario: An operator wants the previous state back

- **WHEN** a swept repository must be restored
- **THEN** `git revert` of the sweep commit SHALL restore it, with no archived
  copy consulted
