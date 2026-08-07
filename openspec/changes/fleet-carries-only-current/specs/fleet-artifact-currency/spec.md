## ADDED Requirements

### Requirement: Removing a tool includes removing its artifacts from the fleet

When the workflow removes a tool, the change that removes it SHALL also remove
that tool's artifacts from every repository declared in `FLEET`, and the two
SHALL NOT be separated across releases. A removal that lands only in core is
incomplete, and SHALL NOT be described as a removal.

Three removals have already demonstrated the failure. GSD and GitNexus were
removed on 2026-07-28, `.planning/` fleet-wide on 2026-08-05, and the
wiki-builder on 2026-07-28. Each landed in core and in the global instruction
file. None reached the repositories, so a `setup-gstack-gsd-superpowers-workflow`
command still offers to install GSD, `.planning/` still exists in nine
repositories, and `workflow-config.md` still describes a workflow that predates
OpenSpec.

The reason this matters is not tidiness. An artifact that is still checked out is
still loadable: a slash command is invocable, an instruction fragment is
readable, a hook shim is executable. "Removed" describes the intent and the
repositories describe the behaviour, and an agent reads the repositories.

#### Scenario: A tool is removed from the workflow

- **WHEN** a change removes a tool
- **THEN** it also removes that tool's artifacts from every declared repository
- **AND** the removal is not reported complete while any declared repository
  retains one

#### Scenario: A declared repository retains a removed tool's artifact

- **WHEN** a repository holds a command, skill, hook, configuration file or
  instruction fragment belonging to a removed tool
- **THEN** the condition is reported, naming the repository and the artifact
- **AND** it is treated as an incomplete removal rather than local preference

### Requirement: Tracked planning content is migrated, never swept

A sweep SHALL distinguish an untracked leftover from tracked content, and SHALL
NOT delete tracked content on the strength of a path name. Where a declared
repository's `.planning/` holds files under version control, the change SHALL
state what becomes of them — migrated to `openspec/`, or kept with a reason —
before anything is deleted.

`.planning/` was removed fleet-wide on 2026-08-05, and the path is now read as a
leftover. In `agenticapps-roadmap` it holds **134 tracked files**. A sweep that
matches on the directory name deletes a repository's planning history and reports
it as cleanup, and the commit message would be true about the path and false
about the content.

#### Scenario: A swept path holds tracked files

- **WHEN** a path targeted for removal holds files under version control
- **THEN** the sweep stops for that repository and reports the count
- **AND** deletion does not proceed until the change states their disposition

#### Scenario: A swept path holds only untracked files

- **WHEN** a path targeted for removal holds nothing under version control
- **THEN** it is removed and the removal is reported

### Requirement: Instruction text is removed only against its replacement

Removing a rule from a repository's instruction file SHALL be justified by
showing where the rule now lives, and the removal SHALL quote or reference the
replacement rather than assert it exists.

The `## Coding Discipline` section is inlined in eight repositories' `CLAUDE.md`,
roughly eighty lines each, and the trigger skill was written to absorb it so
those copies could go. That is the intent; the evidence that a rule survives its
deletion is that some file still says it. Core's own `CLAUDE.md` already carries
this reasoning in the other direction — a workflow section it calls misplaced is
kept "only until the rewritten trigger skill carries it, because deleting a rule
that has no other home deletes the rule."

#### Scenario: A rule is removed from an instruction file

- **WHEN** a change removes a rule from a repository's instruction file
- **THEN** it identifies the artifact that now carries that rule
- **AND** a rule with no identified replacement is left in place and reported
