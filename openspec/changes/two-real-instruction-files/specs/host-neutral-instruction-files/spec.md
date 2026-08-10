## MODIFIED Requirements

### Requirement: The Claude instruction file is out of scope

`CLAUDE.md` SHALL NOT be subject to these requirements **only where it is the
sole instruction file in the repository and Claude alone reads it**.

Where a repository carries both names, `CLAUDE.md` is one of the two copies of
the shared instruction file and this carve-out does not apply. Every requirement
in this capability governs its bytes, because they are the shared file's bytes.
Markers, the `agents:` frontmatter and the section version appear in both
copies, identically, because the two copies are required to be identical.

The original reason for the carve-out was that "Claude is its only reader, so
there is no second agent to coordinate with and nothing to deduplicate". Two
identical files invert that premise exactly as the symlink did: the file Claude
reads holds the same bytes codex, opencode, pi and omp read. The previous
revision narrowed the carve-out for the symlink case only, which would now
exempt `CLAUDE.md` in precisely the arrangement that replaced it — a regular
file carrying the shared content. The condition that matters is whether the
bytes are shared, never whether the path is a link.

#### Scenario: Claude-only project

- **WHEN** a repo is provisioned for Claude alone, carrying `CLAUDE.md` and no
  `AGENTS.md`
- **THEN** no requirement in this capability applies to `CLAUDE.md`
- **AND** the absence of markers in `CLAUDE.md` SHALL NOT be reported as a
  violation

#### Scenario: Both names are present

- **GIVEN** a repository carrying both `AGENTS.md` and `CLAUDE.md`
- **WHEN** this capability's requirements are evaluated
- **THEN** they SHALL apply to both names
- **AND** the markers, frontmatter and section version SHALL be identical in
  both, because the two files are required to be byte-identical

#### Scenario: Tooling counts instruction files

- **WHEN** tooling counts the instruction files in a repository carrying both
  names
- **THEN** it SHALL count one shared instruction file, present under two paths
- **AND** it SHALL NOT report a duplicate-content violation for the pair
