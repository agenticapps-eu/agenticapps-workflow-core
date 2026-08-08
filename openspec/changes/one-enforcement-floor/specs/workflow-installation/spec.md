## MODIFIED Requirements

### Requirement: One command installs the workflow, and it names no host

The workflow SHALL be installable by a single command in core that requires no
host argument. Running it with no arguments SHALL publish the payload, publish
the gate's `pre-commit` to the machine-level hooks directory, and bind that
directory through `core.hooksPath`. A host is an optional addition to that
install, never a precondition for it.

An operator who has never heard of the five hosts SHALL still get a working
install. The git and CI floor **is** the workflow; a host adds skills, and
nothing else.

#### Scenario: A bare run installs without a host

- **WHEN** the operator runs the installer with no arguments
- **THEN** the payload and the gate's `pre-commit` are published
- **AND** the machine-level hooks directory is bound through `core.hooksPath`
- **AND** the run succeeds without any host being detected or named

#### Scenario: No host is installed on the machine

- **WHEN** the installer runs on a machine where no host is installed
- **THEN** it exits successfully, having published the payload and the hook
- **AND** it reports that no host was bound rather than treating it as an error

### Requirement: The installer is short enough to be read before it is trusted

The installer SHALL NOT exceed 217 executable lines, counting neither comments
nor blank lines.

> **The headroom is zero, and this change still claims no raise.** The budget
> came back from 250 to 217 in `core-installer-one-entry-point`, where the
> implementation landed at 210. It is **217 today** — measured 2026-08-07 with
> the canonical counter, `grep -cvE '^[[:space:]]*(#|$)'`. The intervening
> change `fresh-clone-needs-nothing` spent every remaining line on the
> `init-project` artifact and the opsx binder. Both figures this note used to
> carry — "landed at 210", "7 lines of headroom" — are therefore stale, and so
> is the 212 that replaced the first of them.
>
> An earlier revision concluded from that arithmetic that the growth "is plainly
> not enough" to fit and a raise was unavoidable. **That conclusion assumed the
> floor's wiring would be added to the installer. It displaces instead.** The
> machine-level floor supersedes `tools/install-core-git-hooks.sh` as the thing
> the installer invokes, so the floor binder takes that helper's variable and its
> call site: one variable for one variable, one call for one call. The published
> hook, the foreign-binding refusal and the `--check` reports live in the binder
> and the gate, which carry no budget.
>
> The budget is therefore **not raised here**, and that is a measured claim
> rather than an aspiration: the arithmetic is 217 → 217. The escape clause is
> unchanged and still applies to anything that turns out not to fit — itemise
> the overage, name the behaviour responsible, and raise the number in this
> document. What is not permitted is arriving at 240 and discovering the ceiling
> had already been moved to accommodate it.

Mandatory: every mode named in this specification, publishing, skill binding,
the global floor binding, the foreign-binding refusal, the legacy manifest, and
every acceptance and preservation rule. None may be omitted to fit.

Deferrable, in order: reporting distinctions within check mode that collapse
into a coarser but still correct state; then the archived-binding sweep's
per-name reporting, which may collapse to a count.

Anything deferred SHALL be reported to the operator, naming what was deferred
and why.

#### Scenario: The budget is measured

- **WHEN** the installer's executable lines are counted
- **THEN** the count is at most 217, or the budget has been raised in this
  document with the overage itemised

#### Scenario: The budget cannot be met

- **WHEN** the behaviour this specification requires cannot fit the budget
- **THEN** what is dropped is taken from the deferrable list, in the stated order
- **AND** each deferral is reported to the operator with the reason
- **AND** no mandatory behaviour is omitted to fit

#### Scenario: The mandatory behaviour alone exceeds the budget

- **WHEN** the mandatory behaviour alone cannot fit the budget
- **THEN** the overage is reported together with the behaviour responsible
- **AND** the budget is not raised without amending this specification

#### Scenario: The growth is accounted for

- **WHEN** this change is complete
- **THEN** the installer's line count is reported against its count before the
  change
- **AND** the difference is attributed to named behaviour rather than absorbed

## ADDED Requirements

### Requirement: The enforcement floor is bound once per machine, not once per repository

The gate's `pre-commit` SHALL be published to a single machine-level hooks
directory and bound by setting `core.hooksPath` in the operator's global git
configuration. It SHALL NOT be copied into an individual repository's hooks
directory.

A per-repository copy is a fork that nothing reports has forked. Nine
repositories on the machine this was measured on carried the gate at four
different sizes, and no surface named the divergence.

#### Scenario: A machine is bound

- **WHEN** the installer runs
- **THEN** the gate's `pre-commit` is published to the machine-level hooks
  directory
- **AND** `core.hooksPath` in global git configuration resolves to that
  directory

#### Scenario: A repository without a local override is covered without being visited

- **WHEN** an **enrolled** repository with no local `core.hooksPath` on a bound
  machine runs `git commit`
- **THEN** the published gate runs
- **AND** the repository required no hook installation step of its own

#### Scenario: A repository needs different hooks

- **WHEN** a repository sets its own `core.hooksPath` in local configuration
- **THEN** the local setting governs that repository
- **AND** the global binding SHALL NOT reach it

### Requirement: The floor governs only repositories that enrolled in it

A global `core.hooksPath` runs the published hook in **every** repository on the
machine. The hook SHALL therefore determine whether the repository opted into
this workflow before it does anything else, and SHALL exit 0 without output when
it did not.

Enrolment is a local git config key, `agenticapps.workflow.enrolled`.

**This is a measured requirement, not a precaution.** With the predicate absent,
a repository containing any `openspec/` tree that fails `openspec validate --all`
has every commit blocked — a test fixture, a vendored example, an abandoned
experiment — while a repository with no `openspec/` at all, and one whose
`openspec/` is unrelated, both commit normally. So the failure lands precisely on
repositories that touched OpenSpec once and never adopted the workflow, and it
arrives as a message about spec deltas that means nothing to them.

Enrolment is an **act**, deliberately, rather than an inference from the shape of
a directory. A predicate that guesses from shape makes the wrong outcome rarer
without making it impossible, and its failures are silent for the person hit
by them.

The cost is named: an unenrolled repository that ought to be governed is
silently ungated. `--check` SHALL therefore report a repository that carries
`openspec/` and is not enrolled, so the gap is visible rather than assumed
absent. Without that report this predicate is a drifting list under another name.

#### Scenario: An unenrolled repository is left alone

- **WHEN** `git commit` runs on a bound machine in a repository with no
  `agenticapps.workflow.enrolled` key
- **THEN** the hook SHALL exit 0
- **AND** SHALL produce no output
- **AND** SHALL NOT invoke the gate

#### Scenario: An unenrolled repository carries a malformed openspec tree

- **WHEN** an unenrolled repository contains an `openspec/` tree that fails
  `openspec validate --all`
- **THEN** the commit SHALL succeed
- **AND** SHALL NOT be blocked on the validity of a spec delta the repository
  never opted into

#### Scenario: An enrolled repository is gated

- **WHEN** an enrolled repository stages code while `openspec validate --all` is
  not green
- **THEN** the commit SHALL be blocked, exactly as a per-repository install would
  have blocked it

#### Scenario: A repository carries openspec but never enrolled

- **WHEN** `--check` runs in a repository that carries `openspec/` and has no
  enrolment key
- **THEN** it SHALL report the repository as unenrolled and therefore ungated
- **AND** SHALL NOT report the machine's global binding as governing it
- **AND** the installer neither prevents nor repairs this

### Requirement: No repository is left with neither surface

A repository carrying a per-repository gate hook SHALL NOT have that hook
removed unless it is enrolled **and** the global binding has been verified to
govern it. Enrolment SHALL precede removal, and the verification SHALL resolve
the repository's hooks directory rather than infer coverage from the global
configuration.

A repository carrying a redundant local `core.hooksPath` SHALL have that binding
swept as part of its migration, because git prefers a local binding over the
global one and the verification would otherwise fail for a repository the
migration is in the middle of adopting. Measured 2026-08-08: two of the three
repositories in the migration set carry exactly this. The sweep is therefore a
step inside the migration, not a separate pass that runs beside it, and the
distinction between a redundant binding and a real one is the one the sweep
requirement below already draws.

**The full order is enrol → sweep → verify → remove, and every step of it is
load-bearing.** Enrolment is inert while the local binding still stands: the
repository is gated by its own hook, which predates the enrolment predicate and
does not consult it, so writing the marker changes nothing until the sweep. That
is exactly what makes enrolling first safe, and sweeping first unsafe. Sweeping
an unenrolled repository hands it to the global dispatcher, whose first act is to
exit 0 because the marker is absent — so the window between sweep and enrolment
is one in which the repository has a hook file, a global binding, and **no
enforcement**, and an interruption inside it leaves that state permanently with
nothing reporting it. It is the same failure as removing before enrolling,
reached through the binding rather than through the file, and this requirement
already forbids it by name.

**Every named repository SHALL be enrolled before the global binding is set**,
not merely before its own sweep. The sweep is one of two things that displace a
repository's own hook and it is the smaller one: a repository with **no** local
`core.hooksPath` — the state `tools/install-core-git-hooks.sh` leaves behind,
since it writes into the directory git already resolves and sets nothing — stops
consulting `.git/hooks/` the instant `core.hooksPath` is set globally, with no
sweep involved anywhere. Enrolling inside each repository's own sequence
therefore reopens this same window one step earlier and for every named
repository at once. Reproduced 2026-08-08 against an implementation that
enrolled inside the loop: the run was cut at the binding and a commit in a
repository whose gate hook was still on disk succeeded. Enrolment before the
binding is inert in the strongest sense — with no binding yet, the predicate has
no reader at all — and it SHALL still follow every refusal the binder makes, so
a run that refuses has written nothing into a named repository.

If verification fails after the sweep, the swept binding SHALL be restored, so a
repository that cannot be handed to the floor is returned to the surface it had.

Composed carelessly, three of this change's own parts destroy the floor they
build: the sweep removes the per-repository copies, the published hook exits 0
without `agenticapps.workflow.enrolled`, and enrolment is only wired for *new*
projects. Every repository gated today would end the migration silently
ungated — the exact failure this change exists to eliminate.

Ordering is load-bearing rather than cosmetic. Removing first leaves a window in
which the repository has no gate at all, and a migration interrupted inside that
window leaves it there permanently with nothing reporting it. Enrolling first
has a worst case of a repository enrolled while still carrying a redundant local
hook, which is the state every one of them is in today.

Carrying a gate hook is evidence for **proposing** enrolment and is not
enrolment. The installer wrote a `pre-commit` into whichever repository the
operator's shell was sitting in, so this population mixes deliberate adoption
with drive-by installs and nothing on disk separates them. A migration that
translated the hook into a marker unasked would enshrine the accidents as
policy, at the moment this change is asserting that enrolment is an act.

#### Scenario: A gated repository is migrated

- **WHEN** the migration processes a repository carrying a gate hook and the
  operator has accepted
- **THEN** it is enrolled first
- **AND** any redundant local `core.hooksPath` is swept next
- **AND** the global binding is confirmed to govern it by resolving its hooks
  directory
- **AND** only then is the local hook removed

#### Scenario: The migration is interrupted inside a repository

- **WHEN** the migration is interrupted after any single step of a repository's
  enrol → sweep → verify → remove sequence, or at the global binding itself
- **THEN** that repository SHALL still have an active enforcement surface —
  its own hook while git still resolves it, and the floor once git does not
- **AND** no interruption point SHALL leave it swept but unenrolled
- **AND** no interruption point SHALL leave it bound but unenrolled

#### Scenario: A named repository holds no local binding at all

- **WHEN** a named repository carries a gate hook and no local `core.hooksPath`,
  so nothing is swept and the global binding alone displaces its hook
- **THEN** it SHALL be enrolled before that binding is set
- **AND** an interruption at the binding SHALL leave the floor governing it
- **AND** its migration SHALL otherwise proceed as verify → remove

#### Scenario: Verification fails after the binding was swept

- **WHEN** a repository is enrolled and swept, and resolving its hooks directory
  then shows the global binding does not govern it
- **THEN** the swept local binding SHALL be restored
- **AND** its local hook SHALL remain in place
- **AND** the repository is reported as not migrated

#### Scenario: A named repository holds a local binding that is not redundant

- **WHEN** a repository in the migration set carries a local `core.hooksPath`
  naming a directory other than the one git would resolve anyway, or carries the
  `declared` marker
- **THEN** the binding SHALL NOT be swept
- **AND** the repository SHALL NOT be enrolled or have its hook removed
- **AND** it is reported, naming the binding that keeps it outside the floor

#### Scenario: Enrolment fails

- **WHEN** a repository cannot be enrolled
- **THEN** its local hook SHALL remain in place
- **AND** the repository is reported as not migrated

#### Scenario: The global binding does not reach the repository

- **WHEN** a repository is enrolled but resolving its hooks directory shows the
  global binding does not govern it
- **THEN** its local hook SHALL remain in place
- **AND** the repository is reported, naming the binding that displaced it

#### Scenario: The migration is interrupted

- **WHEN** the migration is interrupted partway through the set
- **THEN** every repository already processed is enrolled and governed
- **AND** every repository not yet processed still carries its own hook
- **AND** no repository is enrolled-and-unremoved in a way that gates twice, nor
  removed-and-unenrolled in a way that gates not at all

#### Scenario: A repository scheduled for deletion is not migrated

- **WHEN** a repository carrying a gate hook is an archived or retired checkout
- **THEN** it SHALL be excluded by not being named
- **AND** its hook is left alone rather than removed

Disposition is operator input, not a runtime lookup. Whether a checkout is
archived lives on the forge and in a family instruction file, never in the
repository, so a migration that tried to detect it would need network access and
an authoritative record at exactly the moment it is mutating git configuration.
Under a named set the exclusion needs no mechanism at all: an archived checkout
is excluded by the same act that includes a live one, and the reporting
obligation falls on the census that produced the names rather than on the code
that consumes them.

### Requirement: The migration acts only on repositories the operator names

The migration SHALL act only on repositories given to it by name. It SHALL NOT
search the filesystem for candidates, and a repository it was not given SHALL be
left entirely alone — not enrolled, not swept, and its hook not removed.

**Discovery is unnecessary rather than deferred, and the reason is that
enrolment is itself the consent.** A repository is governed by the floor only if
it enrolled, and enrolling is a deliberate act performed in that repository. So
the binding needs no separate consent for a repository that already enrolled: it
delivers what that repository asked for. What the preflight owes an operator is
therefore the set of repositories **this run will newly enrol**, which is the set
it was given by name and is holding in hand — not an enumeration of every
repository already enrolled, which would require the search this requirement
forbids and would re-ask a question already answered.

The distinction is load-bearing and the weaker claim is the true one. The
migration's mutation set and the binding's total impact set are **not** the same
set: a repository enrolled earlier by project initialisation becomes governed
when the binding lands without appearing in any report, and the census showing
zero enrolled repositories today is a measurement, not an invariant. The
preflight SHALL therefore describe what it will newly enrol and SHALL NOT claim
to enumerate every repository the binding governs.

**A search also cannot make the judgements the set requires.** Measured across
61 repositories on 2026-08-08, seven carry a gate hook and three belong in the
migration set. Separating them takes four calls — archived versus live, a husky
installation versus this workflow's gate, deliberate adoption versus a drive-by
install, and a retired checkout versus a current one — and not one is a property
of a file on disk. A search would surface seven candidates and require the
operator to classify them anyway, having read 61 repositories first.

**A named repository is identified by its git common directory, not by the path
typed.** Each name SHALL be canonicalised, SHALL be rejected without writes if it
does not resolve to the top of a git repository, and SHALL be deduplicated by
resolved common directory so two spellings of one repository — a relative path, a
symlink, a second alias — cannot be processed twice. Linked worktrees share one
common directory, and therefore one local configuration and one hooks directory,
so naming any checkout acts on all of them: the preflight SHALL report every
worktree it affects, or the claim that an unnamed repository is left entirely
alone is false for a sibling nobody mentioned.

**Naming a repository is not evidence about the hook inside it.** Before removing
any `pre-commit`, the migration SHALL establish that the file is this workflow's
gate rather than an operator's own, and SHALL refuse that repository without
writes when the hook is absent, foreign, or ambiguous. This is the lesson the
hooks-directory inventory already learned one level up: a file's location proves
who could have written it and never who did, so recognition has to come from the
file rather than from the fact that somebody typed a path.

**And what is removed SHALL be what the report named.** A repository describes
where its own hooks live — a `.git` file names another directory, a hooks
directory may be a symlink — so the path the preflight prints and the file the
removal reaches are not the same thing by construction. A symlinked hooks
directory SHALL refuse the repository, because unlike a symlinked hook it is
invisible in the report: the operator accepts a path inside the repository they
named and the delete lands somewhere else. Demonstrated before this was written,
against a hooks directory linked out of the repository: the file outside it was
removed and the run exited 0.

Everything the run will do SHALL be reported before anything is done, under a
**single** acceptance covering what will be published into the hooks directory,
what this run will newly enrol, and what will be migrated. Separate acceptances
for the same act teach an operator to answer without reading, which is the
failure the per-entry inventory of the hooks directory exists to prevent.

Declining SHALL leave untouched everything downstream of the acceptance: nothing
published into the hooks directory, no global binding set, and no repository
enrolled, swept, or stripped of its hook. The guarantee is scoped to the acts
this requirement governs and SHALL NOT be stated as leaving the machine
untouched — the installer publishes its payload before reaching this point, so a
promise about the whole install is one the preflight cannot keep.

#### Scenario: The preflight reports before it acts

- **WHEN** the migration runs with repositories named
- **THEN** it SHALL report each named repository and the acts it will perform on
  it, together with what will be published and what the binding will newly govern
- **AND** SHALL require one acceptance covering all of it
- **AND** SHALL perform none of it before that acceptance

#### Scenario: The operator declines

- **WHEN** the operator declines the preflight
- **THEN** nothing SHALL be published into the hooks directory
- **AND** the global binding SHALL NOT be set
- **AND** no named repository SHALL be enrolled, swept, or have its hook removed

#### Scenario: A name does not resolve to a repository

- **WHEN** a given name does not canonicalise to the top of a git repository
- **THEN** it SHALL be rejected before any repository is modified
- **AND** the run SHALL report the name it could not resolve

#### Scenario: One repository is named twice

- **WHEN** two given names resolve to the same git common directory
- **THEN** the repository SHALL be processed once

#### Scenario: A named repository has linked worktrees

- **WHEN** a named checkout shares its git common directory with other worktrees
- **THEN** the preflight SHALL report every worktree the migration affects
- **AND** the acceptance SHALL cover them before the configuration they share is
  modified

#### Scenario: The hook in a named repository is not this workflow's gate

- **WHEN** a named repository's `pre-commit` is absent, foreign, or cannot be
  recognised as this workflow's gate
- **THEN** the migration SHALL refuse that repository without writing to it
- **AND** SHALL report why, naming the file it declined to remove

#### Scenario: A named repository's hooks directory is a symlink

- **WHEN** a named repository's resolved hooks directory is a symlink
- **THEN** the migration SHALL refuse that repository without writing to it
- **AND** SHALL report that what would be removed is not what the preflight can
  name

#### Scenario: A repository was not named

- **WHEN** a repository on the machine carries a gate hook and was not named
- **THEN** the migration SHALL NOT enrol it, sweep it, or remove its hook
- **AND** it remains gated by the hook it already carries

#### Scenario: The filesystem is not searched

- **WHEN** the migration determines its set
- **THEN** it SHALL take the set from the names it was given
- **AND** SHALL NOT walk the filesystem for repositories

#### Scenario: One repository fails and the rest continue

- **WHEN** a named repository cannot be swept, enrolled, or verified
- **THEN** that repository SHALL keep its hook and be reported
- **AND** the migration SHALL continue with the repositories still to process
- **AND** the run SHALL exit non-zero so a partial migration is never reported as
  a complete one

### Requirement: A local binding that is redundant is swept; one that is real is kept

Git resolves a local `core.hooksPath` in preference to the global one, so a
repository carrying either is outside the floor. The installer SHALL distinguish
the two cases rather than treat every local binding as an opt-out.

A local binding that names the directory git would resolve anyway grants no
behaviour — unsetting it changes nothing except restoring the floor's reach, and
that is what makes the sweep safe. A local binding that names anything else is a
deliberate act and SHALL be left alone and reported.

**A binding may be redundant by value and still be load-bearing**, and the sweep
SHALL NOT rely on the value alone. Core is the case: its binding names its own
default hooks directory, so it reads as redundant, but removing it hands core to
the machine-level floor and breaks the resolution inversion `core-self-enforcement`
requires. Such a binding SHALL be **declared**, and the sweep SHALL exclude any
declared binding rather than inspecting what it points at.

**The declaration is a git config key in the same local configuration as the
binding it qualifies:** `agenticapps.hooksbinding = declared`. Named concretely
because a requirement to "declare" something with no mechanism is not
implementable, and because it must live where the binding lives — a marker file
can be deleted while the binding survives, and a list held in core cannot be
read by a sweep running against a repository core does not know about.

The rule is then mechanical: a local `core.hooksPath` is swept only if it is
redundant by value **and** carries no `agenticapps.hooksbinding=declared` in the
same scope.

**Equivalence SHALL be decided on resolved paths, never on strings.** A value
may be relative (`fbc-platform`'s is `.husky/_`), may contain `~`, may traverse
a symlink, and in a linked worktree the default resolution is the *main*
checkout's hooks directory rather than a `.git/hooks` beneath the worktree. The
comparison is between the canonicalised value and the canonicalised result of
`git rev-parse --path-format=absolute --git-path hooks` with the local setting
removed. A naive string comparison either sweeps a real opt-out or preserves a
redundant one, and both failures are silent.

This is not hypothetical tidying. Six repositories on the machine this was
measured on set a local `core.hooksPath`; five name their own default directory,
and one names a husky installation. The floor as originally specified would have
reached none of them, and nothing would have said so.

#### Scenario: A redundant local binding is swept

- **WHEN** a repository's local `core.hooksPath` names the directory git would
  resolve without it
- **THEN** the installer unsets it, having confirmed the equivalence first
- **AND** the repository is governed by the global binding afterwards

#### Scenario: A declared binding is redundant by value

- **WHEN** a repository's local `core.hooksPath` names its default directory and
  the binding is declared
- **THEN** the installer SHALL NOT unset it
- **AND** SHALL report it as declared rather than as redundant

#### Scenario: A real local binding is preserved

- **WHEN** a repository's local `core.hooksPath` names any other directory
- **THEN** the installer SHALL NOT unset it
- **AND** SHALL report the repository as outside the floor by its own choice

### Requirement: The hook is published before the binding is set, and a failed bind unwinds

The installer SHALL publish the `pre-commit` to the machine-level directory
**before** setting `core.hooksPath`, and SHALL unset a binding it created if
publishing did not complete.

Order matters here in a way it usually does not. Binding first and failing
before the hook lands leaves `core.hooksPath` pointing at a directory with no
`pre-commit` — and a commit under that binding **succeeds silently**, verified
on git 2.50.1. The machine is then globally unbound in effect while every
surface reports it as bound. Publishing first means the worst partial state is
a published hook nothing has bound yet, which is the floor as it exists today
and is therefore no regression at all.

The two orders are not symmetric and the safe one costs nothing.

#### Scenario: Publishing fails before the binding is set

- **WHEN** publishing the `pre-commit` fails
- **THEN** `core.hooksPath` SHALL NOT be set
- **AND** the run exits non-zero naming the publish failure

#### Scenario: The binding fails after the hook is published

- **WHEN** the hook is published and setting `core.hooksPath` fails
- **THEN** the published hook remains
- **AND** the run reports the machine as unbound rather than as installed

#### Scenario: A run is interrupted between publish and bind

- **WHEN** a run is interrupted after publishing and before binding
- **THEN** re-running completes the binding without republishing from scratch
- **AND** `--check` reports the intermediate state as published-but-unbound
  rather than as bound

### Requirement: A foreign global hooks binding is reported, never overwritten

If `core.hooksPath` is already set globally to a directory this workflow did not
publish, the installer SHALL report it and SHALL NOT change it. The condition
SHALL be reported as skipped, so the run exits non-zero.

An operator who has bound a hooks directory has done so deliberately, and a tool
that silently rebinds it takes a decision that was already made. This is the
posture the git-hook installer already takes toward a foreign hook, applied one
level up.

#### Scenario: A foreign binding is present

- **WHEN** `core.hooksPath` is set globally to an unrecognised directory
- **THEN** the installer reports the existing value and the value it would have
  set
- **AND** the global configuration is unchanged
- **AND** the step is reported as skipped

#### Scenario: The binding is already ours

- **WHEN** `core.hooksPath` already resolves to the published directory
- **THEN** the installer reports it as satisfied and changes nothing

### Requirement: Nothing is published into a directory another account can write

The installer SHALL refuse to publish into the machine-level hooks directory,
and SHALL NOT bind it, if that directory is a symlink or is group- or
world-writable.

The dispatcher already refuses a symlinked or group/world-writable `hooks.d`,
for the reason that either lets another local account supply code that runs on
every commit. It cannot make the same check about the directory it *lives in*:
by the time the dispatcher runs, anyone who could write there has already
replaced it. The check therefore has to sit one level up, in the thing that
creates the directory, and it has to happen before anything is written.

The symlink case is the sharper of the two and was measured rather than
reasoned about. `mkdir -p` over an existing symlink succeeds silently, so
without the check the run published the dispatcher into the link's target and
bound `core.hooksPath` to it — handing the machine's commit-time hook directory
to whoever owned that target. The mode case is quieter: the directory's
permissions otherwise come from the operator's umask, which is 022 on a stock
macOS and is not guaranteed to be.

#### Scenario: The published directory is a symlink

- **WHEN** the machine-level hooks directory exists and is a symlink
- **THEN** nothing is published and `core.hooksPath` SHALL NOT be set
- **AND** the run exits non-zero naming the directory

#### Scenario: The published directory is writable by others

- **WHEN** the machine-level hooks directory is group- or world-writable
- **THEN** nothing is published and `core.hooksPath` SHALL NOT be set
- **AND** the run exits non-zero and says what to change

### Requirement: Binding activates a directory, so its every entry is inventoried first

The installer publishes one file and binds a **directory**. Git runs whatever
hook it finds there by name, so binding activates every entry — `pre-push`,
`commit-msg`, `prepare-commit-msg`, any of them — machine-wide, for every
repository the floor governs. The installer SHALL inventory the machine-level
hooks directory before binding, and SHALL NOT bind while it holds an entry the
installer did not publish, unless the operator accepts that entry by name.

The asymmetry is the defect: publish is file-scoped, bind is directory-scoped,
and nothing reconciles them. The existing directory guards do not close it —
they establish that the directory is not a symlink and that no *other account*
can write it, which together prove who could have written a file and never that
the operator intended it to run on every commit. An entry the operator placed
there themselves passes both guards.

**Measured 2026-08-08, and the instance is not hypothetical.**
`~/.agenticapps/git-hooks/` on this machine held exactly one file, dated
2026-07-25: a 46-line `pre-commit` vendored from `opencode-workflow`, an
archived host repository scheduled for deletion. It carries no version marker,
so the arbitration reads it as 0.0.0 and the 1.1.0 publish replaces it — that
one entry self-heals. What does not self-heal is the shape: it arrived by a
path nothing inventoried, it sat at the exact filename the binder binds, and it
would have been byte-for-byte the machine's commit gate had it been named
`pre-push` instead. It also exported `OPENSPEC_GATE_SELF=opencode` and described
the pre-2.0.0 semantics in which `REVIEWS.md` blocks — so had it run, every
repository on the machine would have gated commits under an archived host's
identity and a rule retired at gate 2.0.0.

Consent SHALL be per entry and SHALL name it. A blanket "the directory contains
unexpected files, proceed?" is the prompt everyone accepts, and it is the same
acceptance whether the entry is a stale copy of the installer's own hook or a
`pre-push` nobody remembers.

#### Scenario: The directory holds only what the installer published

- **WHEN** the machine-level hooks directory holds no entry other than the
  published `pre-commit`
- **THEN** the installer SHALL bind without prompting
- **AND** the inventory SHALL still be reported, so a clean result is evidence
  rather than silence

#### Scenario: The directory holds an entry the installer did not publish

- **WHEN** the inventory finds an entry the installer did not write
- **THEN** the installer SHALL name the entry, its size and its modification date
- **AND** SHALL NOT bind until the operator accepts that entry by name
- **AND** a refusal SHALL leave the global binding unchanged

#### Scenario: An unpublished entry is a stale copy of the published hook

- **WHEN** the unrecognised entry occupies the published hook's own filename
- **THEN** version arbitration SHALL still decide the publish
- **AND** the entry SHALL still be reported, because a hook replaced silently is
  indistinguishable from a hook that was never there

### Requirement: The published hook composes rather than monopolises

The published `pre-commit` SHALL dispatch to the gate and then to an
operator-owned, machine-level `hooks.d` directory alongside the published
directory.

**The canonical paths are pinned here rather than left to `install.sh`:** the
published directory is `~/.agenticapps/git-hooks/`, the dispatcher is
`~/.agenticapps/git-hooks/pre-commit`, and the composition directory is
`~/.agenticapps/git-hooks/hooks.d/`. `--check` must verify that
`core.hooksPath` "resolves to the published directory", which is unverifiable
while the directory is named only in prose.

**Dispatch order and failure semantics, stated because an earlier revision said
both "run each entry" and "fail on the first non-zero" and those are different
contracts:**

- The gate runs **first**. A non-zero gate exit fails the commit immediately and
  `hooks.d` is **not** entered — the gate is the floor, not one voice among
  several.
- `hooks.d` entries then run in **lexical order by filename**, and the first
  non-zero exit fails the commit; remaining entries do not run. Fail-fast, not
  run-all.
- An entry that is **not executable** is skipped and reported, not silently
  ignored — the same reasoning that makes `--check` verify the dispatcher's own
  execute bit.
- Entries whose names begin with `.` or end in `~`, `.bak`, `.sample`, `.orig`
  or `.rej` are skipped. Editor and packaging debris in a hooks directory is
  the normal case, and executing it is how a stale backup becomes policy.
- An **absent** `hooks.d` is not an error. It is the expected state on a machine
  whose operator composes nothing.

**Entries SHALL be resolved within `hooks.d`, and a symlink whose canonical
target lies outside it SHALL be refused and reported.** Without this the
prohibition below is trivially defeated: a single symlink from `hooks.d` into a
clone re-enables repository-controlled execution at commit time while every
requirement here still reads as satisfied.

It SHALL NOT execute anything resolved from inside a repository — not
`.git/hooks/`, not a tracked path, not a fallback gate at a repository-relative
location. A hook bound machine-wide that falls back to repository-controlled
code makes the contents of every clone executable at commit time, which is the
property `core.hooksPath` exists to remove. Composition is for the operator,
who is the party that wanted it; a repository that needs its own hooks has
git's local override, which is the supported answer.

`core.hooksPath` replaces the hooks directory rather than adding to it, so a
repository that adopts another hook manager leaves the floor. That is not a
future hazard — `fbc-platform` runs husky today and is outside the floor for
exactly this reason, correctly and by its own local binding.

#### Scenario: The published hook runs the gate

- **WHEN** the published `pre-commit` runs
- **THEN** it invokes the gate and propagates its exit status

#### Scenario: The dispatcher composes with the operator's own hooks

- **WHEN** the machine-level `hooks.d` directory contains executable entries
- **THEN** the published hook runs them in lexical order by filename
- **AND** the first non-zero exit fails the commit and stops the remaining
  entries

#### Scenario: The gate fails

- **WHEN** the gate exits non-zero
- **THEN** the commit fails
- **AND** no `hooks.d` entry runs

#### Scenario: hooks.d holds debris and non-executable entries

- **WHEN** `hooks.d` contains a non-executable file, a dotfile, or a `~`/`.bak`
  backup
- **THEN** none of them is executed
- **AND** a non-executable entry is reported rather than silently skipped

#### Scenario: hooks.d is absent

- **WHEN** no `hooks.d` directory exists
- **THEN** the gate runs and the commit proceeds on its verdict alone
- **AND** this is not reported as a fault

#### Scenario: A hooks.d entry links outside the directory

- **WHEN** an entry is a symlink whose canonical target lies outside `hooks.d`
- **THEN** it is refused and reported, naming the target
- **AND** it is not executed, whether or not the target is inside a repository

#### Scenario: The dispatcher refuses repository-controlled code

- **WHEN** a repository contains its own `pre-commit` or a repository-relative
  gate
- **THEN** the published hook SHALL NOT execute it
- **AND** the refusal SHALL hold whether or not the shared gate is available

#### Scenario: A repository has hooks the global directory does not carry

- **WHEN** a repository's own hooks are displaced by the global binding
- **THEN** the condition is reportable by `--check` rather than silent

### Requirement: The check mode reports which enforcement surfaces are active

`--check` SHALL report whether `core.hooksPath` is set, whether it resolves to
the published directory, and whether the published `pre-commit` is current by
content against the checkout.

It SHALL report the **effective** binding for the repository it runs in, not the
global one. A local `core.hooksPath` is preferred by git, so reporting the
global binding as active is simply wrong wherever one is set — and one is set in
six repositories today. A `--check` that says the floor is bound while the
repository it ran in is outside the floor is worse than no report, because it is
believed.

Removing a surface makes it more important, not less, that an operator can see
which surfaces remain. "The workflow got weaker" and "the workflow moved its
floor" are indistinguishable from the outside unless something says which.

#### Scenario: The machine is fully bound

- **WHEN** `--check` runs on a bound machine
- **THEN** it reports the global binding as present and current
- **AND** it names the surfaces that enforce the gate

#### Scenario: The machine is unbound

- **WHEN** `--check` runs where `core.hooksPath` is unset
- **THEN** it reports the floor as not bound
- **AND** it states what to run to bind it

#### Scenario: The repository is outside the floor

- **WHEN** `--check` runs in a repository with a local `core.hooksPath`
- **THEN** it reports the effective binding rather than the global one
- **AND** it states that the global floor does not govern this repository

#### Scenario: The binding is dangling

- **WHEN** `core.hooksPath` is set to a directory that does not exist
- **THEN** `--check` reports the binding as dangling
- **AND** it states that commits in every repository the binding governs are
  proceeding **ungated and silently**, rather than failing

> **An earlier revision of this scenario had it backwards**, asserting that
> `git commit` fails machine-wide until the directory is restored. Tested on
> git 2.50.1 with `core.hooksPath` pointing at an absent directory: the commit
> **succeeds, exit 0**, and nothing is reported. A dangling binding does not
> break the machine loudly; it removes the floor quietly, which is the failure
> mode `core-self-enforcement` names as the one this workflow must not have.
> The correction matters because it changes what `--check` is *for* here: it is
> not a convenience that explains a visible breakage, it is the only surface
> that would ever mention this at all.

#### Scenario: The published hook is not executable

- **WHEN** the published `pre-commit` has correct content but lacks its execute
  bit
- **THEN** `--check` reports the floor as **not active**
- **AND** SHALL NOT report it as current on the strength of content alone,
  because git does not run a non-executable hook

#### Scenario: The published hook has been hand-edited

- **WHEN** the published `pre-commit` differs by content from the checkout at
  the same version
- **THEN** `--check` reports it as modified rather than current
