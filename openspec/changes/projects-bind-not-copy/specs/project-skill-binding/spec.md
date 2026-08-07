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

#### Scenario: A project resolves the workflow skill after its copy is removed

- **WHEN** a project's copy of a core-published skill has been removed
- **THEN** work in that project resolves the host-bound skill
- **AND** no project-local file is written to replace it

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

#### Scenario: A declared repository cannot be resolved

- **WHEN** the check runs against a root where a declared repository is absent
- **THEN** that repository is reported as unresolved
- **AND** the check does not report success for it

#### Scenario: Every declared repository is clean

- **WHEN** no declared repository holds a copy of a core-published skill
- **THEN** the check exits zero
- **AND** it states which root it examined, because the result is a statement
  about the trees checked out there and not about the fleet in general

### Requirement: A removal is not silent about what it removed

Removing a project's copy SHALL record what was removed and what now serves it:
the skill name, the version the copy claimed, and the version the host binding
resolves.

A copy that is deleted with a one-line commit message leaves the next reader
unable to tell whether a capability was withdrawn or a duplicate was collapsed.
Four of the eight copies claimed `v3.2.0` and one of those four differed from the
others; a removal record that says only "remove vendored skill" loses the fact
that the four were never the same file.

#### Scenario: A copy is removed from a repository

- **WHEN** a project's copy of a core-published skill is removed
- **THEN** the removal states the skill, the claimed version of the copy, and the
  version now resolved from the host binding
