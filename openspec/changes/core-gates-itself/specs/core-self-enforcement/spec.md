## ADDED Requirements

### Requirement: Core enforces the gate against its own repository

The core repository SHALL wire the §18 change gate at all three interposition
points §18 names: a `PreToolUse` hook, a git `pre-commit` floor, and a CI job.
Publishing an enforcement artifact SHALL NOT be accepted as a substitute for
running it.

The `PreToolUse` hook SHALL NOT be treated as the guarantee. §18 records that a
`PreToolUse` hook is loaded at session start and therefore cannot gate the
session that installs it, and that it does not exist at all for a human using an
editor. The `pre-commit` and CI floors SHALL be the surfaces the requirement
actually rests on.

#### Scenario: All three interposition points are wired

- **WHEN** the core repository is inspected for gate wiring
- **THEN** a `PreToolUse` hook exists and is registered in `.claude/settings.json`
- **AND** a CI workflow exists that runs the gate on pull requests and on pushes to `main`
- **AND** an installer exists that writes the `pre-commit` floor into `.git/hooks/`

#### Scenario: Publishing is not running

- **WHEN** core ships a gate, a wrapper or a CI template for other repositories to consume
- **THEN** that act SHALL NOT discharge this requirement
- **AND** core SHALL still run the gate against itself

### Requirement: Core resolves its own reference implementation

Core's three enforcement points SHALL resolve
`reference-implementations/openspec-change-gate/openspec-change-gate.sh` from
the working tree, and SHALL NOT prefer the shared install at
`~/.agenticapps/bin/openspec-change-gate.sh`.

Core is the source of truth for that file. Gating core with a published copy
would prove nothing about the bytes core ships, and in CI no shared install
exists at all. This resolution order is deliberately the inverse of the one
every consuming project uses, and SHALL be documented where core's other gate
behaviour is documented.

#### Scenario: A consuming project's shim is not reused verbatim

- **WHEN** core's `PreToolUse` hook resolves the gate
- **THEN** it SHALL resolve the path in core's working tree
- **AND** it SHALL NOT fall back to `~/.agenticapps/bin/openspec-change-gate.sh`

#### Scenario: The shared install is absent

- **WHEN** the gate runs in CI, where `~/.agenticapps/` does not exist
- **THEN** the gate SHALL still resolve and run from the working tree
- **AND** the job SHALL NOT fail for want of a shared install

#### Scenario: The resolution order is inverted relative to projects

- **WHEN** core's resolution order is compared with a consuming project's shim
- **THEN** core SHALL prefer the working-tree copy and the project SHALL prefer the shared install
- **AND** core SHALL record the reason for the inversion

### Requirement: Core proves the gate conformant before acting on its verdict

Core's CI job SHALL score
`reference-implementations/openspec-change-gate/openspec-change-gate.sh` with
`tools/change-gate-conformance.sh` before invoking it, and SHALL fail when the
harness fails.

A gate that has drifted can pass every repository it guards while enforcing
nothing. Scoring it in core is the earliest point at which that is detectable:
until core does this, the conformance of the artifact core authors is proven
only downstream, in host repositories that advanced a pin and trusted it.

#### Scenario: The gate is scored before it is run

- **WHEN** the CI job executes
- **THEN** the conformance harness SHALL run against the reference implementation before the gate is invoked
- **AND** a failing harness SHALL fail the job without the gate's verdict being consulted

#### Scenario: The reference implementation stops being conformant

- **WHEN** an edit makes the reference implementation fail one or more harness rows
- **THEN** core's own pull request SHALL go red
- **AND** the failure SHALL be visible before any host advances a pin to that commit

#### Scenario: The named target is missing

- **WHEN** the harness is pointed at a target that is absent, empty or unreadable
- **THEN** the harness SHALL report it as unscoreable and fail
- **AND** the job SHALL NOT pass on a zero-of-zero score

### Requirement: Self-enforcement preserves the gate's fail-open posture

Wiring the gate into core SHALL NOT make core less editable than the gate's own
rules require. The gate's §18 behaviour SHALL be preserved unchanged: it blocks
on exactly one condition, `openspec validate --all` not being green, and fails
open on malformed input, on a missing gate, and when no change is active.

Core SHALL NOT introduce a stricter local posture as a side effect of gating
itself.

#### Scenario: An unrelated change is open with a stale review

- **WHEN** a code edit is attempted while an active change has stale or missing review evidence
- **AND** `openspec validate --all` is green
- **THEN** the gate SHALL allow the edit
- **AND** SHALL report the review state without blocking

#### Scenario: Validation is red

- **WHEN** a code edit is attempted while an active change fails `openspec validate --all`
- **THEN** the `PreToolUse` hook SHALL block the edit
- **AND** the CI job SHALL fail

#### Scenario: The gate cannot be located

- **WHEN** the resolved gate path does not exist or is not executable
- **THEN** the hook SHALL exit 0 and SHALL NOT block the edit
- **AND** SHALL report on stderr that the repository is not gated

#### Scenario: Stdin is malformed

- **WHEN** the hook receives input that is not a well-formed tool-call payload
- **THEN** it SHALL exit 0

#### Scenario: OpenSpec artifacts remain exempt

- **WHEN** the edit targets a file inside `openspec/`
- **THEN** the gate SHALL allow it regardless of the active change's state

### Requirement: The pre-commit floor is installable and its absence is visible

Because `.git/hooks/` is not tracked by git, core SHALL provide an installer
that writes the `pre-commit` floor, and the installer SHALL be idempotent.

The installer SHALL NOT silently overwrite an existing `pre-commit` hook it did
not write. A clone on which the installer has not been run SHALL NOT be assumed
gated at commit time; CI SHALL remain the floor beneath it.

#### Scenario: The installer runs on a fresh clone

- **WHEN** the installer is run in a clone with no `pre-commit` hook
- **THEN** it SHALL write an executable `.git/hooks/pre-commit` resolving core's reference implementation
- **AND** running it a second time SHALL leave the same result

#### Scenario: A foreign pre-commit hook is already present

- **WHEN** the installer finds a `pre-commit` hook it did not write
- **THEN** it SHALL refuse to overwrite it
- **AND** SHALL report what it found and exit non-zero

#### Scenario: The installer was never run

- **WHEN** a commit is made in a clone where the installer has not run
- **THEN** the commit SHALL NOT be gated locally
- **AND** the CI job SHALL still gate the resulting pull request
