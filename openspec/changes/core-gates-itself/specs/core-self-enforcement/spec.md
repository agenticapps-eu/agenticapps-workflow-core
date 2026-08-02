## ADDED Requirements

### Requirement: Core runs the gate against its own repository

The core repository SHALL run the §18 change gate against itself at all three
interposition points §18 names: a `PreToolUse` hook, a git `pre-commit` hook, and
a CI job. Publishing an enforcement artifact SHALL NOT be accepted as a
substitute for running it.

**None of the three is a guarantee, and the requirement SHALL NOT claim
otherwise.** §18 records that a `PreToolUse` hook is loaded at session start and
cannot gate the session that installs it, and that it does not exist at all for
a human using an editor. The `pre-commit` hook is delivered by an installer and
is absent until that installer runs. The CI job's verdict blocks a merge only
where a repository setting requires the check, and core's `main` carries no
branch protection and no rulesets — so the CI job **reports** rather than
enforces. Whether a verdict blocks a merge is a repository setting outside this
capability's scope.

This is recorded as a §09 delta: core runs the gate at all three points and has
no enforced floor beneath them.

#### Scenario: All three interposition points run the gate

- **WHEN** the core repository is inspected for gate wiring
- **THEN** a `PreToolUse` hook exists and is registered in `.claude/settings.json`
- **AND** a CI workflow exists that runs the gate on pull requests and on pushes to `main`
- **AND** an installer exists that writes the `pre-commit` hook into the repository's resolved hooks directory

#### Scenario: The CI verdict does not block a merge

- **WHEN** the CI job fails on a pull request against `main`
- **THEN** the failure SHALL be visible on the pull request
- **AND** the merge SHALL NOT be prevented by this capability
- **AND** no surface SHALL describe the CI job as an enforced floor

#### Scenario: Publishing is not running

- **WHEN** core ships a gate, a wrapper or a CI template for other repositories to consume
- **THEN** that act SHALL NOT discharge this requirement
- **AND** core SHALL still run the gate against itself

#### Scenario: The gate does not observe every edit path

- **WHEN** a file is modified through `Bash` — by `sed -i`, `tee`, a redirect or a script
- **THEN** the `PreToolUse` hook SHALL NOT observe the edit, because its matcher covers `Edit|Write|MultiEdit|NotebookEdit` only
- **AND** the capability SHALL NOT describe the three interposition points as complete coverage

### Requirement: Core resolves its own reference implementation

Core's three interposition points SHALL resolve
`reference-implementations/openspec-change-gate/openspec-change-gate.sh` from
the working tree, and SHALL NOT prefer the shared install at
`~/.agenticapps/bin/openspec-change-gate.sh`.

Core is the source of truth for that file. Gating core with a published copy
would prove nothing about the bytes core ships, and in CI no shared install
exists at all. This resolution order is deliberately the inverse of the one
every consuming project uses, and SHALL be documented in
`adrs/0028-core-gates-itself.md` and in `docs/WORKFLOW.md`.

#### Scenario: The working-tree copy is preferred over a present shared install

- **WHEN** an executable gate exists at `~/.agenticapps/bin/openspec-change-gate.sh` whose behaviour differs from the working-tree copy
- **THEN** both the `PreToolUse` hook and the `pre-commit` hook SHALL execute the working-tree copy
- **AND** the shared install SHALL NOT be consulted

#### Scenario: The shared install is absent

- **WHEN** the gate runs in CI, where `~/.agenticapps/` does not exist
- **THEN** the gate SHALL still resolve and run from the working tree
- **AND** the job SHALL NOT fail for want of a shared install

#### Scenario: The resolution order is inverted relative to projects

- **WHEN** core's resolution order is compared with a consuming project's shim
- **THEN** core SHALL prefer the working-tree copy and the project SHALL prefer the shared install
- **AND** core SHALL record the reason for the inversion in the two documents named above

### Requirement: Core proves the gate conformant before acting on its verdict

Core's CI job SHALL score
`reference-implementations/openspec-change-gate/openspec-change-gate.sh` with
`tools/change-gate-conformance.sh` before invoking it, and SHALL fail when the
harness fails.

A gate that has drifted can pass every repository it guards while enforcing
nothing. Scoring it in core is the earliest point at which that is detectable:
until core does this, the conformance of the artifact core authors is proven
only downstream, in host repositories that advanced a pin and trusted it.

**The scorer SHALL itself be bounded.** The harness is a working-tree file
executed from the same checkout as the gate, so a change that weakens the
harness — deleting rows, inverting expected exit codes — would otherwise yield a
green job while certifying a drifting gate. The job SHALL therefore assert a
minimum scored-row count, and SHALL fail when the harness reports fewer rows
than that floor. The floor SHALL be recorded as a literal in the workflow and
SHALL be raised, never lowered, without an explicit recorded decision.

#### Scenario: The gate is scored before it is run

- **WHEN** the CI job executes
- **THEN** the conformance harness SHALL run against the reference implementation before the gate is invoked
- **AND** a failing harness SHALL fail the job without the gate's verdict being consulted

#### Scenario: The reference implementation stops being conformant

- **WHEN** an edit makes the reference implementation fail one or more harness rows
- **THEN** core's own pull request SHALL go red
- **AND** the failure SHALL be visible before any host advances a pin to that commit

#### Scenario: The harness is weakened

- **WHEN** a change reduces the number of rows the harness scores below the recorded floor
- **THEN** the CI job SHALL fail
- **AND** it SHALL NOT report success on a reduced row count that still shows zero failures

#### Scenario: The named target is missing

- **WHEN** the harness is pointed at a target that is absent, empty or unreadable
- **THEN** the harness SHALL report it as unscoreable and fail
- **AND** the job SHALL NOT pass on a zero-of-zero score

### Requirement: Fail-open is scoped to the local interposition points

The gate's §18 behaviour SHALL be preserved unchanged by self-enforcement. Core
SHALL NOT introduce a stricter local posture as a side effect of gating itself,
and SHALL NOT introduce a laxer one in CI.

**Fail-open applies to the `PreToolUse` hook and the `pre-commit` hook only.**
Those two SHALL exit 0 when the gate cannot be located, so that absent tooling
cannot brick an editing session or train contributors to pass `--no-verify`. **CI
SHALL fail closed**: a gate or harness that cannot be located or scored SHALL
fail the job, because in CI an unanswerable question is a defect rather than a
missing convenience.

**Missing `openspec` CLI is fail-CLOSED, by inherited design.** When the
`openspec` binary is absent the gate returns 2 while any change is active. Core
is a repository where a change is almost always open, so a contributor without
the CLI installed is blocked locally on every non-exempt edit. This is the
gate's own semantics, correctly preserved rather than introduced here, and it
SHALL be disclosed rather than left to be discovered.

#### Scenario: An unrelated change is open with a stale review

- **WHEN** a code edit is attempted while an active change has stale or missing review evidence
- **AND** `openspec validate --all` is green
- **THEN** the gate SHALL allow the edit
- **AND** SHALL report the review state without blocking

#### Scenario: Validation is red

- **WHEN** a code edit is attempted while an active change fails `openspec validate --all`
- **THEN** the `PreToolUse` hook SHALL block the edit
- **AND** the CI job SHALL fail

#### Scenario: The gate cannot be located locally

- **WHEN** the resolved gate path does not exist or is not executable
- **THEN** the `PreToolUse` hook and the `pre-commit` hook SHALL exit 0 and SHALL NOT block
- **AND** each SHALL report on stderr that the repository is not gated

#### Scenario: The gate or harness cannot be located in CI

- **WHEN** the CI job cannot resolve the gate or the harness
- **THEN** the job SHALL fail
- **AND** SHALL NOT exit 0 on the grounds that the question could not be answered

#### Scenario: The openspec CLI is absent

- **WHEN** a code edit is attempted while a change is active and the `openspec` binary is not on `PATH`
- **THEN** the gate SHALL block the edit
- **AND** the capability's documentation SHALL state that this case is fail-closed

#### Scenario: Stdin is malformed

- **WHEN** the hook receives input that is not a well-formed tool-call payload
- **THEN** it SHALL exit 0

#### Scenario: OpenSpec artifacts remain exempt

- **WHEN** the edit targets a file inside `openspec/`
- **THEN** the gate SHALL allow it regardless of the active change's state

### Requirement: The pre-commit installer resolves the real hooks directory

Because the hooks directory is not tracked by git, core SHALL provide an
installer that writes the `pre-commit` hook, and the installer SHALL resolve the
destination rather than assume it.

The installer SHALL obtain the hooks directory from `git rev-parse --git-path
hooks`. It SHALL NOT write to a literal `.git/hooks/` path: in a linked git
worktree `.git` is a file rather than a directory, so that path does not exist,
and the real hooks directory belongs to the main checkout.

The installer SHALL detect `core.hooksPath`. When that setting is present and
points elsewhere, a hook written to the resolved default directory would be
silently ignored by git, so the installer SHALL report the conflict and exit
non-zero rather than install a hook that cannot fire.

#### Scenario: Installation inside a linked worktree

- **WHEN** the installer runs in a linked worktree, where `.git` is a file
- **THEN** it SHALL resolve the hooks directory via `git rev-parse --git-path hooks`
- **AND** SHALL NOT attempt to create or write a literal `.git/hooks/` path
- **AND** SHALL report that the hook it installs is shared with the main checkout

#### Scenario: core.hooksPath is set

- **WHEN** the installer runs in a repository where `core.hooksPath` is configured
- **THEN** it SHALL report the conflict and exit non-zero
- **AND** SHALL NOT write a hook that git would ignore

### Requirement: The installer owns its hook without clobbering another

The installer SHALL be safe to re-run and SHALL NOT silently destroy a
`pre-commit` hook it did not write.

Ownership SHALL be established by a marker line the installer writes into the
hook, not by comparing whole-file bytes. Byte equality cannot express ownership
across versions: a hook core wrote and later revised would read as foreign under
that test and be refused permanently, which is the opposite of the intended
behaviour.

Marker semantics SHALL be explicit:

- **No hook present** — install, and report an install.
- **Hook present, marker present, content current** — leave it, and report a
  no-op rather than a fresh install.
- **Hook present, marker present, content stale** — update in place, and report
  an upgrade. This is what makes the gate advanceable.
- **Hook present, no marker** — refuse, report what was found, exit non-zero.

A marker is an ownership claim, not an integrity proof: a hand-edited or
adversarially marked hook will be treated as core's and updated in place. That
is an accepted limit of a repository-local convenience script, and SHALL be
recorded rather than implied.

#### Scenario: The installer runs on a fresh clone

- **WHEN** the installer is run where no `pre-commit` hook exists
- **THEN** it SHALL write an executable hook resolving core's reference implementation
- **AND** the hook SHALL carry the ownership marker

#### Scenario: The installer runs twice

- **WHEN** the installer is run again and the installed hook is already current
- **THEN** it SHALL leave the hook unchanged
- **AND** SHALL report a no-op rather than an install

#### Scenario: A self-written hook is stale

- **WHEN** the installer finds a hook carrying its marker whose content differs from what it would write now
- **THEN** it SHALL update the hook in place
- **AND** SHALL report an upgrade

#### Scenario: A foreign pre-commit hook is already present

- **WHEN** the installer finds a `pre-commit` hook with no ownership marker
- **THEN** it SHALL refuse to overwrite it
- **AND** SHALL report what it found and exit non-zero

#### Scenario: The installer was never run

- **WHEN** a commit is made in a clone where the installer has not run
- **THEN** the commit SHALL NOT be gated locally
- **AND** the CI job SHALL still run the gate on the resulting pull request

### Requirement: The CI job constrains what it executes

Core's CI job executes shell scripts from the working tree of the revision under
test. It SHALL be configured so that a pull request cannot use that execution to
reach beyond the job.

The job SHALL declare least-privilege permissions, SHALL NOT persist checkout
credentials into the workspace, and SHALL pin the version of the `openspec` CLI
it installs. An unpinned global install would let an upstream release change the
gate's verdict between two runs of an unchanged repository.

#### Scenario: The workflow declares its privileges

- **WHEN** the workflow is inspected
- **THEN** it SHALL declare read-only `contents` permission
- **AND** the checkout step SHALL disable credential persistence

#### Scenario: The OpenSpec dependency is pinned

- **WHEN** the workflow installs the `openspec` CLI
- **THEN** it SHALL install an exact pinned version
- **AND** an upstream release SHALL NOT change the verdict for an unchanged revision
