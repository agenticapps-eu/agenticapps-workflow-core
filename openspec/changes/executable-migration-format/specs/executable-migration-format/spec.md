## ADDED Requirements

### Requirement: Executable steps carry role-tagged fences

A migration step's sections SHALL be expressed as fenced code blocks whose
info-string declares a role, so that a runner can dispatch them without
interpreting prose. The valid roles are `check`, `precondition`, `apply`,
`verify` and `rollback`. Each role-tagged fence SHALL follow the heading it
belongs to: `check` under `**Idempotency check:**`, `precondition` under
`**Pre-condition:**`, `apply` under `**Apply:**`, `verify` under `**Verify:**`,
and `rollback` under `**Rollback:**`.

The info-string grammar is exact: the literal `bash`, one or more spaces,
`role=`, then a role name, then nothing but optional trailing whitespace. An
info-string carrying additional keys, a different case, or any other trailing
content is not a valid tagged fence.

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

#### Scenario: An info-string with extra content is rejected
- **WHEN** a migration contains a fence opened as ` ```bash role=apply retry=2 `
- **THEN** the format linter SHALL report a violation and exit non-zero

### Requirement: Every step declares the four required roles

Each step SHALL carry exactly one `check`, one `precondition`, one `apply` and
one `rollback` block. A step MAY carry at most one `verify` block. No role
SHALL appear more than once within a step.

The four required roles are §08's existing quartet, unchanged. `verify` is the
one addition and is optional, because a step whose `apply` is its own evidence
has nothing further to assert.

#### Scenario: A step missing a required role is rejected
- **WHEN** a step declares `check`, `precondition` and `apply` but no `rollback`
- **THEN** the format linter SHALL report a violation naming the missing role and exit non-zero

#### Scenario: A step with a duplicated role is rejected
- **WHEN** a step declares two `apply` blocks
- **THEN** the format linter SHALL report a violation naming the duplicated role and exit non-zero

#### Scenario: A step without verify is accepted
- **WHEN** a step declares the four required roles and no `verify` block
- **THEN** the format linter SHALL exit zero for that step

### Requirement: Steps are numbered consecutively and bounded by the next step heading

A migration's steps SHALL be numbered consecutively from 1, with each step
introduced by a `### Step <N>` heading at the start of a line. A step's extent
SHALL end at the next `### Step ` heading of any number, or at the end of the
document.

Bounding a step by "the next step heading" rather than by "the heading numbered
N+1" means a gap in the numbering cannot silently merge two steps into one and
hide the second step's roles from both the linter and the runner.

#### Scenario: A gap in numbering does not merge steps
- **WHEN** a migration declares `### Step 1` and `### Step 3` with no `### Step 2`
- **THEN** the extractor SHALL treat them as two separate steps
- **AND** the format linter SHALL report the non-consecutive numbering as a violation

#### Scenario: Step 1 is not confused with step 10
- **WHEN** a migration contains both `### Step 1` and `### Step 10`
- **THEN** a request for step 1's blocks SHALL return only step 1's blocks

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

### Requirement: A runner refuses a migration that would do nothing

Before executing any step, a runner SHALL lint the migration and SHALL abort
without executing anything if the linter reports a violation. A runner SHALL
also abort if an in-scope migration yields zero steps, or if any step yields no
`apply` block.

Rejecting a bad migration at lint time is not sufficient on its own, because
nothing obliges the operator to have linted. A runner that will execute whatever
it is given is a runner that can be handed an all-illustration document and
report success having changed nothing — the precise failure this format exists
to prevent, and most dangerous when the step it silently skipped was the
security-relevant one.

#### Scenario: A runner refuses a migration that fails the linter
- **WHEN** a runner is given an in-scope migration whose step omits its `rollback` block
- **THEN** the runner SHALL exit non-zero reporting the violation
- **AND** SHALL NOT execute any block

#### Scenario: A runner refuses an all-illustration migration
- **WHEN** a runner is given an in-scope migration whose only fences are un-annotated
- **THEN** the runner SHALL exit non-zero
- **AND** SHALL NOT report success

### Requirement: An ID threshold scopes which migrations must be executable

The format linter SHALL determine a migration's ID from its **filename**, and
SHALL judge a migration whose ID is at or above its host's declared threshold. A
migration below the threshold SHALL be skipped entirely.

A migration at or above the threshold SHALL declare `migration_format:
executable` in frontmatter, and the linter SHALL report a violation if it does
not. A migration below the threshold that declares `migration_format:
executable` SHALL be judged as though it were in scope; a declaration can add a
migration to the linter's scope but SHALL NOT remove one from it. A
`migration_format` value other than `executable` SHALL be reported as a
violation.

Reading the ID from the filename rather than from frontmatter is what makes the
scope unevadable: a frontmatter field can be omitted, and an omitted field must
not be the difference between a judged migration and an unjudged one. The
declaration is retained as a human-readable assertion and cross-checked against
the filename, which is why the two can only disagree in the safe direction.

Thresholds SHALL be declared per host in a file the linter reads. Until a host
declares its own, core's declaration is authoritative.

#### Scenario: A migration below the threshold is not judged
- **WHEN** the linter runs against a migration whose filename ID is below the declared threshold
- **AND** that migration has no role-tagged fences and no rollback section
- **THEN** the linter SHALL exit zero without reporting a violation

#### Scenario: A migration at or above the threshold must declare its format
- **WHEN** the linter runs against a migration whose filename ID is at or above the threshold
- **AND** that migration's frontmatter omits `migration_format: executable`
- **THEN** the linter SHALL report a violation naming the missing field and exit non-zero

#### Scenario: Deleting the frontmatter ID does not evade the linter
- **WHEN** a migration at or above the threshold has no `id:` line in its frontmatter
- **THEN** the linter SHALL still judge it, having taken its ID from the filename
- **AND** SHALL exit non-zero

#### Scenario: A below-threshold migration may opt in
- **WHEN** a migration below the threshold declares `migration_format: executable`
- **AND** one of its steps omits a required role
- **THEN** the linter SHALL report the violation and exit non-zero

### Requirement: Steps are dispatched in a fixed order

A runner SHALL evaluate each step in document order, and within a step SHALL
evaluate its blocks in this order: `check`, then `precondition`, then `apply`,
then `verify` if present.

A `check` block SHALL exit 0 when the step is already applied and 1 when it is
not. Any other exit code SHALL be treated as the check itself having failed, and
SHALL abort the migration. Conflating "not yet applied" with "the check could
not run" would silently re-apply a step whose state is unknown.

A `precondition` block exiting non-zero SHALL abort the migration immediately,
regardless of whether standard input is a terminal. A failed pre-condition means
the migration's assumptions about the tree do not hold; retrying cannot change
that, and skipping would apply a step whose assumptions are known to be
violated. The interactive failure policy therefore governs `apply` and `verify`
failures only.

A `verify` block exiting non-zero SHALL be treated as the step having failed:
the step SHALL NOT be recorded as applied, and the failure policy SHALL govern.

#### Scenario: An already-applied step is skipped
- **WHEN** a step's `check` block exits 0
- **THEN** the runner SHALL NOT execute that step's `apply` block
- **AND** SHALL report the step as skipped

#### Scenario: A check that cannot run aborts rather than re-applying
- **WHEN** a step's `check` block exits 2
- **THEN** the runner SHALL abort
- **AND** SHALL NOT execute that step's `apply` block

#### Scenario: A failing pre-condition aborts even at a terminal
- **WHEN** a step's `precondition` block exits non-zero and standard input is a terminal
- **THEN** the runner SHALL abort without prompting

#### Scenario: A failing verify does not mark the step applied
- **WHEN** a step's `apply` succeeds and its `verify` exits non-zero
- **THEN** the runner SHALL NOT report that step as applied
- **AND** the failure policy SHALL govern

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

Because this output is reproduced into whatever log the runner writes to,
migration authors SHALL NOT emit secrets or personal data from a block's
diagnostics. A runner cannot screen this, and CI logs are frequently more widely
readable than the repository.

#### Scenario: A multi-line remediation message survives intact
- **WHEN** a `precondition` block writes a two-option remediation message to stderr and exits 3
- **THEN** the runner SHALL emit that message unchanged, including both options
- **AND** SHALL exit non-zero

### Requirement: Unattended failure aborts without rolling back

When an `apply` or `verify` block fails and standard input is a terminal, the
runner SHALL prompt with three options: retry the step, skip it with a warning
and continue to the next step with the migration recorded as partial, or roll
back the steps already applied in reverse document order.

When standard input is not a terminal, the runner SHALL abort in place, SHALL
report on standard error which steps applied, and SHALL NOT roll back.

The absence of anyone to ask is not consent. A half-applied tree is also
evidence of what went wrong, which an automatic rollback destroys. Runners SHALL
offer an explicit means of selecting the failure policy directly, so that
automation is never dependent on whether a terminal happens to be attached.

The failed step is not among "the steps already applied" and its rollback SHALL
NOT be run: a step that failed part-way through `apply` is in an unknown state,
and running its rollback could destroy work the rollback did not create.
"Recorded as partial" and "which steps applied" are satisfied by the runner's
own diagnostic output; this format defines no journal or state file.

#### Scenario: A non-interactive failure preserves completed work
- **WHEN** step 2 of a two-step migration fails with no terminal attached
- **THEN** step 1's changes SHALL remain on disk
- **AND** the runner SHALL report which steps applied
- **AND** SHALL exit non-zero

#### Scenario: Skip continues rather than aborting
- **WHEN** the failure policy is skip and step 2 of a three-step migration fails
- **THEN** the runner SHALL continue to step 3
- **AND** SHALL report the migration as partial

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

### Requirement: Check and pre-condition blocks do not mutate the tree

A `check` or `precondition` block SHALL NOT write to the working tree. Their
role is to answer a question, and a runner's dry-run mode executes them.

This is an obligation on the migration author, not something a runner can
enforce. It is stated because the alternative is a dry-run that promises not to
write while executing arbitrary shell — a guarantee the runner cannot keep and
should not make.

#### Scenario: An idempotency check only reads
- **WHEN** a step's `check` block runs against an unmodified tree
- **THEN** the tree SHALL be unchanged afterwards

### Requirement: Dry-run reports the source it would execute

A runner's dry-run mode SHALL evaluate each step's `check` and `precondition`
blocks, SHALL print the source of the `apply` block each pending step would run,
and SHALL NOT itself write to the working tree. A `precondition` failing during
a dry run SHALL abort the dry run and exit non-zero, exactly as it would during
a real run.

Dry-run does not report a diff. Producing one would require applying the step,
which is the thing dry-run exists not to do.

#### Scenario: Dry-run prints sources and writes nothing
- **WHEN** a migration is run in dry-run mode against a tree where no step has been applied
- **AND** every `check` and `precondition` block honours the non-mutation requirement
- **THEN** the runner SHALL print each pending step's `apply` source
- **AND** the working tree SHALL be unchanged
- **AND** the runner SHALL exit zero
