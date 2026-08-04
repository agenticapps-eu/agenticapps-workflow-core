## ADDED Requirements

### Requirement: Executable steps carry role-tagged fences

A migration step's four required sections SHALL be expressed as fenced code
blocks whose info-string declares a role, so that a runner can dispatch them
without interpreting prose. The valid roles are `check`, `precondition`,
`apply`, `verify` and `rollback`. Each role-tagged fence SHALL follow the
heading it belongs to: `check` under `**Idempotency check:**`, `precondition`
under `**Pre-condition:**`, `apply` under `**Apply:**`, `verify` under
`**Verify:**`, and `rollback` under `**Rollback:**`.

The prose headings are retained rather than replaced. They already carry the
document's readable structure and are already extracted by existing host
tooling; the role tag adds only what a heading cannot express, which is that a
given fence is not meant to run.

#### Scenario: A tagged block is dispatched to its role
- **WHEN** a step contains a fence opened as ` ```bash role=apply `
- **THEN** an extractor asked for that step's `apply` block SHALL return that fence's body and no other content

#### Scenario: A tagged block under the wrong heading is rejected
- **WHEN** a step places a `role=apply` fence under the `**Rollback:**` heading
- **THEN** the format linter SHALL report a violation naming the role, the heading it expected, and the heading it found
- **AND** SHALL exit non-zero

#### Scenario: A role tag on a non-bash fence is rejected
- **WHEN** a migration contains a fence opened as ` ```yaml role=apply `
- **THEN** the format linter SHALL report a violation and exit non-zero

### Requirement: Un-annotated fences are never executed

A ` ```bash ` fence carrying no `role=` tag SHALL be treated as illustration and
SHALL NOT be executed by any runner, nor reported as contributing a role. This
is what permits a migration to show an explanatory or contrasting snippet beside
the commands it actually runs.

#### Scenario: An illustrative fence is invisible to the extractor
- **WHEN** a step contains an un-annotated ` ```bash ` fence alongside tagged ones
- **THEN** listing that step's roles SHALL NOT include any entry derived from the un-annotated fence
- **AND** running the migration SHALL NOT execute its contents

### Requirement: Unrecognised role values are rejected

The format linter SHALL reject a `role=` value that is not one of the five valid
roles, rather than ignoring it.

Because un-annotated fences are illustration, silently ignoring an unrecognised
value would demote a real command to a comment: the migration would lint clean,
run to completion, report success, and have done nothing. This is the same
failure mode as a hook that is installed but untrusted — present, plausible, and
enforcing nothing.

#### Scenario: A misspelled role fails the linter
- **WHEN** a step's apply fence is opened as ` ```bash role=aply `
- **THEN** the format linter SHALL report a violation quoting the offending value
- **AND** SHALL exit non-zero

### Requirement: An ID threshold scopes which migrations must be executable

Each host SHALL declare an executable threshold in its instruction file. A
migration whose numeric ID is at or above that threshold SHALL satisfy the
executable form and SHALL declare `migration_format: executable` in its
frontmatter. A migration below the threshold SHALL be skipped by the format
linter entirely.

Keying on the filename's ID rather than on a per-file declaration alone means
the scope cannot be evaded by forgetting to declare it. The frontmatter field is
retained as a human-readable assertion that the linter cross-checks; the two
disagreeing is an error.

#### Scenario: A migration below the threshold is not judged
- **WHEN** the linter runs against a migration whose ID is below the declared threshold
- **AND** that migration has no role-tagged fences and no rollback section
- **THEN** the linter SHALL exit zero without reporting a violation

#### Scenario: A migration at or above the threshold must declare its format
- **WHEN** the linter runs against a migration whose ID is at or above the threshold
- **AND** that migration's frontmatter omits `migration_format: executable`
- **THEN** the linter SHALL report a violation naming the missing field and exit non-zero

### Requirement: Steps are dispatched in a fixed order

A runner SHALL evaluate each step in document order, and within a step SHALL
evaluate its blocks in this order: `check`, then `precondition`, then `apply`,
then `verify` if present.

A `check` exiting zero SHALL cause the step to be skipped and reported as
already applied. A `precondition` exiting non-zero SHALL abort the migration.

#### Scenario: An already-applied step is skipped
- **WHEN** a step's `check` block exits zero
- **THEN** the runner SHALL NOT execute that step's `apply` block
- **AND** SHALL report the step as skipped

#### Scenario: Re-running an applied migration changes nothing
- **WHEN** a migration that has already been applied is run a second time
- **THEN** every step SHALL report as skipped
- **AND** the working tree SHALL be byte-identical to its state before the second run

### Requirement: A failing pre-condition's diagnostics reach the caller unaltered

When a `precondition` block exits non-zero, the runner SHALL reproduce that
block's standard error verbatim and SHALL NOT paraphrase, summarise or replace
it.

A pre-condition is where a migration explains what it found and what the
operator may do about it. Existing migrations exit with multi-line remediation
messages offering specific alternatives; a runner that substitutes its own
wording destroys the only useful output.

#### Scenario: A multi-line remediation message survives intact
- **WHEN** a `precondition` block writes a two-option remediation message to stderr and exits 3
- **THEN** the runner SHALL emit that message unchanged, including both options
- **AND** SHALL exit non-zero

### Requirement: Unattended failure aborts without rolling back

When a step fails and standard input is a terminal, the runner SHALL prompt with
three options: retry the step, skip it with a warning and record the migration
as partial, or roll back the steps already applied.

When standard input is not a terminal, the runner SHALL abort in place, SHALL
report which steps applied, and SHALL NOT roll back.

The absence of anyone to ask is not consent. A half-applied tree is also
evidence of what went wrong, which an automatic rollback destroys. Runners
SHOULD offer an explicit override to select the failure policy directly.

#### Scenario: A non-interactive failure preserves completed work
- **WHEN** step 2 of a two-step migration fails with no terminal attached
- **THEN** step 1's changes SHALL remain on disk
- **AND** the runner SHALL report which steps applied
- **AND** SHALL exit non-zero

#### Scenario: An explicit override selects the policy
- **WHEN** the runner is invoked with an explicit failure-policy selection
- **THEN** it SHALL use that policy rather than the one derived from whether a terminal is attached

### Requirement: Rollback blocks are exercised independently of the runner

Because the non-interactive path never reaches a `rollback` block, a host's
migration harness SHALL exercise each `rollback` block directly against its own
step's post-apply state.

Every step is required to declare a rollback, but only an interactive operator
choosing to roll back ever causes one to run. Without a direct test, the one
block every step must have is the one nothing ever executes, which makes it the
most likely to be silently wrong.

#### Scenario: A rollback returns the tree to its pre-apply state
- **WHEN** a step's `apply` block is executed and then its `rollback` block is executed
- **THEN** the working tree SHALL match its state before the `apply` ran

#### Scenario: A rollback affects only its own step
- **WHEN** two steps are applied and only the second step's `rollback` is executed
- **THEN** the first step's changes SHALL remain on disk

### Requirement: Dry-run reports the source it would execute

A runner's dry-run mode SHALL evaluate each step's `check` and `precondition`
blocks, SHALL print the source of the `apply` block each pending step would run,
and SHALL NOT write to the working tree.

Dry-run does not report a diff. Producing one would require applying the step,
which is the thing dry-run exists not to do.

#### Scenario: Dry-run prints sources and writes nothing
- **WHEN** a migration is run in dry-run mode against a tree where no step has been applied
- **THEN** the runner SHALL print each pending step's `apply` source
- **AND** the working tree SHALL be unchanged
- **AND** the runner SHALL exit zero
