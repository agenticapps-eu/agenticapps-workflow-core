# project-onboarding Specification

## Purpose
TBD - created by archiving change fresh-clone-needs-nothing. Update Purpose after archive.
## Requirements
### Requirement: A repository carries its truth and nothing more

A repository that uses this workflow SHALL carry exactly two workflow artifacts:
an `openspec/` directory, and one instruction file. Both SHALL be committed.

It SHALL NOT carry **any artifact this workflow publishes** — skills, hooks, hook
shims, host settings written by this workflow, workflow configuration files, or
command definitions. Those are machine-level and are established by `install.sh`.

**This includes the `openspec` CLI's own per-project files.** `openspec init
--tools <host>` writes six skills, and for most hosts a set of commands, into the
repository — it is a per-project agent installer, and it is the last thing still
putting behaviour in a repository. `workflow-installation` binds those files
machine-level instead, and the initializer passes `--tools none`, so a repository
receives none of them and `/opsx:*` resolves from the machine.

An earlier revision of this requirement kept them, on the grounds that another
tool owns them and deleting them breaks `/opsx:*`. Ownership was the right test
and the wrong conclusion: it left new repositories, which never receive them, and
swept repositories, which kept them, in two different shapes — the drift this
capability exists to end.

#### Scenario: A repository carries the openspec CLI's per-host files

- **WHEN** a repository carries `openspec-*` skills or `opsx` command files
- **THEN** they are removed with everything else, because the machine-level
  binding provides them
- **AND** `/opsx:*` SHALL still resolve in that repository afterwards

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

A repository's instruction file SHALL exist under both names, `AGENTS.md` and
`CLAUDE.md`, as **regular files with byte-identical content**. Neither SHALL be
a symlink. Where either already exists, the workflow's section SHALL be inserted
or updated behind the markers `host-neutral-instruction-files` makes normative —
never a marker of this capability's own — and every existing line SHALL be
preserved.

The initializer's only write to these files is **between the markers**. It SHALL
NOT move, replace, link or delete either name. Where one name is absent it SHALL
be created containing the block; where both are absent both SHALL be created.
After writing, the two names SHALL hold identical content.

**Every starting state is defined, because the interesting ones are the states
that can silently produce two different files.** Appending to an existing
`CLAUDE.md` while leaving `AGENTS.md` untouched is the obvious implementation
and it is forbidden: it produces the two divergent copies this requirement
exists to prevent.

The previous revision made `CLAUDE.md` a symlink to `AGENTS.md`, and gave the
reason that "two real files would be two versions of one rule… a symlink makes
them the same bytes by construction". That guarantee was real. It was bought at
the price of a mechanism that owns the whole file in order to deliver an
eight-line pointer — measured at 5% of cparx's instruction file and 0% of
callbot's — and on 2026-08-10 that disproportion turned a guard defect into
22,292 bytes of lost content across two repositories.

Identity is now established by enforcement rather than by construction, and the
requirement below carries it. Three costs go with the link and are the rest of
the reason: git stores the target path rather than the content, so anything
reading the object store sees `AGENTS.md` where the instructions should be;
Windows checks a link out as a one-line text file unless developer mode is on;
and adoption cannot be additive, because a repository holding only `CLAUDE.md`
has that file relocated and its readership widened from Claude to every host.

That prior revision required this to be a deliberate decision — "if that
changes, it is a new decision and not a fallback smuggled in as robustness".
This is that decision, taken for the blast radius and not for portability.

#### Scenario: Neither file exists

- **WHEN** the initializer runs in a repository with no instruction file
- **THEN** `AGENTS.md` and `CLAUDE.md` are both created as regular files
- **AND** each contains the workflow section behind the normative markers
- **AND** the two are byte-identical

#### Scenario: Only `CLAUDE.md` exists

- **GIVEN** a repository carrying a `CLAUDE.md` and no `AGENTS.md`
- **WHEN** the initializer runs
- **THEN** `CLAUDE.md` SHALL remain at its own path, and no line of it SHALL be
  removed or reordered
- **AND** the workflow section is inserted behind the normative markers
- **AND** `AGENTS.md` is created holding the same content
- **AND** neither name is a symlink

#### Scenario: Only `AGENTS.md` exists

- **GIVEN** a repository carrying an `AGENTS.md` and no `CLAUDE.md`
- **WHEN** the initializer runs
- **THEN** the workflow section is inserted behind the normative markers,
  preserving every existing line
- **AND** `CLAUDE.md` is created holding the same content

#### Scenario: Both exist as separate regular files and are identical

- **GIVEN** both names present, byte-identical
- **WHEN** the initializer runs
- **THEN** the workflow section is inserted or updated in both
- **AND** they remain byte-identical

#### Scenario: Both exist as separate regular files and differ

- **GIVEN** both names present with differing content
- **WHEN** the initializer runs
- **THEN** it SHALL exit non-zero and write nothing
- **AND** it SHALL report that reconciling them decides which rule survives,
  which is the operator's decision and not the tool's

#### Scenario: One name is a symlink to the other

- **GIVEN** a repository carrying the previous arrangement, in either direction
- **WHEN** the initializer runs
- **THEN** it SHALL exit non-zero and write nothing
- **AND** it SHALL report which name is the link and that replacing it with a
  copy of the content is the migration step

Refused rather than migrated in place. Replacing a link with content is a
one-time, per-repository act that belongs in a reviewable commit, not in a
scaffolder run that an operator may not be watching.

#### Scenario: `CLAUDE.md` is already a symlink to something else

- **GIVEN** either name — the header keeps `CLAUDE.md` because that is where
  this state was first met, but the rule is symmetric — is a symlink whose
  target is not the other name
- **WHEN** the initializer runs
- **THEN** it SHALL exit non-zero, naming the target
- **AND** it SHALL NOT follow the link to write through it, because the target
  may lie outside the worktree

#### Scenario: An instruction path is a directory or a dangling link

- **WHEN** either name exists as a directory, or as a symlink with no target
- **THEN** the initializer SHALL refuse and report what it found, changing nothing
- **AND** the same SHALL hold for any other name that is not a regular file — a
  FIFO, a socket, a device — because the writer reads the existing file to build
  the new content, and a read of a FIFO blocks until a writer appears

Refusing a scaffolder is a worse outcome than success and a far better one than
a scaffolder that never returns.

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

