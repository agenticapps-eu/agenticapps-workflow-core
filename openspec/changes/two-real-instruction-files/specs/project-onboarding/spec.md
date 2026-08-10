## MODIFIED Requirements

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

#### Scenario: Only CLAUDE.md exists

- **GIVEN** a repository carrying a `CLAUDE.md` and no `AGENTS.md`
- **WHEN** the initializer runs
- **THEN** `CLAUDE.md` SHALL remain at its own path, and no line of it SHALL be
  removed or reordered
- **AND** the workflow section is inserted behind the normative markers
- **AND** `AGENTS.md` is created holding the same content
- **AND** neither name is a symlink

#### Scenario: Only AGENTS.md exists

- **GIVEN** a repository carrying an `AGENTS.md` and no `CLAUDE.md`
- **WHEN** the initializer runs
- **THEN** the workflow section is inserted behind the normative markers,
  preserving every existing line
- **AND** `CLAUDE.md` is created holding the same content

#### Scenario: Both exist as regular files with identical content

- **GIVEN** both names present, byte-identical
- **WHEN** the initializer runs
- **THEN** the workflow section is inserted or updated in both
- **AND** they remain byte-identical

#### Scenario: Both exist as regular files and differ

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

#### Scenario: A name is a symlink pointing outside the repository

- **GIVEN** `AGENTS.md` or `CLAUDE.md` is a symlink whose target is not the
  other name
- **WHEN** the initializer runs
- **THEN** it SHALL exit non-zero, naming the target
- **AND** it SHALL NOT follow the link to write through it, because the target
  may lie outside the worktree
