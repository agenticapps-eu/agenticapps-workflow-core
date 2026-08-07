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

### Requirement: The installer is short enough to be read before it is trusted

The installer SHALL NOT exceed 217 executable lines, counting neither comments
nor blank lines.

> **This change spends, it does not save.** The host wiring was already removed
> by `core-installer-one-entry-point`, which is where the budget came back from
> 250 to 217 and where the implementation landed at 210. This change adds: the
> published hook, the global binding, the foreign-binding refusal, and four new
> `--check` reports. That is growth, and 7 lines of headroom is plainly not
> enough for it.
>
> The budget is therefore **not pre-raised here**, and saying in advance that it
> will not fit is the point rather than an admission. If the mandatory behaviour
> does not fit, the escape clause applies as written — itemise the overage, name
> the behaviour responsible, and raise the number in this document. What is not
> permitted is arriving at 240 and discovering the ceiling had already been
> moved to accommodate it.

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

- **WHEN** a repository with no local `core.hooksPath` on a bound machine runs
  `git commit`
- **THEN** the published gate runs
- **AND** the repository required no installation step of its own

#### Scenario: A repository needs different hooks

- **WHEN** a repository sets its own `core.hooksPath` in local configuration
- **THEN** the local setting governs that repository
- **AND** the global binding SHALL NOT reach it
- **AND** the installer neither prevents nor repairs this

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
