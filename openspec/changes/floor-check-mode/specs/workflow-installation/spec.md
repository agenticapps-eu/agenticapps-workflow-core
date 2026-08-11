## ADDED Requirements

### Requirement: The floor binder's check mode reports which enforcement surfaces are active

`bind-global-floor.sh --check` SHALL report whether `core.hooksPath` is set,
whether it resolves to the published directory, and whether the published
`pre-commit` is current by content against the checkout.

**Named for its binder, not for its flag.** The installer already has a mode
called "the check mode" in this same capability, and it answers a different
question about different artifacts. Two requirements whose headers both begin
"the check mode" is how a reader comes to satisfy one by reading the other.

It SHALL report the **effective** binding for the repository it runs in, not the
global one. A local `core.hooksPath` is preferred by git, so reporting the
global binding as active is simply wrong wherever one is set — and one is set in
six repositories today. A `--check` that says the floor is bound while the
repository it ran in is outside the floor is worse than no report, because it is
believed.

Removing a surface makes it more important, not less, that an operator can see
which surfaces remain. "The workflow got weaker" and "the workflow moved its
floor" are indistinguishable from the outside unless something says which.

**The surfaces are enumerated, never summarised**, and they are exactly three:

| Surface | What makes it active |
|---|---|
| the published `pre-commit` | present, **executable**, and current by content |
| the gate executable it invokes | `$OPENSPEC_GATE`, else `$OPENSPEC_CHANGE_GATE`, else `~/.agenticapps/bin/openspec-change-gate.sh` — present and executable |
| the `hooks.d` entries | present, executable, and resolving inside `hooks.d` |

The second row is the one a summary drops and the one that matters most. **The
dispatcher fails open when the gate executable is missing** — it warns and exits
0, deliberately, because a commit hook that hard-fails on absent tooling teaches
people to pass `--no-verify` and disables the floor permanently rather than
momentarily. So a floor that is bound, published, current *and* executable still
gates nothing when the gate is absent, and a report that stopped at the
dispatcher would state the opposite of the truth about that machine.

**CI SHALL NOT be reported as a surface.** Whether a workflow file exists is
visible locally; whether it blocks a merge is a setting on the forge. Inferring
the second from the first is the false assurance this mode exists to remove.

**Currency is a state, not a boolean**, and the states SHALL be distinguished,
because the publisher deliberately preserves a published file that is newer than
the checkout — so byte-inequality alone cannot tell a legitimately newer hook
from a hand-edited one:

| State | Condition |
|---|---|
| absent | nothing at the published path |
| a symlink | the published path is a link, whatever it points at |
| not a regular file | a directory, FIFO or device at the published path |
| not executable | present without its execute bit |
| current | identical to the checkout's dispatcher, byte for byte |
| modified | same version marker as the checkout, different bytes |
| ahead | a strictly newer version marker than the checkout |
| not current | an older version marker than the checkout |

This is the classification the installer's check mode already applies to the
four published executables. Answering the same question a second way is how two
doctors come to disagree about one machine.

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

#### Scenario: The global binding is dangling

- **WHEN** the global `core.hooksPath` is set to a directory that does not exist
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

#### Scenario: A repository's own binding is dangling

- **WHEN** a repository's **local** `core.hooksPath` names a directory that does
  not exist
- **THEN** `--check` reports that repository as ungated
- **AND** SHALL NOT describe the consequence as machine-wide, because a local
  binding governs one repository and the rest of the machine is unaffected

#### Scenario: The published directory exists and holds no dispatcher

- **WHEN** `core.hooksPath` resolves to a directory that exists but contains no
  `pre-commit`
- **THEN** `--check` reports the dispatcher as absent
- **AND** it states that commits proceed ungated, exactly as for a dangling
  binding — an empty hooks directory and a missing one silence the floor
  identically

#### Scenario: The published directory is writable by another account

- **WHEN** the published hooks directory is group- or world-writable
- **THEN** `--check` reports it, naming the consequence: another local account
  could replace the hook that runs on every commit

> The binder **refuses to publish** into such a directory, and reporting it is
> the other half of that guard. A machine already in this state reads as
> perfectly healthy to a mode that compares content — the comparison does catch
> a substituted hook, but it cannot show that the machine is open to the
> substitution at all, which is precisely the posture question this mode exists
> to answer.

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

#### Scenario: The published hook is newer than the checkout

- **WHEN** the published `pre-commit` carries a strictly newer version marker
  than the checkout's
- **THEN** `--check` reports it as ahead of the checkout
- **AND** SHALL NOT report it as modified, because the publisher preserves a
  newer destination by design and reporting correct state as drift is how a
  report loses its reader

#### Scenario: The published path is not a regular file

- **WHEN** the published path is a directory, a FIFO or a device
- **THEN** `--check` reports it as not a regular file and the floor as not active
- **AND** SHALL NOT read its contents

> `[ -x ]` is true of a directory, and reading a FIFO blocks forever — so a
> check that inspected content before settling the type would **hang** rather
> than report, which is the one failure mode a diagnostic must not have.

#### Scenario: The dispatcher git runs is one the checkout cannot vouch for

- **WHEN** an enrolled repository resolves to a published dispatcher that is
  *modified* or carries no parseable marker
- **THEN** `--check` reports the repository as gated by the floor, **qualified**:
  git runs the dispatcher, and what it enforces is not this checkout's gate
- **AND** SHALL NOT report it plainly gated

> Two claims, and collapsing them makes the verdict over-claim. "git runs the
> floor here" is structural and knowable; "the floor is still this checkout's
> gate" is a fact about content. A hand-edited hook that exits 0 satisfies the
> first and defeats the second. `ahead` is deliberately excluded — the publisher
> preserves a newer destination by design, and qualifying it would be the false
> alarm this spec already refuses elsewhere.

#### Scenario: The composition directory is one the dispatcher refuses

- **WHEN** `hooks.d` is a symlink, is not owned by the operator, or is group- or
  world-writable
- **THEN** `--check` reports that the dispatcher refuses to run while it is, so
  every commit in every enrolled repository is blocked
- **AND** SHALL NOT list its entries as running after the gate

> The dispatcher applies all three guards before any entry runs, and failing
> them blocks the commit. A report that listed the entries as active would
> describe a healthy machine that is in fact wedged.

#### Scenario: A composition entry resolves outside hooks.d

- **WHEN** a `hooks.d` entry is a symlink whose canonical target is outside
  `hooks.d`
- **THEN** `--check` reports that the dispatcher refuses it, so every commit in
  every enrolled repository is blocked
- **AND** SHALL NOT list it as running after the gate
- **AND** the containment SHALL be judged on the canonical target, never the
  link text, because a relative link leaves the directory just as surely as an
  absolute one

#### Scenario: The gate executable the dispatcher invokes is absent

- **WHEN** the floor is bound and the published dispatcher is current and
  executable, but the gate executable it invokes is absent
- **THEN** `--check` reports the gate as absent
- **AND** it states that the dispatcher fails open, so enrolled repositories are
  committing ungated
- **AND** SHALL NOT report the floor as enforcing on the strength of the
  dispatcher alone

### Requirement: The check mode reports what the floor does not reach

The floor governs only repositories carrying `agenticapps.workflow.enrolled`,
and from the outside an unenrolled repository is indistinguishable from an
enrolled one: no file, no marker, no output. Measured 2026-08-11, 39 of 41
repositories under one root resolve to the published dispatcher and nothing in
any of them says so. `--check` SHALL report, for each repository it is given,
whether the floor gates it.

**Enrolment SHALL be read exactly as the dispatcher reads it** — `--local`,
`--type=bool`, and the value must normalise to `true`. Anything else is *not
enrolled*: `false`, a malformed value, and a key set only in global
configuration all read as ungated, because that is what the dispatcher does at
commit time and the report's whole value is that it agrees with the hook.

A repository carrying `openspec/` and not enrolled SHALL be reported as ungated.
That report SHALL state what is true — the floor does not gate it — and SHALL
NOT assert that it ought to be enrolled. Enrolment is an act, and a mode that
inferred intent from the shape of a directory would be the predicate this
capability already refused to build, wearing a report's clothes.

**Where the effective hooks directory is not the repository's own**, hooks
present in the repository's own directory SHALL be reported as displaced.
Measured on git 2.50.1: with `core.hooksPath` set, `.git/hooks` is not consulted
at all, so an executable `.git/hooks/pre-commit` there does not run and nothing
says so. The precedence runs this way and not the other — a repository hook
cannot bypass the floor, the floor silently displaces the repository hook.

**Outside the floor is not the same as ungated**, and the verdict SHALL say
which. Where a repository's hooks resolve to its own hooks directory and that
directory holds an executable `pre-commit`, `--check` SHALL name that hook as
what git runs there, and SHALL state that the **floor** does not gate the
repository rather than that nothing does.

Core is the case that makes this necessary rather than pedantic: it binds
locally by design so that its commits are scored by the gate in the working tree
it is editing rather than by the published copy (ADR-0028), and that hook carries
no enrolment predicate at all. A report that called core ungated would be true
about the floor and false about the repository — and core is the repository an
operator runs this in most. "The workflow moved its floor" and "the workflow got
weaker" are indistinguishable from the outside unless something says which.

**The repositories it reports on are the ones it is given.** The grammar is
`--check [repository ...]`, and with no repository named it reports the one it
runs in. It SHALL NOT search the filesystem for repositories. The binder's
migration set is named and never discovered, and a mode that only inspects has
no better claim to walk the machine than the mode that mutates; a census whose
scope is a hard-coded root answers a question nobody asked and reports the answer
as if it were complete.

A name that is not inside a git repository SHALL be reported and skipped rather
than stopping the run. The migration refuses the whole run on a bad name because
it is about to mutate and a set that cannot be stated correctly cannot be
accepted correctly; a report has no such reason, and discarding nine good
sections because the tenth name was wrong is a cost with nothing bought by it.

A name **inside** a repository SHALL resolve to that repository's top, and the
report SHALL name the repository it resolved to. The migration refuses this,
because there a typed path that is not an identity would mutate a repository
nobody named. Reporting on one is not the same act: the resolution is visible in
the output, and the operator can see which repository they were answered about.

#### Scenario: An enrolled repository on a bound machine

- **WHEN** `--check` runs in an enrolled repository whose hooks resolve to the
  published directory
- **THEN** it reports the repository as enrolled and gated by the floor

#### Scenario: A repository carries openspec and never enrolled

- **WHEN** `--check` is given a repository containing `openspec/` with no
  `agenticapps.workflow.enrolled` key
- **THEN** it reports the repository as **not enrolled** and not gated by the
  floor
- **AND** SHALL NOT state that the repository ought to be enrolled

#### Scenario: Enrolment is present and false

- **WHEN** a repository sets `agenticapps.workflow.enrolled` to `false`, to a
  value git cannot read as a boolean, or only in global configuration
- **THEN** `--check` reports it as not enrolled
- **AND** the report agrees with what the dispatcher does at commit time

#### Scenario: The repository's own hooks are displaced

- **WHEN** a repository whose hooks resolve to the floor still carries an
  executable `pre-commit` in its own hooks directory
- **THEN** `--check` reports that hook as displaced and no longer consulted

#### Scenario: A repository's hooks path is relative

- **WHEN** a repository's `core.hooksPath` is a relative value
- **THEN** `--check` resolves it against **that repository**, not against the
  directory the check was run from

> Git resolves a relative value per repository, and a relative value is not
> exotic — husky has shipped `core.hooksPath = .husky/_` for years. Resolving it
> against the checker's working directory reports a perfectly good hooks
> directory as missing for every repository except the one the checker happened
> to be standing in, which is the class of bug that only appears once the mode
> is given a repository other than the cwd.

#### Scenario: A repository outside the floor carries its own hook

- **WHEN** a repository's hooks resolve to its own hooks directory and that
  directory holds an executable `pre-commit`
- **THEN** `--check` names that hook as what git runs there
- **AND** the verdict states that the **floor** does not gate the repository,
  rather than that nothing does

#### Scenario: Several repositories are named

- **WHEN** `--check` is given more than one repository
- **THEN** it reports one section per repository, in the order given

#### Scenario: A name is not a repository

- **WHEN** one of the names given to `--check` is not inside a git repository
- **THEN** that name is reported as such and skipped
- **AND** every other named repository is still reported

#### Scenario: A name is a subdirectory of a repository

- **WHEN** a name given to `--check` is inside a repository rather than at its
  top
- **THEN** the report resolves it to that repository's top and names the
  repository it resolved to

### Requirement: The check mode reports and repairs nothing

`--check` SHALL create no file and no directory, SHALL set no git configuration
at any scope, and SHALL exit 0 whenever it completes a report — whatever that
report found.

A mode that can change state is one an operator has to think before running, and
the whole value here is that asking is free. This is not a style preference: the
binder as it stands creates the published hooks directory *before* it parses its
arguments, so a check mode wired in at any convenient point would write a
directory on a machine the operator only asked a question about.

**The exit code SHALL NOT encode the findings.** A caller that branches on it
turns a report into a gate, which is a different decision with different failure
modes, and it would make the answer "the floor is unbound" indistinguishable from
"the command did not run".

A usage error is not a finding, and this requirement does not oblige `--check` to
exit 0 for one. The distinction is between a report that completed and said
something bad, which exits 0, and a run that produced no report at all.

#### Scenario: Nothing is written

- **WHEN** `--check` runs on a machine with nothing installed
- **THEN** it creates no file and no directory, including the published hooks
  directory
- **AND** it sets no git configuration at global, local or system scope

#### Scenario: Everything it could report is wrong

- **WHEN** `--check` runs where the binding is dangling, the dispatcher absent
  and the repository unenrolled
- **THEN** it reports every one of those
- **AND** it exits 0

#### Scenario: The exit code is the same either way

- **WHEN** `--check` runs on a fully bound machine and on a completely unbound
  one
- **THEN** both runs exit 0
