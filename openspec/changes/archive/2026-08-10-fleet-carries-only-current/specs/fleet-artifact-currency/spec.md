## ADDED Requirements

### Requirement: A removed tool declares the artifacts it owns

A change that removes a tool SHALL record, in a declaration that outlives the
change, the paths and patterns that tool owned. The declaration SHALL name the
tool, the date it was removed, and each owned path; it SHALL be append-only, so
that forgetting an entry is visible as an absence rather than achieved by an
edit.

Every other requirement here depends on this one. "Remove the artifacts of a
removed tool" is not implementable from the tool's name: a name cannot tell you
that GSD owned `setup-gstack-gsd-superpowers-workflow.md` but not
`backend-foundation.md`, and a check built on name-matching either misses
artifacts whose names never mentioned the tool or deletes files that merely
share a word with it. The declaration is what makes the invariant decidable, and
it is the same shape as `ARTIFACTS` and `SHIMMED-HOOKS`, which already work.

A path MAY be claimed by a tool and still be preserved in a specific repository
— see the preservation requirement below. Declaring ownership states what the
artifact *is*; it does not by itself order a deletion.

#### Scenario: A tool is removed

- **WHEN** a change removes a tool from the workflow
- **THEN** the declaration gains an entry naming that tool, its removal date and
  every path or pattern it owned
- **AND** the change is not complete while the entry is absent

#### Scenario: An artifact matches no declared owner

- **WHEN** a repository holds a file that resembles a removed tool's artifact but
  matches no declared path
- **THEN** it SHALL NOT be deleted on resemblance
- **AND** the condition SHALL be reported so the declaration can be corrected

#### Scenario: A declared path is claimed by two tools

- **WHEN** the same path appears under more than one tool's entry
- **THEN** the condition SHALL be reported naming both entries
- **AND** the entries SHALL NOT be silently merged, since their removal dates and
  dispositions may differ

### Requirement: A declared repository holds no artifact of a removed tool

Every repository in `FLEET` SHALL hold no file matching a declared removed
tool's owned paths, except where that repository carries a recorded preservation
entry for it. The condition SHALL be checkable against repository contents
alone.

This is stated as a property of the repositories rather than of a release,
because a property of a release is not observable. An earlier revision required
that a removal "SHALL NOT be described as a removal" if incomplete and "SHALL
NOT be separated across releases" — both constrain commit messages and release
timing, which no scenario can verify against a working tree. What is verifiable
is whether the file is there.

The reason it matters is not tidiness. An artifact that is still checked out is
still loadable: a slash command is invocable, an instruction fragment is
readable, a hook shim is executable. "Removed" describes the intent, the
repositories describe the behaviour, and an agent reads the repositories.

Measured 2026-08-08 across the repositories carrying `openspec/`: a
`setup-gstack-gsd-superpowers-workflow` command still offers to install GSD,
`workflow-config.md` still describes a workflow that predates OpenSpec, and ten
repositories still carry a `.planning/` directory.

#### Scenario: A declared repository retains a removed tool's artifact

- **WHEN** a repository in `FLEET` holds a file matching a declared owned path
- **AND** that repository carries no preservation entry for it
- **THEN** the condition SHALL be reported, naming the repository, the artifact
  and the tool that owned it
- **AND** it SHALL be treated as an incomplete removal rather than local
  preference

#### Scenario: The fleet is clean

- **WHEN** no repository in `FLEET` holds an undeclared match
- **THEN** the check SHALL report the fleet clean
- **AND** the report SHALL name the root it examined, since a clean result over
  the wrong root is indistinguishable from a clean fleet

#### Scenario: A linked worktree of a declared repository

- **WHEN** a declared repository has linked worktrees
- **THEN** each worktree SHALL be checked independently
- **AND** an artifact present in a worktree SHALL be reported even when the
  primary checkout is clean, because a worktree is a directory an agent opens

### Requirement: A repository may preserve an artifact, and the reason is recorded

A repository MAY retain an artifact of a removed tool where that artifact is
also that repository's own source code or its own history. Such a retention
SHALL be recorded as a preservation entry naming the repository, the path and
the reason, and a recorded entry SHALL satisfy the invariant above rather than
violating it.

Without this, the invariant is unsatisfiable by construction. A repository that
was *built on* a removed tool holds that tool's artifacts as its own product —
sweeping them is not removing residue, it is gutting the thing being preserved.
A check with no exception category must then either fail forever or be silently
ignored, and an invariant everyone has learned to ignore is worse than none.

The category is normative rather than a list, because the repositories that need
it are not knowable in advance. `agenticapps-roadmap` was the case that made
this concrete — a product whose source walked sibling repositories' `.planning/`
trees — and its checkout was deleted on 2026-08-07, which is exactly why the
exception must be a category and not that repository's name.

#### Scenario: A preserved artifact is present

- **WHEN** a repository holds a declared artifact covered by a preservation entry
- **THEN** the check SHALL NOT report it as an incomplete removal
- **AND** the entry's reason SHALL be reported alongside it, so a preservation
  nobody would defend is visible rather than silent

#### Scenario: A preservation entry names a path that is gone

- **WHEN** a preservation entry names a path no longer present
- **THEN** the stale entry SHALL be reported
- **AND** it SHALL NOT be removed automatically, since the disappearance may be
  the loss the entry existed to prevent

### Requirement: A multi-repository removal has a sanctioned intermediate state

A removal that spans repositories SHALL define when it is complete, and the
check SHALL distinguish a removal in progress from an incomplete one. A tool
whose entry is declared but whose sweep has not reached every repository SHALL
be reported as in progress, naming the repositories still holding the artifact
and the ones already swept.

One PR per repository is the safe way to land this and it guarantees a window in
which some repositories are swept and others are not. Without a sanctioned
intermediate state, every run during that window reports a violation, and a
check that cries violation for a week trains its reader to ignore it.

Completion is a property of the set: the removal is complete when every declared
repository either holds no match or holds a preservation entry.

#### Scenario: A sweep is partly landed

- **WHEN** some declared repositories have been swept and others have not
- **THEN** the check SHALL report the removal in progress with both counts
- **AND** SHALL NOT report it complete

#### Scenario: The last repository is swept

- **WHEN** the final declared repository holding a match is swept
- **THEN** the removal SHALL be reported complete
- **AND** completion SHALL be derived from repository contents, not from a
  release note or a commit message

### Requirement: Instruction text is removed only against its replacement

Removing a rule from a repository's instruction file SHALL be justified by
showing where the rule now lives, and the removal SHALL quote or reference the
replacement rather than assert it exists. A rule with no identified replacement
SHALL be left in place and reported.

The `## Coding Discipline` section is inlined in several repositories'
`CLAUDE.md`, roughly eighty lines each, and the trigger skill was written to
absorb §11 so those copies could go. That is the intent; the evidence that a
rule survives its deletion is that some file still says it. Core's own
`CLAUDE.md` carried this reasoning about itself until 2026-08-08, keeping a
misplaced workflow section "only until the rewritten trigger skill carries it,
because deleting a rule that has no other home deletes the rule" — and it was
cut on the day the skill demonstrably carried it, which is the procedure this
requirement generalises.

#### Scenario: A rule is removed from an instruction file

- **WHEN** a change removes a rule from a repository's instruction file
- **THEN** it identifies the artifact that now carries that rule
- **AND** a rule with no identified replacement is left in place and reported

#### Scenario: The replacement carries only part of the rule

- **WHEN** the named replacement covers some of a section's rules and not others
- **THEN** only the covered rules SHALL be removed
- **AND** the uncovered rules SHALL remain, with the partial coverage reported
  rather than rounded up to full coverage

#### Scenario: The replacement does not load in that repository

- **WHEN** the named replacement is a skill or file that is not reachable from
  the repository whose instruction text is being cut
- **THEN** the removal SHALL NOT proceed for that repository
- **AND** the unreachability SHALL be reported, because a replacement that does
  not load is indistinguishable from no replacement
