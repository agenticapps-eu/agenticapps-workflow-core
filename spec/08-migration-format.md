---
id: 08-migration-format
section_type: declarative-contract
spec_version: 2.0.0
---

# 08 — Migration Format

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and
runtime semantics are at the host's discretion. The keywords MUST,
MUST NOT, SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Concept

A migration is a versioned, idempotent, atomic, dry-runnable patch
that brings an installed AgenticApps workflow scaffolding from one
version to the next. The `migrations/` directory is the single source
of truth for what each version looks like on disk. The existing-project
update flow consumes it directly, applying only those migrations not yet
applied — those whose `to_version` is newer than the project's installed
version (equivalently, the chain of migrations whose `from_version` is at or
after the installed version). This matches the per-field rules below: a
migration is skipped when the installed version is below its `from_version`
or already at or beyond its `to_version`.

The fresh-project setup flow MUST arrive at the same end state that a
full `0000-baseline`→latest replay produces — but it need not get there
by replaying. Two strategies are conformant: **replay** (setup applies
every migration from `0000-baseline` forward) and **snapshot** (setup
installs a prebuilt artifact assembled from those same sources, with a
drift guard in CI proving artifact and sources agree). The Conformance
section below is the normative statement.

What this spec forbids is a *second source of truth*: a setup path that
writes a shape derived from somewhere other than the migration sources,
so that "what does v1.3.0 look like on disk" is maintained twice and can
silently diverge. A guarded snapshot is not a second source of truth —
it is a build artifact of the first one, and the guard is what makes
that claim checkable rather than merely asserted.

ADR-0013 established the migration framework and assumed both flows
would replay. ADR-0018 supersedes that assumption: a chain containing
prose, agent, or interactive steps cannot be shell-replayed, so the end
state — not the mechanism — is what the spec makes normative.

## Requirements

### File location and naming

- **MUST** store migrations in a `migrations/` directory at the
  scaffolder repo root.
- **MUST** name each migration file `NNNN-{kebab-slug}.md` where
  `NNNN` is a four-digit zero-padded sequential ID and `kebab-slug`
  is a short kebab-case description.
- **MUST** use sequential IDs starting at `0000`. Sequential IDs
  decouple "I have a new feature" from "what version number does
  that imply" — multiple migrations MAY ship inside one semver
  release.
- **MUST** treat `0000-baseline.md` as special: it codifies the
  starting state of a fresh project at the workflow scaffolder's
  initial supported version. Every other migration is incremental.

### Frontmatter

Every migration MUST include YAML frontmatter with at minimum:

| Field | Required | Meaning |
|---|---|---|
| `id` | MUST | Sequential migration ID (matches filename prefix) |
| `slug` | MUST | Kebab-case slug (matches filename middle) |
| `title` | MUST | Human-readable one-line title |
| `from_version` | MUST | Installed version that this migration upgrades from. The update flow skips this migration if the project's installed version is less than `from_version`. |
| `to_version` | MUST | Version after this migration successfully applies. The update flow writes this to the project's installed-version field on success. |
| `applies_to` | MUST | List of files / directories this migration touches (for impact awareness in plan output; at or above the executable-form threshold it is also the scope boundary described in "Executable form" below) |
| `requires` | MAY | List of external dependencies (skills, tools, CLIs) that must be installed before this migration applies. Each entry SHOULD include `verify` (test command) and `install` (install command). |
| `optional_for` | MAY | List of conditional groups. Each entry has a `tag`, a `detect` shell command, and a `note`. Steps tagged with the same `tag` are skipped if `detect` returns non-zero. |

### Step structure

Every migration body MUST contain at least one step. Every step MUST
have four sections, in this order:

| Section | Purpose |
|---|---|
| **Idempotency check** | A shell command that returns 0 if the step has already been applied. The update flow skips applied steps without prompting. |
| **Pre-condition** | A shell command that must return 0 before the step can apply (e.g. "the file exists and has the section we're patching"). If pre-condition fails, the step errors with a specific message rather than silently producing wrong output. |
| **Apply** | The exact patch — markdown content to insert, JSON entry to add, file to create. |
| **Rollback** | How to revert this step. Either a unique anchor comment to delete, an explicit `git revert` instruction, or "manual — see VERIFICATION.md for resolution". |

### Executable form

Everything above this point holds for every migration, unconditionally. This
subsection is an ADDITION, not a replacement: it binds a step's four sections
to machine-dispatchable fenced blocks only for migrations at or above a
host's declared threshold (see "Threshold scope" below). A migration below
its host's threshold satisfies the format by prose, agent instructions, or
interactive steps exactly as before — ADR-0013's and ADR-0018's
accommodation for non-replayable steps is unchanged.

At or above the threshold, each of a step's four sections MUST be backed by a
fenced code block whose info string carries a role tag, so that a runner can
dispatch the section without interpreting prose:

| Role | Heading it MUST follow |
|---|---|
| `check` | **Idempotency check:** |
| `precondition` | **Pre-condition:** |
| `apply` | **Apply:** |
| `verify` | **Verify:** (optional — see below) |
| `rollback` | **Rollback:** |

The prose headings are retained rather than replaced — they already carry
the document's readable structure. What the role tag adds is the one thing a
heading cannot express: that a given fence is, or is not, meant to run.

**Info-string grammar.** A tagged fence's info string MUST match exactly:
the literal `bash`, one or more spaces or tabs, `role=`, a role name, then
nothing but optional trailing whitespace. A fence carrying additional keys (` ```bash
role=apply retry=2 `), a non-`bash` language (` ```yaml role=apply `), a
different case, or any other trailing content is not a valid tagged fence
and MUST be rejected by the format linter — "close enough" is not honoured
silently.

**Un-annotated fences are illustration.** A ` ```bash ` fence carrying no
`role=` tag MUST be treated as illustration: it MUST NOT be executed by any
runner and MUST NOT be reported as contributing a role. This is what lets a
migration show an explanatory or contrasting snippet beside the commands it
actually runs.

**Roles per step.** Each step MUST carry exactly one `check`, one
`precondition`, one `apply`, and one `rollback` block; it MAY carry at most
one `verify` block. No role may appear more than once within a step. `verify`
is the one optional addition to §08's existing quartet — a step whose
`apply` is its own evidence has nothing further to assert.

**Roles are recognised only where declared.** A role-tagged fence found under
the wrong heading (e.g. a `role=apply` fence following **Rollback:**) MUST be
rejected, naming both the heading it expected and the heading it found. A
`role=` value that is not one of the five valid roles MUST be rejected,
quoting the offending value — silently ignoring an unrecognised value would
demote a real command to a comment, so that a migration lints clean, runs to
completion, reports success, and has done nothing.

**Every opened fence MUST be closed before end of file.** A step's role
listing is read from a fence's *opening* line, but a runner can only ever
execute a fence's *closing* line as the end of its captured body. A fence
that opens and is never closed is therefore visible to role-presence checks
but absent to block extraction: the document would lint clean and then fail
at runtime reporting a role "missing" that the linter just confirmed was
present. The format linter MUST reject an unclosed fence as a violation of
its own, distinctly from a missing role.

**A tagged fence's body MUST NOT be empty or whitespace-only,** for any of
the five roles. `bash -c ''` (and a fence containing only blank lines) exits
0, which the three-valued `check` contract in the Atomicity contract below
reads as "already applied" — so a tagged-but-empty `check` (or
`precondition`) fence is a silent no-op indistinguishable from success: the
runner reports the step skipped or the pre-condition satisfied, and applies
nothing. The format linter MUST reject a tagged fence whose body is empty or
whitespace-only.

**Steps are numbered consecutively and bounded by the next step heading.** A
migration's steps MUST be numbered consecutively from 1; a gap in the
numbering MUST be rejected by the format linter as a violation. Independently
of that rule, a step's extent MUST be bound by the *next* `### Step` heading
of any number — never by "the heading numbered N+1" — so that a numbering
gap cannot silently merge two steps into one and hide the second step's
roles from both the extractor and the linter.

A `### Step` heading MUST be recognised only **outside** a fenced code
block. Step bodies are shell, and shell contains heredocs: a migration whose
`apply` block writes a document containing the literal line `### Step 2`
MUST NOT have its own step boundary computed from that line.

A `migration_format` frontmatter value other than `executable` MUST be
rejected by the format linter, regardless of whether the migration is at,
above, or below its host's threshold. A migration below the threshold that
declares nothing at all is skipped entirely (see "Threshold scope"); one
that declares an unrecognised value has been touched deliberately, and a
typo there is worth reporting rather than silently ignoring.

**`applies_to` is a scope boundary, not only impact-awareness metadata, for a
migration at or above the threshold.** A step's `apply` block MUST NOT
modify any file or directory outside the paths its migration's `applies_to`
declares. This is what makes the Rollback contract meaningful rather than
aspirational: a rollback's obligation to return the working tree to its
pre-apply state extends only as far as `apply` was permitted to reach. A step
whose `apply` reaches outside its declared scope is non-conformant, and the
format does not require — and no runner or test harness can be expected to
provide — a rollback for an effect that should never have occurred.

This excludes ordinary bookkeeping that never outlives the step: a scratch
sibling file the step itself deletes before the step ends, a `mktemp`-created
path, and `mkdir -p` of a declared path's parent directory. None of those are
"an effect that should never have occurred" — they are working storage, gone
by the time the step's rollback would ever need to reason about the tree.

**This is stated as an obligation on the migration author, in the same
unenforced sense as the non-mutation rule in "Non-mutation and diagnostics"
below: no rule in this format's linter checks which paths an `apply` block
actually writes to.** A host MAY add such a check; none is required, and none
ships with the reference linter today.

### Threshold scope

The executable form above binds only at or above a host-declared threshold
migration ID.

- **MUST** determine a migration's ID from its **filename**, matching
  `<digits>-<slug>.md`, never from frontmatter. A filename cannot be
  forgotten the way a frontmatter field can be omitted, which is what keeps
  the threshold unevadable.
- A file whose name carries no parseable leading numeric ID **MUST** be
  reported as a violation, never silently skipped.
- **MUST** judge (require and enforce the executable form on) every
  migration whose filename ID is at or above the host's declared threshold,
  and **MUST** skip entirely — reporting no violation — every migration
  below it that declares no `migration_format`.
- A migration at or above the threshold **MUST** declare
  `migration_format: executable` in frontmatter; omitting it **MUST** be
  reported as a violation naming the missing field.
- A migration below the threshold **MAY** declare `migration_format:
  executable` to opt in early; once declared, it is judged exactly as if it
  were in scope. A declaration MAY add a migration to scope; it MUST NOT be
  used, and has no mechanism, to remove one that the filename ID already
  put in scope.
- Frontmatter `id`, where present, **MUST** be cross-checked against the
  filename ID; a mismatch (or a non-numeric frontmatter `id`) **MUST** be
  reported as a violation. This cross-check can only disagree in the
  direction of "frontmatter is wrong" — the filename alone decides scope.
- A threshold **MUST** be declared for each host in a form the linter reads
  unambiguously (one threshold per host) — the spec is silent on who declares
  it or where; core's own reference linter reads it from a file it ships
  (`THRESHOLDS`), which satisfies this without requiring any host itself to
  have written anything. A linter invoked without a
  resolvable threshold for the host in question **MUST** fail rather than
  proceed — there is deliberately no "no threshold given" path that treats
  an absent threshold as an empty scope, because that would make every
  migration out of scope, every lint trivially clean, and (per "A runner
  lints before executing" below) every migration runnable.

A runner **MUST** refuse to execute a migration that the format linter did
not judge — i.e. one below its host's threshold that does not opt in —
reporting that refusal as *out of scope*, distinctly from a format
violation. The linter's silence on such a migration means *not examined*,
not *examined and found well-formed*; a runner that conflates the two would
let a below-threshold document with no rollback block, no pre-condition, or
no steps at all be renamed into apparent compliance.

A runner **MUST** use a single reserved exit code for every pre-execution
refusal — a lint violation, a zero-step document, a step with no `apply`
block, or an out-of-scope migration all SHARE one code — and that code
**MUST** be distinct from any code used for a failure that occurs once
execution has begun. A caller cannot otherwise tell "refused, the tree is
untouched" from "ran partway, the tree may have changed" without parsing
diagnostic text. (This is deliberately one shared code, not one code per
refusal kind: the caller's only load-bearing question is *did anything run*,
and a distinct code per kind would answer a question nobody needs answered
that way.)

This exit-code contract is scoped to refusal versus post-execution failure;
it does not cover usage errors (the runner itself was invoked wrong — a
missing required flag, an unresolvable threshold) or environment errors (the
named document does not exist or cannot be read). Those **MAY** use their own
codes, distinct from both the refusal code and the failure code, at the
host's discretion — they are not migration-refusal outcomes at all, and nothing
above requires them to share the refusal code.

### A runner lints before executing

Rejecting a bad migration at lint time is not sufficient on its own, because
nothing obliges the operator to have linted first. A runner:

- **MUST** lint the migration before executing any step, and **MUST** abort
  without executing anything if the linter reports a violation.
- **MUST** abort, before executing anything, if an in-scope migration yields
  zero steps, or if any step yields no `apply` block (including a
  tagged-but-empty one).

A runner that will execute whatever it is handed can be given an
all-illustration document — every fence un-annotated, or every role tag
absent — and report success having changed nothing: the exact silent-no-op
failure this format exists to prevent, and most dangerous when the step it
silently skipped was the security-relevant one.

### Idempotency contract

- **MUST** make every step safely re-runnable. Running the same
  migration twice in a row MUST produce: 1 actual apply, 1 "skipped
  (already applied)" log line.
- **MUST** use idempotency checks of the appropriate shape:
  - For markdown insertions: a unique anchor string from the new
    content (e.g. `grep -q "^## Backend language routing" <host-workflow-config>`).
  - For JSON modifications: a unique key path (e.g.
    `jq -e '.hooks.pre_phase.design_critique' <host-config-json> >/dev/null`).
  - For file creation: file existence at the expected path with
    expected content (e.g. `test -f templates/<artifact>.md`).
- A migration without working idempotency checks is non-conformant. This is
  the failure-to-detect case, distinct from the three-valued `check` contract
  in "Atomicity contract" below: a *working* check on a second run exits 0
  and the step is skipped cleanly (exit 0 overall, no error — that is the
  correct, conformant idempotent behaviour). What this bullet describes is a
  check that never correctly reports "already applied," so a second run
  proceeds to re-apply a step whose effects already exist; that MUST surface
  as a failure — either the check itself is wrong and reported as such, or
  the re-applied `apply`/`verify` naturally errors against a tree that no
  longer matches its pre-condition's assumptions. Silently succeeding twice
  with a different result each time is what this rule exists to prevent.

### Atomicity contract

The three-option failure policy (retry / skip / rollback) below binds every
migration, exactly as it always has. The dispatch mechanics that follow it —
block exit codes, "hard-abort", the fixed check/precondition/apply/verify
order — describe an **executable-form** runner (a migration at or above the
host's threshold) dispatching role-tagged fences. A migration below the
threshold satisfies the same three-option policy in whatever idiom prose or
agent steps allow (per "Executable form" above); it has no blocks to
sequence or exit codes to read.

A step is dispatched in this fixed order: `check`, then `precondition`, then
`apply`, then `verify` if present.

- A `check` **MUST** be read as three-valued: exit 0 means already applied
  (the step is skipped), exit 1 means not yet applied (proceed), and any
  other exit code **MUST** be treated as the check itself having failed and
  **MUST** hard-abort the migration. Conflating "not yet applied" with "the
  check could not run" would silently re-apply a step whose state is
  unknown.
- A failing `precondition` **MUST** hard-abort the migration immediately,
  regardless of whether a terminal is attached. A failed pre-condition means
  the migration's assumptions about the tree do not hold; retrying cannot
  change that, and skipping would apply a step whose assumptions are known
  to be violated. **The interactive failure policy below governs `apply`
  and `verify` failures only** — it does not apply to `check` or
  `precondition`.
- A `verify` block exiting non-zero **MUST** be treated as the step having
  failed: the step **MUST NOT** be recorded as applied, regardless of which
  failure-policy outcome follows. `apply` having run is not sufficient
  evidence the step succeeded once a `verify` block exists to check further.
- When an `apply` or `verify` block fails and standard input is a terminal,
  the runner **MUST** prompt the user with three options:
  1. **Retry** — re-run the failing block (idempotent steps are safe to
     re-run).
  2. **Skip with warning** — log the skip, continue with the next step. The
     migration is recorded as `partial` — satisfied by the runner's own
     diagnostic output, since this format defines no separate journal or
     state file to record it in.
  3. **Rollback** — run the rollback blocks of every step that has already
     applied, in **reverse document order**, excluding the failed step
     itself. A step whose `apply` succeeded and whose `verify` then failed
     **MUST** be included (its `apply` completed; its rollback describes a
     state that exists). A step whose `apply` itself failed **MUST NOT**
     have its rollback run (its state is unknown; rolling it back could
     destroy work it did not create).
- When standard input is **not** a terminal, the runner **MUST** abort in
  place, **MUST** report on standard error which steps applied, and **MUST
  NOT** roll back. The absence of anyone to ask is not consent, and a
  half-applied tree is itself evidence of what went wrong — evidence an
  automatic rollback would destroy.
- End-of-input, an empty answer, or an unrecognised answer at the prompt
  **MUST** be treated as "abort, do not roll back" — never as consent to
  roll back. A prompt whose default is destruction is not consent.
- Runners **SHALL** offer an explicit means of selecting the failure policy
  directly (independent of whether a terminal happens to be attached), so
  that automated invocations are never at the mercy of TTY detection.
- If a `rollback` block itself fails during an interactive rollback, the
  runner **MUST** report which rollbacks succeeded and which failed,
  **MUST** continue attempting the remainder rather than stopping at the
  first failure, and **MUST** exit non-zero.
- **MUST NOT** auto-rollback without explicit user consent. Partial-state
  recovery may be more useful than full revert.

### Non-mutation and diagnostics

This subsection describes blocks, which exist only in the **executable
form** (at or above the host's threshold). A below-threshold migration's
prose or agent-instruction steps carry no equivalent obligation beyond what
"Idempotency contract" and "Atomicity contract" already state in prose terms.

- A `check` or `precondition` block **MUST NOT** write to the working tree.
  Their role is to answer a question, and dry-run mode executes them. This
  is an obligation on the migration author, not something a runner can
  enforce — the alternative is a dry-run that promises not to write while
  executing arbitrary shell, a guarantee no runner can keep or should make.
- When a `precondition` fails, the runner **MUST** reproduce that block's
  standard error verbatim — **MUST NOT** paraphrase, summarise, or replace
  it. A pre-condition is where a migration explains what it found and what
  the operator may do about it; substituting the runner's own wording
  destroys the only useful output.
- Because diagnostic output (including a failing `precondition`'s stderr,
  and the `apply` source dry-run prints) commonly reaches CI logs that are
  more widely readable than the repository itself, migration authors
  **MUST NOT** emit secrets or personal data from any block's output or
  source.
- Each block **MUST** execute in its own shell. A step **MUST NOT** rely on
  environment variables, shell functions, or a working directory
  established by an earlier block or an earlier step — such a dependency
  would be invisible in the document and would break the moment a step is
  skipped as already applied.

### Dry-run mode

Dry-run itself is a universal MUST, unchanged from before the executable
form existed. The specifics below — printing a block's **source**, evaluating
only up to the first pending step, the prohibition on a scratch-copy
workaround — describe what dry-run means for an **executable-form** migration
dispatching role-tagged blocks. A below-threshold migration satisfies the
same "preview before applying, write nothing" obligation in whatever form its
prose or agent instructions allow; it has no block source to print.

- **MUST** support a dry-run mode that evaluates `check` and `precondition`
  up to and including the first pending step, prints the **source** of the
  `apply` block each pending step would run, and writes or commits nothing.
  Dry-run does not print a diff — producing one would require applying the
  step, which is the thing dry-run exists not to do.
- Blocks belonging to steps **after** the first pending step **MUST NOT** be
  evaluated; their `apply` sources are reported as unevaluated. Those steps
  describe a tree that only an earlier `apply` would have created, so
  evaluating them asks a question about a state that does not exist. This
  **MUST NOT** be worked around with a scratch copy of the tree: executing
  `apply` against a mirrored directory still runs arbitrary shell with the
  caller's environment, credentials, and network, and an ordinary recursive
  copy preserves symlinks, so even a purely relative write can land outside
  it. "The working tree was not modified" must be a property of the runner,
  not of the fixtures it happened to be tested against.
- A `precondition` failing during a dry run **MUST** abort the dry run and
  exit non-zero, exactly as it would during a real run, and the
  three-valued `check` contract above applies unchanged in dry-run.
- **SHOULD** make dry-run the default-on-confirm interactive mode:
  dry-run the whole chain, show what would apply, then ask "apply now?".

### Skip cases

Migrations MUST handle (without crashing) at minimum:

- The project has no workflow scaffolding installed yet → migration
  is skipped with a note directing the user to the setup flow.
- The project's `installed_version` is already ≥ this migration's
  `to_version` → migration is skipped silently.

### Test fixtures

- **SHOULD** ship a fixture pair (before-state, expected-after-state)
  for every migration that operates on existing files.
- **SHOULD** maintain a runner script (`run-tests.sh` or equivalent)
  that asserts each migration produces the expected end-state when
  applied to its before-state fixture.
- The `0000-baseline.md` migration MAY omit a non-interactive test
  if its application requires interactive input.

## Example migration outline

The following is an illustrative skeleton. Host implementations may
adapt path conventions; the shape is normative. This outline illustrates the
**prose form**: the four sections are headings followed by prose or an
un-annotated fence, which remains fully conformant for any migration below
its host's threshold. A migration at or above the threshold MUST additionally
give each section's fence a `role=` tag, as shown in "Executable-form
counterpart" below.

```markdown
---
id: 0001
slug: example-feature-add
title: Add example feature wiring to AgenticApps workflow
from_version: 1.2.0
to_version: 1.3.0
applies_to:
  - <host-workflow-config>
  - <host-config-json>
  - <host-instruction-file>
  - docs/decisions/
requires:
  - skill: example-skill
    install: "<host-install-command>"
    verify: "<host-verify-command>"
optional_for:
  - tag: example-tag
    detect: "<detect-command>"
    note: "If <condition> not detected, tagged steps install but the runtime won't trigger them."
---

# Migration 0001 — Add example feature wiring

## Pre-flight
{commands the update flow runs before any patch}

## Steps

### Step 1: Add anchor section to host-workflow-config
**Idempotency check:** `grep -q "^## Example feature" <host-workflow-config>`
**Pre-condition:** the file exists and has a `## Conventions` section
**Apply:**

\`\`\`markdown
## Example feature

{content}
\`\`\`

**Rollback:** delete the section bounded by the unique anchor `^## Example feature`.

### Step 2: ...
{...}

## Post-checks
- All `grep` verifications pass
- `<host-config-json>` validates structurally
- ADR opportunity: prompt user whether to draft an ADR

## Skip cases
- Project has no workflow scaffolding → skip with note "no workflow detected; run setup first"
- Project's `from_version` already ≥ this migration's `to_version` → skipped silently
```

### Executable-form counterpart

The same Step 1, at or above the host's threshold, with `migration_format:
executable` declared and each section's fence role-tagged:

```markdown
---
id: 0035
slug: example-feature-add
title: Add example feature wiring to AgenticApps workflow
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - <host-workflow-config>
---

### Step 1: Add anchor section to host-workflow-config

**Idempotency check:**
\`\`\`bash role=check
grep -q "^## Example feature" <host-workflow-config>
\`\`\`

**Pre-condition:**
\`\`\`bash role=precondition
test -f <host-workflow-config> && grep -q "^## Conventions" <host-workflow-config>
\`\`\`

**Apply:**
\`\`\`bash role=apply
cat >> <host-workflow-config> <<'EOF'

## Example feature

{content}
EOF
\`\`\`

**Rollback:**
\`\`\`bash role=rollback
sed -i '/^## Example feature$/,/^$/d' <host-workflow-config>
\`\`\`
```

Note what changed between the two forms: the prose-form Apply is a
` ```markdown ` fence containing the *content to insert* — never eligible
for a `role=` tag, since the grammar requires the literal `bash` — while the
executable form's Apply is a `role=apply` **bash** fence containing the
*shell that performs the insertion*. The executable form does not merely tag
the old fence; it re-expresses "what to add" as "the command that adds it,"
because only a command is something a runner can dispatch.

## Conformance

A host implementation:

- **MUST** store migrations in a single directory that the update flow
  consumes. The setup flow **MUST** produce an end state equivalent to a
  full `0000`→latest replay, by one of:
  - **replay** — setup applies every migration from `0000-baseline` forward; or
  - **snapshot** — setup installs a prebuilt artifact assembled from the same
    sources, PROVIDED a drift guard runs in CI and fails the build when the
    snapshot and the sources disagree.

  The snapshot strategy exists because a migration chain containing prose,
  agent, or interactive steps cannot be shell-replayed (ADR-0013 assumed it
  could; ADR-0018 supersedes that assumption). What is normative is the
  equivalence of the end state and a mechanical guard proving it — not the
  mechanism. A host choosing snapshot **MUST** name its guard in its
  instruction file.
- **MUST** support the frontmatter fields, step structure,
  idempotency contract, atomicity contract, and dry-run mode listed
  above.
- A host that has adopted the executable form (i.e. cites this spec version
  and has migrations at or above a declared threshold) **MUST** satisfy
  "Executable form," "Threshold scope," and "A runner lints before
  executing" above for those migrations, **MUST** run a format linter
  enforcing those rules, and **MUST** wire it into CI so a violation fails
  the build rather than merely being available to run locally. No host is
  touched by this change, and no host has adopted the executable form as of
  this spec version — so no host is retroactively non-conformant for lacking
  any of the above; a host **SHOULD** plan for these obligations as part of
  adopting the executable form.
- **SHOULD** ship test fixtures for every non-baseline migration.
- **MAY** define host-specific frontmatter fields beyond the
  required minimum (e.g. host-runtime-extension version pins).
