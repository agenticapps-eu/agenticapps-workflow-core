## ADDED Requirements

### Requirement: A project does not carry its own copy of a core-owned skill

A repository that consumes this workflow SHALL NOT hold, in
`.claude/skills/` or any other project-local skill directory, a copy of a skill
that core publishes from `skills/`. It obtains that skill from the host binding,
which reaches every directory on the machine.

Core-owned is the criterion, and it is decided by a name appearing in core's
`skills/`, not by resemblance. A project may hold skills core does not publish —
upstream tools install their own, and `openspec-*` is the case that exists today:
MIT-licensed, declaring "Requires openspec CLI", installed per-project by that
tool. Deleting those would break the commands they implement. This requirement
governs core's payload and nothing else.

The reason is not tidiness. A project-local skill resolves ahead of the host one,
so a copy does not sit harmlessly beside the published skill — it replaces it,
silently, for every agent working in that repository. Eight repositories carried
copies at four byte-sizes across two claimed versions while core published a
ninth, which is what "which one loads is down to loader ordering" looks like when
it is measured instead of argued about.

#### Scenario: A project holds a copy of a published skill

- **WHEN** a project-local skill directory holds an entry whose name core
  publishes from `skills/`
- **THEN** the condition is reported, naming the repository and the skill
- **AND** it is treated as a defect rather than an accepted local override

#### Scenario: A project holds a skill core does not publish

- **WHEN** a project-local skill directory holds an entry whose name core does
  not publish
- **THEN** it is left alone and is not reported

**Precedence SHALL be measured before anything is deleted, not assumed.** The
claim that a project resolves the host-bound skill once its copy is gone has
never been observed on this machine — it is inferred from the copy resolving
*first*, which is a different fact. No removal SHALL occur until it is measured
in one repository, and the measurement SHALL be recorded.

The premise that "every host reads a directory the installer binds" is
additionally **false as stated**: pi reads `~/.pi/agent/skills`, which is
neither bound by the installer nor swept, and is measured empty. A deletion that
assumes otherwise could leave pi resolving nothing at all in that repository.
Either the directory is bound before the sweep, or this requirement is scoped to
the hosts where the binding is verified.

#### Scenario: Precedence is measured before the first removal

- **WHEN** a removal is proposed in any repository
- **THEN** the host binding is first shown to resolve in a repository whose copy
  has been removed
- **AND** the measurement is recorded
- **AND** no further removal proceeds if it fails

#### Scenario: A project resolves the workflow skill after its copy is removed

- **WHEN** a project's copy of a core-published skill has been removed, on a host
  whose skill directory the installer binds
- **THEN** work in that project resolves the host-bound skill
- **AND** no project-local file is written to replace it

#### Scenario: A host reads a directory the installer does not bind

- **WHEN** a host resolves skills from a directory outside the bound set
- **THEN** removing a project's copy SHALL NOT be described as covered for that
  host
- **AND** the condition is reported rather than left to be discovered

#### Scenario: A project skill shares a name with a core skill but is not a copy

- **WHEN** a project-local skill has the same name as one core publishes but was
  independently authored
- **THEN** the condition is reported as a name collision rather than as a copy
- **AND** the report distinguishes the two, because deleting an independently
  authored skill on a name match destroys work rather than collapsing a duplicate

### Requirement: The fleet is checked from a declaration that cannot shrink

The set of repositories checked SHALL be read from a declaration in this
repository, and a repository named there that cannot be resolved SHALL be
reported rather than skipped.

This is the rule `project-hook-binding` already applies to hooks, for the reason
`ARTIFACTS` and `FLEET` state at length: an expected set discovered from what you
happen to find cannot detect a missing member. A check that enumerates the
directories it can see would pass a machine where a repository was never cloned,
and pass it for the same reason it passes a clean one.

The declaration SHALL be the existing `FLEET` file where the repository is
already named there. A repository carrying a copy but absent from `FLEET` is a
gap in the declaration and SHALL be added to it rather than special-cased in the
check.

**A linked worktree SHALL be checked in its own right and SHALL NOT be treated
as covered by its parent repository.** A worktree has its own working tree and
can sit on a branch that still carries the copy, so cleaning the main checkout
changes nothing about it — and a check that resolves only the first directory
matching a repository name reports clean while the stale copy still loads.
`agenticapps-dashboard-add-agent-board` is the live case: a worktree of a
retired repository, carrying the oldest copy on the machine at 415 lines and
v3.0.0.

**A declaration entry SHALL be removable.** `FLEET` names
`agenticapps-dashboard`, which is retired; when its checkout is eventually
deleted, "report, never skip" would fail the check permanently. Removing a name
is a legitimate edit and SHALL be possible with a recorded reason, exactly as
adding one is.

#### Scenario: A declared repository cannot be resolved

- **WHEN** the check runs against a root where a declared repository is absent
- **THEN** that repository is reported as unresolved
- **AND** the check does not report success for it

#### Scenario: A declared repository has a linked worktree

- **WHEN** a declared repository has a linked worktree holding a copy
- **THEN** the worktree is reported in its own right
- **AND** cleaning the main checkout SHALL NOT report the worktree as clean

#### Scenario: A declared repository is retired and its checkout removed

- **WHEN** a name is removed from the declaration with a recorded reason
- **THEN** the check does not report it as unresolved
- **AND** the removal is distinguishable from a repository that went missing

#### Scenario: Every declared repository is clean

- **WHEN** no declared repository holds a copy of a core-published skill
- **THEN** the check exits zero
- **AND** it states which root it examined, because the result is a statement
  about the trees checked out there and not about the fleet in general

### Requirement: A removal is not silent about what it removed

Removing a project's copy SHALL record what was removed and what now serves it:
the skill name, the version the copy claimed, and the version the host binding
resolves.

**The record SHALL name its artifact**, because "the removal states" is not
testable without one: it is the body of the commit that performs the removal, in
the repository the copy was removed from. Not a changelog, not a review file,
not core's own history — the reader who needs it is the next person in *that*
repository running `git log` on a directory that is no longer there.

A copy that is deleted with a one-line commit message leaves the next reader
unable to tell whether a capability was withdrawn or a duplicate was collapsed.
Four of the eight copies claimed `v3.2.0` and one of those four differed from the
others; a removal record that says only "remove vendored skill" loses the fact
that the four were never the same file.

#### Scenario: A copy is removed from a repository

- **WHEN** a project's copy of a core-published skill is removed
- **THEN** the removal states the skill, the claimed version of the copy, and the
  version now resolved from the host binding
