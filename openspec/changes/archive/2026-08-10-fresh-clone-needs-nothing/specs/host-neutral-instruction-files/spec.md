## MODIFIED Requirements

### Requirement: The Claude instruction file is out of scope

`CLAUDE.md` SHALL NOT be subject to these requirements **while it is a regular
file that Claude alone reads**.

Where `CLAUDE.md` is a symlink to the shared instruction file, it is not a second
file and this carve-out does not apply: every requirement in this capability
governs those bytes, because they are the shared file's bytes. Markers, the
`agents:` frontmatter and the section version apply exactly once, to the one file
under both names.

The original reason for the carve-out was that "Claude is its only reader, so
there is no second agent to coordinate with and nothing to deduplicate". A
symlink inverts that premise rather than satisfying it: the file Claude reads
becomes the file codex, opencode, pi and omp read. Left unamended, this
capability would exempt from its own marker and frontmatter rules the very bytes
those rules exist to govern — and it would do so through a name, not through a
property of the content.

#### Scenario: Claude-only project

- **WHEN** a repo is provisioned for Claude alone and `CLAUDE.md` is a regular file
- **THEN** no requirement in this capability applies to it
- **AND** the absence of markers in `CLAUDE.md` SHALL NOT be reported as a
  violation

#### Scenario: `CLAUDE.md` is a symlink to the shared file

- **WHEN** `CLAUDE.md` resolves to the shared instruction file
- **THEN** every requirement in this capability applies to the resolved file
- **AND** the requirements SHALL be evaluated once, against the resolved path,
  rather than once per name

#### Scenario: Tooling counts instruction files

- **WHEN** tooling enumerates instruction files to check or repair them
- **THEN** it SHALL resolve symlinks first, so one file under two names is
  processed once
- **AND** SHALL NOT report the second name as a duplicate section

### Requirement: The shared instruction file is delimited and machine-removable

The workflow section SHALL be enclosed in begin and end markers so that it can
be located and removed without reading its prose. The markers SHALL be exactly:

```
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
<!-- END: agentic-apps-workflow sections -->
```

The literal strings are normative. A contract whose whole purpose is to be
machine-checkable by a host repo without core executing it cannot leave the one
string that detection depends on to a design narrative — a host implementing
from this requirement alone would have to invent it, and two hosts inventing
separately is the duplication this capability exists to prevent.

This is not a new marker. All three live host templates already write exactly
this, which is why hosts collide in one file: the name is shared and none of
them looks for it first.

**Any writer of the workflow section SHALL use these markers**, including the
project initializer. There is no second provenance convention. An initializer
that invented its own marker would produce a section this capability's tooling
cannot find, which is the failure the literal strings exist to prevent — and it
would be a second convention for one thing, in a workflow whose entire subject
is that one thing should have one home.

Removing the two host blocks from `factiv/cparx` was mechanical only because
those hosts happened to write markers. Nothing required it, so nothing
guaranteed it for the next host.

#### Scenario: Locating the section

- **WHEN** tooling needs to find the workflow section
- **THEN** it SHALL locate it by its markers alone
- **AND** SHALL NOT depend on any heading text, ordering, or wording inside the
  section

#### Scenario: Content outside the markers is preserved

- **WHEN** the workflow section is removed from a shared instruction file that
  also carries unrelated content
- **THEN** every byte outside the markers SHALL be unchanged

#### Scenario: The initializer writes the workflow section

- **WHEN** the project initializer appends the workflow section to an existing
  instruction file
- **THEN** it SHALL enclose it in exactly these markers
- **AND** SHALL treat their presence as the signal that the section is already
  written, rather than defining a marker of its own
