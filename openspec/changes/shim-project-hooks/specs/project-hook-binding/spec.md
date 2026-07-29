## ADDED Requirements

### Requirement: A hook implementation lives in exactly one place

A workflow hook's behaviour SHALL be implemented in exactly one file on a given
machine. A project SHALL NOT carry a copy of a hook implementation.

This is the rule that the existing drift violates: five hook implementations
copied into seven projects produced three distinct versions of
`normalize-claude-md.sh` and `database-sentinel.sh`, and two of
`design-shotgun-gate.sh` and `skill-router-log.sh`.

#### Scenario: A hook's behaviour is changed

- **WHEN** a maintainer changes what a hook does
- **THEN** exactly one file is edited, and the change is live in every project
  on that machine without any per-project edit, PR, or migration

#### Scenario: Two projects are compared

- **WHEN** the same hook is compared byte-for-byte across any two projects that
  bind it
- **THEN** the two files are identical, because both are shims naming the same
  implementation

### Requirement: A project binds a hook through a shim

A project SHALL bind a hook by shipping a shim that locates and `exec`s the
canonical implementation. The shim SHALL contain no behaviour of its own beyond
resolution, host self-identification, and `exec`.

The shim SHALL resolve the implementation in this order:

1. An explicit environment override, when set
2. `~/.agenticapps/bin/<hook>.sh` — the shared install
3. `<repo>/bin/<hook>.sh` — a scaffolder checkout

#### Scenario: The shared install is present

- **WHEN** a hook fires and `~/.agenticapps/bin/<hook>.sh` is executable
- **THEN** the shim `exec`s it and the implementation decides the outcome

#### Scenario: An override is set

- **WHEN** the hook's explicit override variable names an executable file
- **THEN** the shim `exec`s that file in preference to the shared install,
  so a test can substitute an implementation without editing any project

### Requirement: An unresolvable hook fails open

When a shim cannot resolve any implementation, it SHALL exit 0 (allow) rather
than block.

A missing shared install MUST NOT brick every edit in a session. The git
pre-commit and CI floor remain the guarantee that actually binds, per §18 — a
`PreToolUse` hook cannot gate its own installing session in any case.

#### Scenario: No implementation is resolvable

- **WHEN** a hook fires, no override is set, and neither
  `~/.agenticapps/bin/<hook>.sh` nor `<repo>/bin/<hook>.sh` is executable
- **THEN** the shim exits 0 and the tool call proceeds

#### Scenario: A project is cloned on a machine with no install

- **WHEN** a project is cloned onto a machine where the installer has never run
- **THEN** every hook fails open, the project is fully editable, and hook
  enforcement is absent rather than the project being unusable

### Requirement: A gate whose sentinel mechanism is absent does not block

A gate that predicates blocking on a sentinel artifact SHALL allow the action
when the mechanism that produces that sentinel is not present in the project.
A gate SHALL NOT block on a condition that the project has no available means
to satisfy.

This is the `design-shotgun-gate` defect: it blocks edits to design surfaces
unless `.planning/current-phase/design-shotgun-passed` exists, but only GSD-era
preflight ever wrote that sentinel, and GSD was removed on 2026-07-28. In
`callbot` and `fbc-platform`, which have no `.planning/current-phase/`
directory, this blocked every edit to 90 and 114 tracked design files
respectively, with a printed remedy that no longer exists.

#### Scenario: The sentinel directory is absent

- **WHEN** an edit targets a design surface and `.planning/current-phase/` does
  not exist in the project
- **THEN** the gate allows the edit, because the project has no mechanism that
  could produce the sentinel

#### Scenario: The sentinel directory exists but the sentinel does not

- **WHEN** an edit targets a design surface, `.planning/current-phase/` exists,
  and `design-shotgun-passed` is absent from it
- **THEN** the gate blocks the edit, because the project does have a working
  sentinel mechanism and the pre-flight has genuinely not run

#### Scenario: The sentinel is present

- **WHEN** an edit targets a design surface and the sentinel exists
- **THEN** the gate allows the edit, unchanged from current behaviour

### Requirement: An extension hook may be removed; a named gate may not

A host-specific extension hook — one not named in §02's normative gate list —
MAY be deleted without a spec delta. A hook that binds a gate named in §02
SHALL NOT be deleted; a defective binding is repaired, not removed.

#### Scenario: An inert extension hook is removed

- **WHEN** a hook is not named in §02's gate list and its trigger condition
  cannot occur in any project
- **THEN** it MAY be deleted from every project without a §02 delta

#### Scenario: A named gate's binding is defective

- **WHEN** a hook binds a §02-named gate and is found to misbehave
- **THEN** the binding is repaired and retained, because §02 states that
  removing or renaming a gate in its list is non-conformant
