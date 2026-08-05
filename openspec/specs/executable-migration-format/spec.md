# executable-migration-format Specification

## Purpose
TBD - created by archiving change executable-migration-format. Update Purpose after archive.
## Requirements
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

A `### Step ` heading SHALL be recognised only **outside** a fenced code block.
Step bodies contain shell, and shell contains heredocs; a migration whose
`apply` block writes a document containing the text `### Step 2` must not have
its own step silently truncated at that line.

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

#### Scenario: A step heading inside a fence does not end the step
- **WHEN** a step's `apply` block contains a heredoc whose body includes the line `### Step 2`
- **THEN** the extractor SHALL return that block in full
- **AND** SHALL NOT treat the heredoc line as the start of a new step

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

### Requirement: Every fence a migration opens SHALL be closed

The format linter SHALL reject a migration in which a fenced code block is
opened and never closed before end of file.

A step's role listing is read from a fence's *opening* line, but block
extraction only succeeds on that fence's *closing* line. An unclosed fence is
therefore present to anything that lists roles but absent to anything that
extracts a block body — a document in that state lints clean and then fails
at runtime reporting a role "missing" that the linter itself just confirmed
was there. This is a gap in the linter's own role listing, not a runner
defect, and closing it there is what keeps "lints clean" meaning "will run,"
rather than "was examined and happened not to notice."

#### Scenario: An unclosed fence is rejected
- **WHEN** a step's `precondition` fence is the last thing in the document and is never closed
- **THEN** the format linter SHALL report a violation naming the step and the line the fence opened on
- **AND** SHALL exit non-zero, even though every role the step requires appears to be present

### Requirement: A tagged fence's body SHALL contain an executable statement

The format linter SHALL reject a role-tagged fence whose captured body
contains no executable statement, for any of the five roles. A body has no
executable statement when nothing remains after discarding blank lines,
whole-line `#` comments, and whole-line no-op builtins (`:`, `true`).

`bash -c` exits 0 on every one of those: on `''`, on blank lines, on a body of
nothing but comments, and on a bare `:`. The three-valued `check` contract
reads exit 0 as "already applied," so a `check` fence in any of those states
makes a runner report a step skipped and apply nothing on a tree where nothing
was ever applied — the same silent-no-op class an un-annotated fence produces,
one layer further in: this fence *is* tagged, and still does nothing. An
`apply` in the same state is attempted and vacuous; a `precondition` passes
just as emptily.

The comment case is the one that matters in practice, because it is what a
leftover placeholder looks like — `# TODO: check whether the allowlist is
already hardened` — and it is one character past a test for "empty or
whitespace-only." The `check` variant is strictly worse than the `apply`
variant: the step is never attempted at all rather than attempted and
vacuous.

A bare `:` or `true` is counted as non-executable **only as an entire body**.
Both appear legitimately inside larger bodies (`while :; do`, `: "${VAR:?}"`)
and SHALL NOT be rejected there.

**The requirement is bounded, and the bound is part of it.** The test is
whole-line and lexical: it rejects a body that is provably inert by
inspection. It SHALL NOT be read as detecting a body that executes and
accomplishes nothing. `true; true`, `:;:`, `( : )`, `exit 0` and
`echo "checking whether the allowlist is hardened"` all satisfy this
requirement while changing nothing, and as a `check` each exits 0 — which the
three-valued contract reads as "already applied". A conforming implementation
is NOT required to reject those, and SHOULD NOT be widened to try: whether a
shell body accomplishes anything is not decidable from its text, and an
implementation that guesses rejects valid migrations, which is the more
expensive error of the two. Confirming that a step's blocks do what the step
claims remains an author and reviewer obligation.

#### Scenario: A body that executes but accomplishes nothing is accepted
- **WHEN** a step's `check` fence contains `true; true`
- **THEN** the format linter SHALL NOT report a violation for that fence
- **AND** the limit SHALL be documented rather than treated as a defect to close

#### Scenario: A tagged-but-empty check is rejected
- **WHEN** a step's `check` fence is opened as ` ```bash role=check ` and its body is empty
- **THEN** the format linter SHALL report a violation naming the step and the role
- **AND** SHALL exit non-zero

#### Scenario: A check fence containing only a comment is rejected
- **WHEN** a step's `check` fence contains a single `# TODO:` line and nothing else
- **THEN** the format linter SHALL report a violation naming the step and the role
- **AND** SHALL exit non-zero
- **AND** the runner SHALL NOT report the step as skipped (already applied)

#### Scenario: A fence whose whole body is a no-op builtin is rejected
- **WHEN** a step's `check` fence contains only the line `:`
- **THEN** the format linter SHALL report a violation and exit non-zero

#### Scenario: A no-op builtin inside a larger statement is accepted
- **WHEN** a step's `check` fence contains `while :; do break; done`
- **THEN** the format linter SHALL NOT report a violation for that fence

### Requirement: A fence delimiter emitted from inside a block SHALL be rejected

A block's captured body ends at its fence's closing delimiter. The format
linter SHALL therefore reject a role-tagged fence whose body is truncated by a
fenced-code-block delimiter emitted from within it. At minimum it SHALL reject
a tagged fence whose terminating delimiter line carries a non-empty info
string — a closing fence may not carry one, so such a line is never a
legitimate terminator — and a tagged fence whose captured body leaves a
heredoc unterminated.

This is the same hazard the `### Step` heading rule already closes, for the
fence delimiters themselves. A heredoc writing a ` ```bash ` line into a
markdown file is the ordinary way a migration patches an instruction file or a
skill. The truncated body still runs and still succeeds — an unterminated
heredoc writes its partial payload and exits 0 — so the runner reports the
step applied, and the step's own idempotency check then matches the truncated
output, which makes the migration permanently self-certify as done. Nothing
about this is visible to role-presence, fence-balance, or emptiness checks: the
role is read from the opening line, the fences balance because the inner one
closes and the real closer re-opens, and the truncated body is not empty.

The heredoc half of this requirement SHALL recognise a delimiter quoted with
`'`, `"` or a leading backslash (`<<\EOF`), which the shell treats
identically. Recognising only the first two leaves the requirement's own
worst case reachable: when the truncating line is a **bare** delimiter, the
info-string half is silent by construction, so an unrecognised heredoc opener
means neither half fires.

A four-backtick outer fence is not an escape, because the info-string grammar
requires the literal `bash` immediately after the delimiter and a four-backtick
opener does not satisfy it. A migration SHALL instead use one of three forms:
emit the line indirectly (`printf '%s\n' '```bash'`); indent it by up to three
spaces, which keeps the emitted block a valid fenced block while moving the
delimiter off column 1 at the cost of a leading space in the output; or use a
tab-stripping heredoc (`<<-`) with a tab-indented payload, which moves the
delimiter off column 1 in the source and restores it to column 1 in the
emitted file. The third form depends on the indentation being tabs, since
`<<-` strips tabs only.

#### Scenario: A backslash-quoted heredoc delimiter is recognised
- **WHEN** a step's `apply` block opens `<<\EOF` and the captured body is truncated by a bare fence delimiter before the terminator
- **THEN** the format linter SHALL report the unterminated heredoc and exit non-zero

#### Scenario: A heredoc emitting a fence delimiter is rejected
- **WHEN** a step's `apply` block opens a heredoc whose body contains a line beginning with a fenced-code-block delimiter and an info string
- **THEN** the format linter SHALL report a violation naming the step, the role, and the truncating line
- **AND** SHALL exit non-zero
- **AND** the runner SHALL NOT execute the truncated body

#### Scenario: An unterminated heredoc is rejected even with no fence involved
- **WHEN** a step's `apply` block opens a heredoc whose terminator never appears in the captured body
- **THEN** the format linter SHALL report a violation and exit non-zero

#### Scenario: A correctly terminated heredoc is accepted
- **WHEN** a step's `apply` block opens a heredoc whose body contains the line `### Step 2` and whose terminator is present
- **THEN** the format linter SHALL NOT report a violation for that fence

#### Scenario: A comment that merely mentions a heredoc operator is accepted
- **WHEN** a step's `apply` block contains a whole-line `#` comment mentioning `<<EOF` and opens no heredoc
- **THEN** the format linter SHALL NOT report a violation for that fence
- **AND** the runner SHALL apply the step

A whole-line `#` comment is prose, not a redirection operator. This scenario
exists because the linter did reject exactly this — a migration avoiding the
truncation hazard the way this specification recommends, and saying so in a
comment. A heredoc-detection rule narrow enough to miss a real opener is a
missed detection; one wide enough to read an opener out of a comment is a
false accusation, and the two are not interchangeable costs.

### Requirement: An in-scope migration SHALL declare at least one step

The format linter SHALL reject an in-scope migration that declares no `### Step`
heading.

§08 has always required every migration body to contain at least one step, and
a runner is separately required to refuse a zero-step document. Leaving the
check to the runner alone is not sufficient: an adopting host is required to
run the **linter** in CI, and CI does not run the runner — so a document that
cannot run would leave that CI green. A step heading typed at the wrong level
(`## Step 1:` for `### Step 1:`) is the ordinary way a migration ends up with
no steps, and it produces a document that lints clean and refuses to run.

#### Scenario: A migration with no step heading fails the linter
- **WHEN** an in-scope migration's only step heading is written `## Step 1:`
- **THEN** the format linter SHALL report a violation and exit non-zero
- **AND** the runner SHALL refuse to execute it

### Requirement: An in-scope migration SHALL declare `applies_to`

The format linter SHALL reject an in-scope migration whose frontmatter omits
`applies_to`. Only the field's presence SHALL be checked; which paths an
`apply` block actually writes to remains unenforceable and is stated elsewhere
as an author obligation.

At or above the threshold `applies_to` is the write boundary an `apply` block
may not cross, not merely plan-output metadata. A boundary that can be omitted
entirely is not a boundary: with no `applies_to` at all, the permitted write
set is undefined and every statement about what that migration's rollback owes
the working tree is vacuous.

#### Scenario: A missing applies_to is a violation
- **WHEN** an in-scope migration's frontmatter carries no `applies_to` field
- **THEN** the format linter SHALL report a violation naming the missing field
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

### Requirement: A runner executes only migrations the linter judged

A runner SHALL refuse to execute a migration that the format linter declined to
judge — that is, one below its host's threshold that does not opt in. Refusal
SHALL be reported as out of scope, distinctly from a format violation.

Otherwise the format gate evaporates on rename. A migration numbered below the
threshold is skipped by the linter and exits 0 clean, so a runner that treats
"the linter did not object" as "the linter approved" will execute a document
with no rollback block, no pre-condition, or no steps at all. The linter's
silence there means *not examined*, not *examined and found well-formed*, and a
runner must not confuse the two.

This also matches what below-threshold means: those migrations are frozen
history that nothing should replay. A runner asked to apply one is being asked
to do something the design has already ruled out.

#### Scenario: A below-threshold migration is refused rather than run unjudged
- **WHEN** a runner is given a migration whose filename ID is below the host's threshold
- **AND** that migration declares no `migration_format`
- **THEN** the runner SHALL exit non-zero reporting it as out of scope
- **AND** SHALL NOT execute any block

#### Scenario: An opted-in migration below the threshold is runnable
- **WHEN** a below-threshold migration declares `migration_format: executable` and satisfies the format
- **THEN** the runner SHALL execute it normally

### Requirement: Refusal is distinguishable from failure by exit code

A runner SHALL use a single reserved exit code for every refusal that happens
before any block executes — every such refusal SHARES that one code — and
SHALL reserve other non-zero codes for failures that occur once execution
has begun.

A caller — a CI job especially — needs to tell "refused, nothing ran, the tree
is untouched" from "ran partway, the tree may have changed" without parsing
stderr. Collapsing both into exit 1 makes the safe outcome and the dangerous one
indistinguishable at exactly the moment the distinction matters most.

#### Scenario: Pre-execution refusals share one code
- **WHEN** a runner refuses because of a lint violation, a zero-step document, a step with no apply block, or an out-of-scope migration
- **THEN** it SHALL exit with the same reserved refusal code in every case
- **AND** the working tree SHALL be unchanged

#### Scenario: A runtime failure is a different code
- **WHEN** a step's `apply` fails after earlier steps applied
- **THEN** the runner SHALL exit with a code distinct from the refusal code

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
violation, **including below the threshold** — "skipped entirely" means a
migration that declares nothing, not one that declares something unrecognised.
A historic migration carries no `migration_format` line at all, so this cannot
retroactively fail one; a below-threshold file that does declare a value has
been touched deliberately, and a typo there is worth reporting.

Reading the ID from the filename rather than from frontmatter is what makes the
scope unevadable: a frontmatter field can be omitted, and an omitted field must
not be the difference between a judged migration and an unjudged one. The
declaration is retained as a human-readable assertion and cross-checked against
the filename, which is why the two can only disagree in the safe direction.

A migration's ID SHALL be the leading digits of its filename, which SHALL match
`<digits>-<slug>.md`. A file whose name carries no parseable leading ID SHALL be
reported as a violation rather than skipped — an unreadable ID must never be the
quiet route out of the linter's scope.

Thresholds SHALL be declared per host in a file the linter reads, as rows of
`<host-repo-name> <threshold-id>`, with `#` introducing a comment and blank
lines ignored. The host SHALL be named explicitly by the caller; the linter
SHALL NOT infer it. A linter invoked against an in-scope migration without a
resolvable threshold SHALL fail rather than proceed, and a host name with no row
SHALL be an error, not a default.

There is deliberately no "no threshold given" path that silently judges nothing.
A caller who omits the host would otherwise find every migration out of scope,
every lint trivially clean, and — because the runner lints before executing —
every migration runnable. That reopens the silent-no-op hole one layer down.

#### Scenario: A missing host is an error, not an empty scope
- **WHEN** the linter is invoked with no host and no threshold
- **THEN** it SHALL exit non-zero reporting that no threshold could be resolved
- **AND** SHALL NOT report the migration as clean

The linter is invoked per migration file. A host wiring it into CI SHOULD
enumerate migrations as `migrations/[0-9]*.md` rather than `migrations/*.md`,
because an ID-less filename is a MUST-report violation with no carve-out and
`migrations/` is also the conventional home of a `migrations/README.md`. The
narrower glob is the fix; a `README.md` exemption inside the linter is not,
since "an unreadable ID is never a quiet route out of scope" would then have a
named exception a migration could be renamed into.

#### Scenario: An unparseable filename is a violation
- **WHEN** the linter is invoked against a file whose name carries no leading numeric ID
- **THEN** it SHALL report a violation and exit non-zero

#### Scenario: A frontmatter ID contradicting the filename is a violation
- **WHEN** a file named `0016-example.md` declares `id: 0005` in frontmatter
- **THEN** the linter SHALL report the disagreement and exit non-zero
- **AND** SHALL have used the filename's ID to decide scope

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
migration authors SHALL NOT emit secrets or personal data from **any** block's
output — `check`, `precondition`, `apply`, `verify` or `rollback` — nor from an
`apply` block's source, which dry-run prints. A runner cannot screen this, and
CI logs are frequently more widely readable than the repository.

Each block SHALL be executed in its own shell. A step therefore SHALL NOT rely
on environment variables, shell functions, or a working directory established by
an earlier block or an earlier step: such a dependency would be invisible in the
document and would break the moment a step is skipped as already applied.

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

Rollback SHALL be performed only on an explicit choice. End-of-input, an empty
answer, or an unrecognised answer SHALL abort without rolling back. A prompt
whose default is destruction is not consent, and a runner reaching EOF in a
pipeline must not read silence as permission to undo work.

A step whose `apply` failed part-way SHALL NOT have its rollback run: its state
is unknown, and the rollback could destroy work it did not create. A step whose
`apply` succeeded and whose `verify` then failed SHALL be included in a
rollback: `apply` completed, so its rollback describes a state that actually
exists. The two failures are not interchangeable.

If a `rollback` block itself fails during an interactive rollback, the runner
SHALL report which rollbacks succeeded and which failed, SHALL continue
attempting the remainder, and SHALL exit non-zero. Stopping at the first failed
rollback would leave a tree that is neither migrated nor restored, with no
record of how far it got.

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

#### Scenario: Silence is not consent to roll back
- **WHEN** the runner prompts after a failure and standard input reaches end-of-file
- **THEN** the runner SHALL abort without running any rollback
- **AND** SHALL exit non-zero

#### Scenario: A verify failure is rolled back, a partial apply is not
- **WHEN** an interactive rollback follows a step whose `apply` succeeded and whose `verify` failed
- **THEN** that step's rollback SHALL be run
- **AND WHEN** the rollback instead follows a step whose `apply` itself failed
- **THEN** that step's rollback SHALL NOT be run

#### Scenario: An explicit override selects the policy
- **WHEN** the runner is invoked with an explicit failure-policy selection
- **THEN** it SHALL use that policy rather than the one derived from whether a terminal is attached

### Requirement: Rollback blocks are exercised independently of the runner

Because the non-interactive path never reaches a `rollback` block, the migration
harness that ships with this format SHALL exercise each `rollback` block
directly against its own step's post-apply state. Hosts SHOULD adopt the same
practice when they adopt the format; the obligation is stated as a SHOULD for
them because no host is touched by this change and no host harness exists yet.

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

### Requirement: Within the executable form's scope, an apply block SHALL NOT touch paths outside `applies_to`

For a migration within the executable form's scope (see "An ID threshold
scopes which migrations must be executable" — the same population whose
steps must express role-tagged fenced blocks at all), a step's `apply` block
SHALL modify only files and directories the migration's `applies_to` field
declares. `applies_to` is therefore more than plan-output metadata for such a
migration: it is the boundary that makes the rollback-parity scenario above
meaningful. A rollback's obligation to return the working tree to its
pre-apply state SHALL be read as bounded by what `apply` was permitted to
touch — not as a promise to undo an effect `apply` should never have
produced in the first place. Below the threshold this requirement does not
bind: `applies_to` remains plan-output metadata only, and the fleet's
existing practice there is unaffected.

This excludes bookkeeping that does not outlive the step: a scratch sibling
file the step itself deletes before the step ends, a path created via
`mktemp`, and `mkdir -p` of a declared path's parent directory. None of these
are "an effect that should never have occurred" in the sense this
requirement targets — they are working storage gone by the time a rollback
would ever need to reason about the tree. Without this carve-out the
requirement would forbid the idiom every host's existing migrations already
use for exactly this purpose; the threshold scoping above already exempts
that existing history as frozen, but a *new*, at-or-above-threshold migration
should not have to avoid `mktemp` just to stay conformant.

A fleet audit for this requirement (Stage 2 review) also surfaced a case this
carve-out deliberately does **not** cover: `claude-workflow`'s migration
`0034` makes a permanent, deliberate `.pre-0034` rollback backup that lives
outside its `applies_to` by design and is not deleted before the step ends.
`0034`'s ID (34) is below `claude-workflow`'s own threshold (35, per
`THRESHOLDS`), so it is exempt from this requirement as frozen history, not
because its backup fits the carve-out — a future migration wanting the same
permanent-backup pattern at or above its host's threshold would need to
declare the backup path in `applies_to`.

This is an obligation on the migration author, in the same unenforced sense
as the non-mutation rule below: no structural rule in this linter checks
which paths an `apply` block actually writes to, so a violation is only
ever caught by review or by its symptom (a rollback that does not restore
something). Stating it normatively is still worth doing, because the
alternative — silence — reads as license: an `apply` that reaches outside
its declared scope, and a `rollback` that consequently cannot undo it,
would otherwise look like a bug in the format rather than a violation of
it.

`0046-apply-dropped-by-step1.md`, a fixture in this change, is the concrete
case this resolves: its step 1 `apply` rewrites a workdir-resident copy of
the migration document itself — a path absent from its `applies_to`, which
declares only `s1.txt` and `s2.txt` — and its `rollback` (`rm -f s1.txt`)
does not restore that copy. Under this requirement, step 1 is non-conformant
in that one respect; the fixture exists to exercise a runner's defense
against a document that mutates out from under the dispatch loop (the
`BLOCK_MISSING` branch — see the "runner executes only migrations the linter
judged" requirement's own exit-code discussion), not to demonstrate a
compliant rollback. Its rollback's failure to restore the document is
therefore not a defect in the fixture, the runner, or this spec — it is the
predicted consequence of an apply that reached where it should not have.

#### Scenario: An apply that touches an undeclared path is non-conformant
- **WHEN** an in-scope step's `apply` block modifies a file not listed in the migration's `applies_to`, and that file is not scratch bookkeeping the step deletes before it ends
- **THEN** that step's rollback is not required to restore that file
- **AND** the step SHALL be considered non-conformant with this requirement, independent of whether the format linter can detect it

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

A runner's dry-run mode SHALL evaluate `check` and `precondition` up to and
including the first pending step, SHALL print the source of the `apply` block
each pending step would run, and SHALL NOT execute any `apply`, `verify` or
`rollback` block. A `precondition` failing during a dry run SHALL abort the dry
run and exit non-zero, exactly as it would during a real run, and the
three-valued `check` contract SHALL apply unchanged.

The blocks of steps *after* the first pending step SHALL NOT be evaluated, and
their apply sources SHALL be reported as unevaluated. Those blocks describe a
tree that only an earlier `apply` would have created, so running them asks a
question about a state that does not exist. A runner MUST NOT manufacture that
state — not in the working tree, and not in a copy of it.

A scratch copy is not a sandbox. Executing `apply` against a mirrored directory
still runs arbitrary shell with the caller's environment, credentials and
network: it can write to `$HOME` or any absolute path, push to a real remote
using the `.git` the copy inherited, or install globally. A copy made with
ordinary recursive tools also preserves symlinks, so even a purely relative
write can land outside it. "The working tree was not modified" is then a
property of the migration that happened to be tested, not of the runner.

Dry-run does not report a diff. Producing one would require applying the step,
which is the thing dry-run exists not to do.

#### Scenario: Dry-run prints sources and writes nothing
- **WHEN** a migration is run in dry-run mode against a tree where no step has been applied
- **AND** every `check` and `precondition` block honours the non-mutation requirement
- **THEN** the runner SHALL print each pending step's `apply` source
- **AND** the working tree SHALL be unchanged
- **AND** the runner SHALL exit zero

#### Scenario: Dry-run does not evaluate steps behind a pending one
- **WHEN** step 1 is pending and step 2's `check` describes a file that only step 1's `apply` would create
- **THEN** the runner SHALL NOT execute step 2's `check`
- **AND** SHALL report step 2's apply source as unevaluated

#### Scenario: A dry run predicts the run it precedes
- **WHEN** a migration's first step has a `check` that exits 2
- **THEN** the dry run SHALL abort and exit non-zero, exactly as the real run does

