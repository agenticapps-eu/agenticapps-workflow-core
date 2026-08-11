# core-self-enforcement Specification

## Purpose
TBD - created by archiving change core-gates-itself. Update Purpose after archive.
## Requirements
### Requirement: Core provides and registers the gate against its own repository

The core repository SHALL provide and register the §18 change gate against
itself at two interposition points it owns — a git `pre-commit` hook and a CI
job — and SHALL be governed by the machine-level enforcement floor for
everything else. Publishing an enforcement artifact SHALL NOT be accepted as a
substitute for running it.

**The `PreToolUse` hook is removed, and this requirement is amended rather than
left to contradict the change that removes it.** The unamended text mandated
three points, the first of which was "a `PreToolUse` hook registered in
`.claude/settings.json`" — precisely what this change deletes across the fleet,
core included. A durable requirement that mandates what an active change removes
is not a tension to be noted in prose; one of the two is wrong, and it is the
requirement, because the reason the hook went is that a per-host session hook
cannot gate the session that installs it and does not exist for a human with an
editor.

**"Provides and registers", not "runs".** The `pre-commit` hook is written by an
installer and is absent until that installer is run, so a requirement that core
*runs* the gate would be unsatisfiable in any fresh clone — and would contradict
this capability's own "the installer was never run" scenario, which explicitly
blesses that state. The obligation is on what the repository ships and wires,
which is what core controls.

**§18 requires an interposition point, and no surface SHALL claim it requires
these two.** §18's requirement is a `PreToolUse` hook (or host equivalent); it
mentions `pre-commit` and CI only as *evaluating contexts* whose reviewer
identity must come from the trailer rather than the environment. With the host
hook removed, core satisfies §18 through the host-equivalent floor, and the two
points named here are core's own additions, adopted because core authors the
gate and wants drift caught at commit time and on the pull request.

**Neither is a guarantee, and the requirement SHALL NOT claim otherwise.** The
`pre-commit` hook is delivered by an installer and is absent until that
installer runs. The CI job's verdict blocks a merge only where a repository
setting requires the check, and core's `main` carries no branch protection and
no rulesets — so the CI job **reports** rather than enforces. Whether a verdict
blocks a merge is a repository setting outside this capability's scope.

**What the removal costs is stated rather than netted out.** The `PreToolUse`
hook gated an edit before it was written, regardless of any commit flag. Both
remaining local points are commit-time, and `git commit --no-verify` bypasses
one of them. Core keeps CI, so core is the best-covered case; a repository
without CI is left with one surface and a documented bypass, which is the
trade this change makes and does not conceal.

#### Scenario: Both owned interposition points run the gate

- **WHEN** the core repository is inspected for gate wiring
- **THEN** a CI workflow exists that runs the gate on pull requests and on pushes to `main`
- **AND** an installer exists that writes the `pre-commit` hook into the repository's resolved hooks directory
- **AND** no `PreToolUse` hook SHALL be required in `.claude/settings.json`

#### Scenario: All three interposition points run the gate

The header is kept because a `MODIFIED` block replaces a requirement whole, so
dropping it would read as a scenario deleted by accident rather than by decision.
It is retired on purpose, and this is the record of that.

Its third point was a `PreToolUse` hook "registered in `.claude/settings.json`".
Core has carried no such file since the host wiring was removed — measured
2026-08-11, `.claude/` holds `commands/`, `hooks/`, `skills/` and
`settings.local.json`, and no `settings.json`. The scenario has therefore been
asserting a registration that does not exist, which is the shape of staleness
this capability is meant to catch in others.

- **WHEN** the core repository is inspected for gate wiring
- **THEN** exactly two interposition points SHALL be required, not three, as the
  scenario above states
- **AND** a host session hook SHALL NOT be one of them, because it cannot gate
  the session that installed it and does not exist for a human with an editor

#### Scenario: A host session hook is present anyway

- **WHEN** a `PreToolUse` hook registered against the gate is found in core
- **THEN** it SHALL be reported as a surface this capability no longer requires
- **AND** its presence SHALL NOT be treated as satisfying any part of this
  requirement, since a surface nothing specifies is a surface nothing maintains

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
- **THEN** the commit-time points SHALL still observe it, because they read the index rather than the tool call
- **AND** the capability SHALL NOT describe its interposition points as complete coverage

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

**The machine-level floor does not reach core, and that is deliberate.** The
enforcement floor is now published once and bound through a global
`core.hooksPath`. One file serving every repository necessarily resolves the
shared install, which is exactly what this requirement forbids for core. Core
SHALL therefore set a **local `core.hooksPath`**, which git prefers over the
global binding, and SHALL keep a `pre-commit` in that directory resolving the
working-tree gate.

This is not an exception carved out for convenience. It is the same mechanism
the floor already offers every repository that needs different hooks — core is
simply the repository whose different hook is a documented invariant rather than
a preference. What changes is that the binding becomes **load-bearing**: before
the global floor existed, core's local resolution happened by default and no
configuration expressed it. It must now be explicit, because the default has
moved.

An explicit `OPENSPEC_GATE` override is retained and is **not** a violation of
the above: the prohibition is on *silently preferring* the published copy, which
is what a resolution-order fallback does. Setting an environment variable is a
deliberate operator act, it is required to test the fail-open path, and §18
requires the gate be demonstrable by direct invocation. The override SHALL be
documented wherever the resolution order is documented.

**Its weakness SHALL be disclosed rather than argued away.** "A deliberate
operator act" describes setting the variable, not every occasion it is read: an
`OPENSPEC_GATE` exported once in a shell profile is ambient thereafter, and
silently redirects core's local gate to a foreign copy on every subsequent
session — which is the same class of silent divergence the resolution inversion
exists to remove, re-entering by a door this capability holds open. It is kept
because removing it would leave the fail-open and direct-invocation paths
untestable, and because a local override cannot affect CI, where no such
environment exists and the verdict that gates the pull request is produced. That
is a trade accepted with its cost named, not a property the override lacks.

#### Scenario: An explicit override is honoured

- **WHEN** `OPENSPEC_GATE` names an executable and a local interposition point runs
- **THEN** that executable SHALL be used
- **AND** this SHALL NOT be treated as preferring the shared install, which is reached only by a fallback the resolution order does not contain

#### Scenario: The working-tree copy is preferred over a present shared install

- **WHEN** an executable gate exists at `~/.agenticapps/bin/openspec-change-gate.sh` whose behaviour differs from the working-tree copy
- **THEN** both the `PreToolUse` hook and the `pre-commit` hook SHALL execute the working-tree copy
- **AND** the shared install SHALL NOT be consulted

#### Scenario: The machine is bound by the global floor

- **WHEN** `core.hooksPath` is bound globally to the published hooks directory
- **THEN** core SHALL set a local `core.hooksPath` that git prefers
- **AND** a commit in core SHALL run the working-tree gate, not the published one

#### Scenario: Core's local binding is absent

- **WHEN** a commit is attempted in core while the global binding is in force and
  core has no local `core.hooksPath`
- **THEN** the published hook runs and core is gated by the shared install
- **AND** core's CI job SHALL fail, because it is the only surface whose verdict
  someone is obliged to look at. A local diagnosis is worth having too, but this
  condition SHALL NOT be reported *only* by a mode nobody runs until they
  already suspect something

#### Scenario: The shared install is absent

- **WHEN** the gate runs in CI, where `~/.agenticapps/` does not exist
- **THEN** the gate SHALL still resolve and run from the working tree
- **AND** the job SHALL NOT fail for want of a shared install

#### Scenario: The resolution order is inverted relative to projects

- **WHEN** core's resolution order is compared with a consuming project's shim
- **THEN** core SHALL prefer the working-tree copy and the project SHALL prefer the shared install
- **AND** core SHALL record the reason for the inversion in the two documents named above

The repository root SHALL NOT be derived from the process working directory.
A `PreToolUse` hook runs in whatever directory the session currently holds, and
that directory changes during a session; deriving the root from it meant one
`cd` outside the repository made resolution fail, which the fail-open branch
then reported as an ungated edit. The wrapper SHALL resolve the root from a
fixed point — the host-provided project directory, falling back to the
wrapper's own location — so that resolution does not depend on session state.

Silent ungating is the one outcome this wrapper SHALL NOT have. Failing open on
genuinely absent tooling is deliberate; failing open because the wrapper could
not work out where it was is a defect.

#### Scenario: The session's working directory has moved

- **WHEN** an edit is attempted while the session's working directory is outside the repository
- **THEN** the wrapper SHALL still resolve and execute core's working-tree gate
- **AND** SHALL NOT report the edit as ungated

### Requirement: The wrapper asserts no identity the gate will honour

Neither the `PreToolUse` wrapper nor the generated `pre-commit` hook SHALL
export `OPENSPEC_GATE_SELF`, and no comment SHALL describe it as excluding a
host's own reviews.

The gate has **ignored** that variable since 1.5.0: the implementing host is
read from the `REVIEWS.md` trailer, because CI and pre-commit evaluate evidence
that *other* hosts produced, and an environment identity names the wrong party.
The gate's own header records that documenting this variable as live was itself
the hazard — the conformance harness set it in every self-exclusion row, and
those rows passed on an unrelated mechanism. Core, which published that
warning, SHALL not reintroduce the pattern it names.

#### Scenario: The generated hook claims no host identity

- **WHEN** the generated `pre-commit` hook is inspected
- **THEN** it SHALL contain no `OPENSPEC_GATE_SELF` export
- **AND** no comment asserting that such an export affects reviewer counting

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
harness would otherwise yield a green job while certifying a drifting gate. The
job SHALL therefore assert **two** floors, recorded as literals in the workflow:

1. a minimum **scored-row count**, from the harness's reported total; and
2. a minimum count of **row call sites in the harness source**.

The second exists because the first takes the harness's word for it. The
reported total is scraped from the harness's own stdout, so a stub that prints a
passing `TOTAL` satisfies it while scoring nothing; a source count cannot be
satisfied that way. Raising either needs no ceremony; **lowering either SHALL
require an explicit recorded decision**, since removing obsolete rows is a
legitimate edit the floors must be able to follow. The point is that the number
moves deliberately and shows up in the diff.

**Neither floor bounds row CORRECTNESS, and the delta SHALL NOT claim they do.**
Inverting a row's expected exit code, duplicating rows, or weakening an
assertion leaves both counts unchanged. An earlier revision listed "inverting
expected exit codes" among what the floor catches; it does not.

**The residual trust SHALL be recorded.** A single pull request can edit the
gate, the harness and both floors atomically, and nothing mechanical then
objects — the tripwire's value rests on a human noticing the changed literals in
the diff. Core has no required checks, no branch protection and no CODEOWNERS,
so that is a real assumption rather than a theoretical one, and it is named here
because this capability is otherwise explicit about exactly this kind of gap.

**Scoring the published artifact is not the same as testing the code core
runs.** The harness scores the gate; it does not execute core's own `PreToolUse`
wrapper or its hook installer. That gap is not academic — the job reported
71 of 71 rows green while the installer carried four defects that wrote a file
into the working tree or destroyed a hook it did not own, each exiting 0 and
reporting success. Core's CI SHALL therefore also exercise the interposition
code this capability adds, and SHALL fail when it misbehaves.

Each case SHALL be a regression test for a defect that was actually reproduced,
not a hypothetical, so that the suite's failures name real history.

#### Scenario: The gate is scored before it is run

- **WHEN** the CI job executes
- **THEN** the conformance harness SHALL run against the reference implementation before the gate is invoked
- **AND** a failing harness SHALL fail the job without the gate's verdict being consulted

#### Scenario: The installer regresses

- **WHEN** a change reintroduces any of the installer defects this capability fixed
- **THEN** core's CI job SHALL fail
- **AND** the harness's row count SHALL NOT be what is relied on to catch it,
  since that count stayed at its floor throughout

#### Scenario: The reference implementation stops being conformant

- **WHEN** an edit makes the reference implementation fail one or more harness rows
- **THEN** core's own pull request SHALL go red
- **AND** the failure SHALL be visible on core's own pull request

Ordering against host pins is an **expectation, not a control**. Host
repositories are external to core; core has no required check and no branch
protection, so nothing here prevents a host from advancing a pin to a commit
whose gate job was red, or from pinning a commit that never ran the job. What
this capability establishes is that the signal now EXISTS in core, and earlier
than it did — not that anyone is compelled to read it.

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

`git rev-parse --git-path hooks` **honors `core.hooksPath`**: with that setting
configured the command returns the configured directory, not the default. The
installer SHALL therefore rely on the resolver rather than inspect the setting.
It SHALL NOT refuse merely because `core.hooksPath` is present — a hook written
to the resolved path fires normally, so such a refusal would be a false
positive, including in the degenerate case where the setting names the default
directory.

**One new refusal is required, and it exists because the resolver is now a
hazard.** Since the enforcement floor is bound machine-wide, a resolver that
honours `core.hooksPath` will, in a repository with no local binding, return the
**machine-level published directory**. Writing there would either be refused
permanently — the published hook carries a different ownership marker and is
correctly read as foreign — or, if the markers ever coincide, would publish
core's working-tree-resolving hook to every repository on the machine. The
second outcome is severe and silent: every repository would begin gating against
whatever happens to be in core's checkout.

The installer SHALL therefore refuse when the resolved hooks directory lies
outside the repository's **git common directory** — `git rev-parse
--path-format=absolute --git-common-dir` — report the global binding as the
cause, and name the local `core.hooksPath` that would fix it. This is a refusal
about *destination ownership*, distinct from the containment refusal below,
which is about writing into repository content.

**The predicate is the common directory, not the working tree, and the two must
not be confused.** An earlier revision of this delta said "outside core's own
git directory" while the requirement below says the installer SHALL install when
`core.hooksPath` names a directory *outside the working tree* — and `.git/hooks`
is outside the working tree, so the two read as contradictory. The common
directory resolves it: `.git/hooks` is inside it and installs normally; the
machine-level published directory is outside it and is refused. It is
specifically the **common** directory rather than the git directory because in a
linked worktree the real hooks directory belongs to the main checkout, and a
predicate using `--git-dir` would refuse every legitimate install performed from
a worktree.

One case does warrant refusal: when the resolved hooks directory lies **inside
the working tree**, installing would write into repository content rather than
local, untracked configuration. Placing a hook into the repository is a
different act with different consequences, so the installer SHALL report and
exit non-zero rather than make that decision silently.

The predicate SHALL be **path containment**, and nothing adjacent to it. Two
adjacent predicates have each already produced this bug:

- *Tracking status.* `git ls-files --error-unmatch` fails for an untracked
  in-tree directory, which the installer read as permission to write. An
  untracked path inside the tree is still repository content.
- *Existence.* Containment SHALL be decided for a directory that does not yet
  exist, since the installer creates missing parents. Canonicalising by
  `cd`-ing to the path cannot resolve one that is absent, and resolving only
  its immediate parent fails when that is absent too — which yielded a path
  outside the tree and installed a hook inside it.

The installer SHALL therefore canonicalise by resolving the deepest **existing**
ancestor and re-appending the remaining components.

#### Scenario: The resolver returns the machine-level published directory

- **WHEN** the installer runs in core while a global `core.hooksPath` is bound
  and core has no local binding
- **THEN** it SHALL refuse and exit non-zero
- **AND** SHALL report that the global floor redirected the resolver
- **AND** SHALL NOT write into the machine-level published directory

#### Scenario: The installer runs from a linked worktree of core

- **WHEN** the installer runs in a linked worktree whose hooks directory belongs
  to the main checkout
- **THEN** the destination is inside the git **common** directory and installs
  normally
- **AND** SHALL NOT be refused as foreign on the grounds that it lies outside
  the worktree's own git directory

#### Scenario: Core carries its own local binding

- **WHEN** the installer runs in core where a local `core.hooksPath` names
  core's own hooks directory
- **THEN** it SHALL install normally
- **AND** SHALL NOT refuse on the grounds that a global binding exists

#### Scenario: Installation inside a linked worktree

- **WHEN** the installer runs in a linked worktree, where `.git` is a file
- **THEN** it SHALL resolve the hooks directory via `git rev-parse --git-path hooks`
- **AND** SHALL NOT attempt to create or write a literal `.git/hooks/` path
- **AND** SHALL report that the hook it installs is shared with the main checkout

#### Scenario: core.hooksPath points outside the working tree

Kept as a header so its retirement is a decision on the record rather than a
scenario that vanished. It is superseded by the narrowed scenario immediately
below, and the reason is given there: unbounded "outside the working tree" also
described the machine-level published directory, so this scenario required
installing into the very directory the refusal above forbids.

- **WHEN** the installer runs where `core.hooksPath` names a directory outside
  the working tree
- **THEN** the bare condition SHALL NOT decide the outcome, because it does not
  distinguish the repository's own git common directory from the machine's
  published hooks directory
- **AND** the scenario below SHALL decide it instead

#### Scenario: core.hooksPath points outside the working tree but inside the git common directory

- **WHEN** the installer runs where `core.hooksPath` names a directory outside
  the working tree and inside the repository's git common directory — of which
  `.git/hooks` is the ordinary case
- **THEN** it SHALL install into the directory the resolver returns
- **AND** SHALL NOT refuse on the grounds that the setting is present

> **Narrowed deliberately.** This scenario previously said "outside the working
> tree" with no upper bound, which contradicted the refusal above: the
> machine-level published directory is *also* outside the working tree, and this
> scenario would have required installing into it while the refusal required
> declining. The prose already named the common directory as the predicate; the
> scenario had not been narrowed to match, so a reader following scenarios alone
> would have implemented the defect.

#### Scenario: core.hooksPath names the default directory

- **WHEN** `core.hooksPath` is set to the same directory the resolver would return by default
- **THEN** the installer SHALL install normally
- **AND** SHALL NOT report a conflict

#### Scenario: The resolved hooks directory is inside the working tree

- **WHEN** the resolved hooks directory lies inside the working tree
- **THEN** the installer SHALL report this and exit non-zero
- **AND** SHALL NOT write a hook into repository content
- **AND** SHALL refuse whether or not that directory is tracked by git

#### Scenario: The resolved hooks directory is inside the tree but does not exist

- **WHEN** `core.hooksPath` names a path inside the working tree whose directory
  and whose parent are both absent
- **THEN** the installer SHALL still recognise it as inside the tree and refuse
- **AND** SHALL NOT create the missing parents and report success

#### Scenario: The hooks path re-enters the tree through an absent `..` segment

- **WHEN** `core.hooksPath` begins outside the working tree and returns into it
  through a `..` segment whose preceding directory does not exist
- **THEN** the installer SHALL normalise the path before deciding containment
- **AND** SHALL refuse, rather than accepting the unnormalised string as outside
  the tree and then creating the absent segment

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

The marker SHALL be matched as a **whole line**. A substring match anywhere in
the file is not an ownership claim: a foreign hook that merely mentions the
marker — in an `echo`, a comment about this installer, a pasted doc block — was
claimed and overwritten under a substring test.

A marker is an ownership claim, not an integrity proof: a hand-edited or
adversarially marked hook will be treated as core's and updated in place. That
is an accepted limit of a repository-local convenience script, and SHALL be
recorded rather than implied.

A `pre-commit` **symlink** SHALL be refused rather than written through. It
carries no marker the installer can read, so it is foreign by the same rule as
any other hook it did not write, and writing through it modifies the link
target — which may lie inside the working tree, defeating the containment rule
above. Presence SHALL therefore be tested such that a **dangling** symlink is
detected: it is not "no hook present", and treating it as such followed the
link and created its target.

The hook SHALL be written **atomically** — to a temporary file in the
destination directory, made executable, then renamed into place. Redirecting
onto the destination truncates a working hook before the replacement is known
to be complete, so an interrupted write leaves a truncated hook that git still
executes, while the installer reports failure.

#### Scenario: The installer runs on a fresh clone

- **WHEN** the installer is run where no `pre-commit` hook exists
- **THEN** it SHALL write an executable hook resolving core's reference implementation
- **AND** the hook SHALL carry the ownership marker

#### Scenario: The installer runs twice

- **WHEN** the installer is run again and the installed hook is already current
- **THEN** it SHALL leave the hook unchanged
- **AND** SHALL report a no-op rather than an install

#### Scenario: A foreign hook mentions the marker without claiming it

- **WHEN** a `pre-commit` hook the installer did not write contains the marker
  text somewhere other than as a line of its own
- **THEN** the installer SHALL treat it as foreign and refuse
- **AND** SHALL leave its contents intact

#### Scenario: The pre-commit path is a symlink

- **WHEN** `pre-commit` is a symlink, including one whose target does not exist
- **THEN** the installer SHALL refuse and name the target
- **AND** SHALL NOT create or modify the link target

#### Scenario: A self-written hook is stale

- **WHEN** the installer finds a hook carrying its marker whose content differs from what it would write now
- **THEN** it SHALL update the hook in place
- **AND** SHALL report an upgrade

#### Scenario: A self-written hook has lost its execute bit

- **WHEN** the installer finds a hook carrying its marker whose content is current but which is not executable
- **THEN** it SHALL restore the execute bit
- **AND** SHALL report a repair rather than a no-op

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

The job SHALL be triggered by `pull_request`, never by `pull_request_target`.
The distinction is the whole trust boundary here: `pull_request` runs the fork's
code with a read-only token and no access to repository secrets, while
`pull_request_target` would run that same fork-supplied shell with the base
repository's privileges. Since this job executes working-tree scripts by design,
the trigger is the control that keeps a fork pull request from turning that into
privilege.

#### Scenario: A pull request arrives from a fork

- **WHEN** a pull request from a fork causes the job to execute the working-tree harness and gate
- **THEN** the job SHALL run under the `pull_request` trigger
- **AND** the fork's code SHALL execute with a read-only token and without repository secrets
- **AND** the workflow SHALL NOT use `pull_request_target`

#### Scenario: The workflow declares its privileges

- **WHEN** the workflow is inspected
- **THEN** it SHALL declare read-only `contents` permission
- **AND** the checkout step SHALL disable credential persistence

#### Scenario: The OpenSpec dependency is pinned

- **WHEN** the workflow installs the `openspec` CLI
- **THEN** it SHALL install an exact pinned version
- **AND** an `openspec` release SHALL NOT change the verdict for an unchanged revision

The pinning claim SHALL be scoped to `openspec` and SHALL NOT be generalised to
the job as a whole. The rest of the execution chain remains mutable —
`actions/*@v7` is a moving major tag, `ubuntu-latest` is a moving image, Node is
pinned only to major `"22"`, and npm still resolves `openspec`'s transitive
dependencies at install time. A claim of full reproducibility would be false;
what is true is that the one dependency whose behaviour decides the verdict is
exact.

### Requirement: Core's local hooks binding is declared, and the fleet sweep does not remove it

The installer's sweep of redundant local `core.hooksPath` settings SHALL NOT
unset core's.

The sweep's rule is that a local binding naming the directory git would resolve
anyway grants no behaviour and is safe to remove. **Core is the one repository
where that reasoning is false.** Its binding names its own default hooks
directory and is therefore syntactically redundant, but removing it hands core
to the machine-level floor and breaks the resolution inversion this capability
exists to protect. A rule that reads only the *value* of the setting cannot tell
the two cases apart.

Core's binding SHALL therefore be **declared** rather than inferred, so that the
sweep excludes it by name and not by accident, and so that a reader can see it
is intentional. A binding that is load-bearing and looks redundant is exactly
the thing a future cleanup removes with a good conscience.

**The binder establishes it, in the same act that creates the hazard.** Setting
the global binding is the moment core's own hook stops being preferred; the
binder is the only thing that knows both facts at once, and it runs from inside
core's checkout by construction. So it SHALL set core's local binding and its
declaration **before** setting the global one, and SHALL NOT set the global
binding if establishing core's fails.

Every other candidate owner disclaims this in its own contract, which is why the
gap existed rather than being an oversight in one place:

| Candidate | Why not |
|---|---|
| `install.sh` | writing hooks into whatever repository the shell is standing in is the category error Decision 4 removed |
| `init-project.sh` | "no skills, no hooks, no host configuration — those are the machine's business" |
| `fresh-clone-needs-nothing` | a repository carries `openspec/` and one instruction file, "nothing else. No hooks, no shims" |
| core's CI | detects the absence; a detector is not an establisher |

This is **not** Decision 4's category error returning. That error was a machine
installer reaching into an arbitrary repository it happened to be standing in.
This is the binder repairing the single, known, deterministic casualty of its
own act, in the one repository it is by definition running from. The
displacement and the repair are one act, for the same reason "publish, then
bind" is one act: the orders are not symmetric and the safe one costs nothing.

#### Scenario: The binder runs before any global binding exists

- **WHEN** the binder is about to set the global `core.hooksPath`
- **THEN** it SHALL first set core's local `core.hooksPath` to core's resolved
  default hooks directory, together with `agenticapps.hooksbinding=declared`
- **AND** it SHALL NOT set the global binding if either write fails
- **AND** a commit in core afterwards SHALL run core's working-tree gate

#### Scenario: Core's binding is already established

- **WHEN** core already carries a declared local binding naming its default
  hooks directory
- **THEN** the binder SHALL report it satisfied and rewrite nothing
- **AND** SHALL proceed to the global binding

#### Scenario: The sweep encounters core

- **WHEN** the sweep evaluates core's local `core.hooksPath`
- **THEN** it SHALL leave the binding in place
- **AND** SHALL report it as declared rather than as redundant

