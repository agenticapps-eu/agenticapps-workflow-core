## ADDED Requirements

### Requirement: A hook implementation is authoritative in one place

A workflow hook's behaviour SHALL be defined in exactly one authoritative file.
A project SHALL NOT carry a copy of that behaviour.

A shim resolves the authoritative file through an ordered lookup, and that
lookup naming several candidate locations does not make several
implementations: at most one is authoritative on a given machine, and the order
decides which.

This is the rule the current fleet violates: two hook implementations copied
into seven projects produced three distinct versions of
`normalize-claude-md.sh` and of `database-sentinel.sh`.

#### Scenario: A hook's behaviour is changed

- **WHEN** a maintainer changes what a hook does
- **THEN** exactly one file is edited, and the change is live in every project
  on that machine once republished, without any per-project edit or migration

#### Scenario: Two projects are compared

- **WHEN** the same hook is compared byte-for-byte across any two projects that
  bind it
- **THEN** the two files are identical, because both are shims naming the same
  implementation

### Requirement: A project binds a hook through a shim

A project SHALL bind a hook by shipping a shim that locates and `exec`s the
authoritative implementation. The shim SHALL contain no behaviour of its own
beyond resolution, host self-identification, and `exec`.

The shim SHALL resolve in this order:

1. An explicit environment override, when set
2. `~/.agenticapps/bin/<hook>.sh` — the shared install
3. `<repo>/bin/<hook>.sh` — a scaffolder checkout

#### Scenario: The shared install is present

- **WHEN** a hook fires and `~/.agenticapps/bin/<hook>.sh` is executable
- **THEN** the shim `exec`s it and the implementation decides the outcome

#### Scenario: An override is set

- **WHEN** the hook's override variable names an executable file
- **THEN** the shim `exec`s that in preference to the shared install, so a test
  can substitute an implementation without editing any project

### Requirement: The fail posture follows the hook's class

An unresolvable shim SHALL fail according to what the hook protects:

- A hook enforcing a **security control** SHALL fail **closed** — it blocks.
- A hook providing **cosmetic or advisory** behaviour SHALL fail **open** — it
  allows.

§18's pre-commit and CI floor backstops the OpenSpec change gate only. It does
not check destructive SQL, `.env` access, or any other control. A
security-relevant hook that fails open therefore removes protection with
nothing beneath it, and does so silently — the worst combination. A cosmetic
hook that fails closed would brick a machine for no safety gain.

#### Scenario: A security hook cannot resolve an implementation

- **WHEN** `database-sentinel`'s shim finds no override, no shared install and
  no repo `bin/` copy
- **THEN** it blocks the tool call and reports that the implementation is
  missing, rather than allowing an unchecked `.env` or migration edit

#### Scenario: A cosmetic hook cannot resolve an implementation

- **WHEN** `normalize-claude-md`'s shim resolves nothing
- **THEN** it exits 0 and the tool call proceeds

#### Scenario: A project is cloned before the installer runs

- **WHEN** a project is cloned onto a machine where the installer has never run
- **THEN** cosmetic hooks are absent without obstruction, and security hooks
  block with an actionable message naming the installer

### Requirement: Reconciling divergent copies selects semantics deliberately

When copies of a hook have diverged, the canonical implementation SHALL be
chosen by comparing behaviour, not by recency. Where variants differ in what
they protect, the canonical implementation SHALL take the superset of
protection.

Choosing "the newest file" would have silently narrowed `.env` matching from a
wildcard to a four-item enumeration, dropping protection for any suffix nobody
enumerated.

#### Scenario: Variants differ in matched paths

- **WHEN** one variant matches `.env.*` by wildcard and another enumerates
  specific suffixes
- **THEN** the wildcard is canonical, together with any explicit allowance
  (`.env.example`, `.env.template`) the narrower variant did not need

#### Scenario: Variants differ in handled tools

- **WHEN** one variant handles a tool (`MultiEdit`) the others omit
- **THEN** the canonical implementation handles it

#### Scenario: A variant is deliberately inert

- **WHEN** a project documents in-file that its copy is intentionally
  unregistered
- **THEN** that decision is preserved: the project is not re-registered, and
  the variant is not treated as drift to be reconciled away

### Requirement: An extension hook may be removed; a named gate may not

A hook not named in §02's normative gate list is a host-specific extension and
MAY be deleted without a §02 delta. A hook binding a §02-named gate SHALL NOT
be deleted.

A shell hook that merely shares a gate's name is not that gate's binding. §02
binds gates to skills and to evidence artifacts; identifying a hook with a gate
by filename alone confuses the two.

#### Scenario: An inert extension hook is removed

- **WHEN** a hook is not named in §02's gate list and its trigger cannot occur
- **THEN** it MAY be deleted from every project without a §02 delta

#### Scenario: A hook shares a gate's name but is not its binding

- **WHEN** a hook is named after a §02 gate, but that gate's binding is a skill
  named in the host instruction file
- **THEN** deleting the hook does not remove the gate's binding, and no §02
  delta is required

### Requirement: A hook does not write into archived directories

A hook SHALL NOT write to a directory the fleet designates as frozen history.

`.planning/` is frozen GSD history: read for context, never written, never
treated as the current plan. A hook writing live session data there
contradicts that designation and makes archived and live content
indistinguishable.

#### Scenario: A hook needs to persist session data

- **WHEN** a hook records telemetry or state across sessions
- **THEN** it writes outside `.planning/`, or it is removed

#### Scenario: Session data is read back into model context

- **WHEN** a hook prints stored content into a session's context
- **THEN** that content is treated as untrusted input, delimited as such — or
  the hook is removed rather than carried
