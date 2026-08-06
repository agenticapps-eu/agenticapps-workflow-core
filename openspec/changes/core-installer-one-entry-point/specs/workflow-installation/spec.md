## ADDED Requirements

### Requirement: One command installs the workflow, and it names no host

The workflow SHALL be installable by a single command in core that requires no
host argument. Running it with no arguments SHALL publish the payload and
install core's own git pre-commit hook. A host is an optional addition to that
install, never a precondition for it.

An operator who has never heard of the five hosts SHALL still get a working
install: the git and CI floor is the workflow, and host wiring is what makes it
convenient.

#### Scenario: A bare run installs without a host

- **WHEN** the operator runs the installer with no arguments
- **THEN** the payload is published and core's git pre-commit hook is installed
- **AND** the run succeeds without any host being detected, named, or wired

#### Scenario: No host is installed on the machine

- **WHEN** the installer runs on a machine where no host is installed
- **THEN** it exits successfully, having published the payload and the hook
- **AND** it reports that no host was wired rather than treating it as an error

### Requirement: The installer orchestrates the existing install paths rather than reimplementing them

Publishing an executable and installing a git hook are already implemented in
this repository, and those implementations carry contracts that were learned
from failures: version arbitration, refusal to downgrade, cross-installer
locking, atomic replacement, attestation, resolution of the hooks directory
through `git rev-parse`, tolerance of linked worktrees and `core.hooksPath`,
and refusal to overwrite a hook the workflow does not own.

The installer SHALL delegate to those implementations. It SHALL NOT copy,
`install`, or write an executable or a git hook by its own means.

A front end that reimplements its back end acquires the back end's bugs without
its fixes. The contracts are not incidental detail — the published log on this
machine records downgrades taken deliberately through the version-arbitration
path, and a plain copy would have silently overwritten them.

#### Scenario: An executable is published

- **WHEN** the installer publishes an executable that is not a project hook
- **THEN** it does so through the versioned install path, passing that
  artifact's version-marker key
- **AND** a destination already holding a strictly newer version is left intact
  and reported as **satisfied**, because the postcondition that the destination
  is at least as new as the source holds either way

#### Scenario: A project hook is published

- **WHEN** the installer publishes a project-hook implementation
- **THEN** it does so through the installer that publishes the whole declared
  set and writes the attesting manifest, not through the per-artifact versioned
  install path
- **AND** the published set is the declared set, so an implementation missing
  from the source is reported rather than silently publishing a smaller set

#### Scenario: A published artifact is not executable

- **WHEN** any artifact has been published
- **THEN** the destination is executable

#### Scenario: A git hook is installed

- **WHEN** the installer installs core's own git pre-commit hook
- **THEN** it does so through the existing hook installer
- **AND** a hook the workflow does not own is refused rather than replaced

### Requirement: Skills are bound by symlink and never copied

The installer SHALL bind `skills/*` into a host's skill directory by symlink to
the checkout. It SHALL NOT copy a skill into a host directory under any
circumstance, including when a symlink cannot be created.

A copy is the drift this capability exists to remove: a copied skill is a second
version that no update reaches, and the machine then holds two files claiming to
be the same skill.

#### Scenario: A skill is bound into a host

- **WHEN** the installer wires a host whose skill directory is known
- **THEN** each entry in `skills/` appears in that directory as a symlink
  resolving to the core checkout
- **AND** no regular file or directory with the same name is written there

#### Scenario: A symlink cannot be created

- **WHEN** the installer cannot create a symlink at the target path
- **THEN** it reports the failure for that host and continues with the others
- **AND** it does not fall back to copying

### Requirement: Every state a binding target can be in is defined

A target path may hold a symlink into the core checkout, a symlink resolving
elsewhere, a dangling symlink, a relative symlink, a regular file, or a
directory. A skill is normally a *directory*, so the directory case is the most
likely one, not an edge case.

The installer SHALL define an outcome for every one of those states, SHALL
report which state it found by path, and SHALL NOT replace or remove anything it
did not recognise as a binding this workflow installed without the operator's
acceptance.

Recognition is what separates the two treatments. A symlink into a checkout the
legacy manifest names is this workflow's own binding and is replaced outright. A
symlink pointing anywhere else may belong to unrelated software, and a directory
or a regular file may hold someone's work — none of those may be replaced on the
installer's own judgement.

#### Scenario: A symlink into an unmaintained checkout occupies the target

- **WHEN** the target holds a symlink resolving into a checkout the legacy
  manifest names
- **THEN** the installer replaces it with a symlink into the current checkout
- **AND** it reports the replacement and names the previous target

#### Scenario: A symlink to something unrecognised occupies the target

- **WHEN** the target holds a symlink resolving outside the core checkout and
  outside every checkout the legacy manifest names
- **THEN** the installer reports what it found, naming the previous target, and
  replaces it only with the operator's acceptance
- **AND** without that acceptance the entry is left in place and counted as
  skipped

#### Scenario: A copied skill directory occupies the target

- **WHEN** the target holds a directory rather than a symlink
- **THEN** the installer reports it as a copy, and replaces it only with the
  operator's acceptance
- **AND** without that acceptance the entry is left in place and counted as
  skipped

#### Scenario: A regular file occupies the target

- **WHEN** the target holds a regular file
- **THEN** the installer reports it, and replaces it only with the operator's
  acceptance
- **AND** without that acceptance the entry is left in place and counted as
  skipped

#### Scenario: A dangling or relative symlink occupies the target

- **WHEN** the target holds a symlink that resolves nowhere, or one whose target
  is relative
- **THEN** the installer resolves it before judging which of the cases above
  applies
- **AND** any replacement it then makes is an absolute symlink into the checkout

### Requirement: Legacy bindings are replaced from a named manifest, not by iteration

The skills this workflow has installed under previous names SHALL be listed
explicitly. Iterating the current `skills/` directory cannot find them: their
names differ from anything core ships today, including host-prefixed names and
separate setup, update, audit and review skills.

The installer SHALL carry that manifest, and SHALL replace or remove every name
on it, reporting which of the two it did.

Without the manifest, deleting an archived checkout leaves dangling skills that
each host will still try to load, which is the failure this whole change exists
to prevent.

The manifest's own completeness SHALL NOT be established by reading the manifest.
The installer SHALL enumerate every known host skill directory and SHALL act on
every entry resolving into an unmaintained checkout, whether or not the manifest
names it. A check that consults the manifest to decide what to check cannot
detect the omission that matters, which is a name the manifest does not carry.

For an entry the manifest does not name, the installer SHALL rebind it to the
host-neutral equivalent where one is installed, and SHALL remove it where none
is. Reporting such an entry and leaving it is not sufficient: the operator
cannot act on a report of a binding they did not create and do not recognise,
and the binding breaks the moment the checkout is deleted either way. Both
outcomes SHALL be reported by name, together with the target replaced.

#### Scenario: A legacy binding is present

- **WHEN** a host holds a binding under a legacy name the manifest lists
- **THEN** the installer replaces it with the current binding, or removes it
  when nothing current replaces it
- **AND** it reports which of the two it did, by name

#### Scenario: A binding the manifest does not name resolves into an unmaintained checkout

- **WHEN** an entry in a known host skill directory resolves into a checkout the
  workflow no longer maintains and the manifest does not name it
- **THEN** it is rebound to the host-neutral equivalent if one is installed, and
  removed otherwise
- **AND** the outcome is reported by name, together with the target replaced
- **AND** after the run it no longer resolves into that checkout

#### Scenario: A binding into an unmaintained checkout survives anyway

- **WHEN** after a run any such binding still resolves into an unmaintained
  checkout
- **THEN** the run reports it, by path and by resolved target
- **AND** the condition is treated as a defect, not accepted

### Requirement: Only git and bash may hard-fail the install

The installer SHALL treat exactly two prerequisites as required: `git` and
`bash`. Every other dependency SHALL be checked, reported when absent, and SHALL
NOT by its mere absence fail the install.

For a missing optional dependency the installer SHALL print the command that
would install it and SHALL NOT run that command.

#### Scenario: An optional dependency is absent and nothing needed it

- **WHEN** an optional dependency is absent and no requested step needed it
- **THEN** the install completes and exits zero
- **AND** the absence is reported with the install command printed but not run

#### Scenario: A required prerequisite is missing

- **WHEN** `git` is not available and the installer runs
- **THEN** the installer fails with a message naming `git`
- **AND** it does not partially publish the payload

### Requirement: A requested step that was skipped exits non-zero

When a step the operator asked for could not be performed, the installer SHALL
name the step and the prerequisite it needed, SHALL state the command that
completes it later, SHALL distinguish completed work from skipped work in its
summary, and SHALL exit non-zero.

This is `installer-prerequisite-consent` applied here, restated because the
obvious implementation gets it wrong: an installer that reports a skip and
exits zero has told the operator one thing and every automated caller another,
and the exit code is what the caller reads.

Work whose desired end state already holds is **satisfied**, not skipped, and
SHALL NOT make the exit non-zero. A destination already carrying a version at
least as new as the source is the case this exists for: the delegated installer
declares that outcome a success, and classifying it as skipped would report
failure on a machine that is in exactly the intended state.

#### Scenario: A destination already holds a newer version

- **WHEN** a publish leaves a destination intact because it already holds a
  strictly newer version
- **THEN** the step is counted as satisfied
- **AND** it does not by itself make the run exit non-zero

#### Scenario: Requested wiring is skipped for a missing tool

- **WHEN** the operator names a host to wire and the tool needed to edit that
  host's configuration is absent
- **THEN** the skill binding for that host still proceeds
- **AND** the wiring step is named as skipped, with the command that completes it
- **AND** the run exits non-zero

#### Scenario: Nothing was requested that could not be done

- **WHEN** every step the operator asked for was performed
- **THEN** the run exits zero

### Requirement: Host configuration is changed only with the operator's acceptance

A host's configuration file belongs to that host, not to this workflow, and on a
real machine it carries entries written by unrelated tools. The installer SHALL
obtain the operator's acceptance before modifying such a file, SHALL default to
no when asked interactively, and SHALL report rather than choose when it cannot
ask.

Before modifying one, the installer SHALL preserve a copy that the operator can
restore, and SHALL confirm the modified content parses before it replaces the
original.

The opt-in that permits this without a prompt SHALL be a named flag, with an
environment-variable equivalent for automated callers, and SHALL appear in the
installer's own usage output. An opt-in that cannot be named cannot be given, so
without one every non-interactive run either prompts into a closed input or
assumes consent it was never granted.

#### Scenario: Acceptance is declined

- **WHEN** the operator declines the change to a host's configuration
- **THEN** the file is not modified
- **AND** the step is reported as skipped, which exits non-zero

#### Scenario: The run cannot ask

- **WHEN** the installer runs non-interactively without a named opt-in
- **THEN** it reports the configuration change it would have made and does not
  make it

#### Scenario: The modified content does not parse

- **WHEN** the rendered configuration does not parse
- **THEN** the original file is left byte-for-byte unchanged
- **AND** the failure is reported and the step counted as skipped

### Requirement: Wiring never asserts a rule the gate does not enforce

Text the installer writes into a host — a plugin, an adapter, or a message it
causes a host to print — SHALL describe the gate's actual behaviour. It SHALL
NOT state that review evidence is required, that a review count is enforced, or
any other condition the gate does not block on.

An operator who is told the gate requires reviews will go and get reviews to
unblock an edit that was never blocked for that reason, and will mistrust every
later message from the same source. Wiring carried forward from an older
installation SHALL be checked against current gate behaviour before it is
reused, never copied on the assumption that an installed file is current.

#### Scenario: Existing wiring is carried forward

- **WHEN** wiring is derived from a copy installed by a previous version
- **THEN** its description of gate behaviour is verified against the gate as it
  now behaves
- **AND** any statement the gate no longer implements is corrected before the
  wiring is installed

#### Scenario: Wiring reports a blocked edit

- **WHEN** installed wiring blocks an edit and explains why
- **THEN** the explanation names only the condition the gate actually blocked on

### Requirement: A host whose wiring is unknown is bound as far as it is known

Hosts differ in how much of them has been measured. The installer SHALL bind
each host to the extent its layout is confirmed, and SHALL NOT guess at the rest.

For a host with a known skill directory and no confirmed hook wiring, the
installer SHALL create the skill binding and SHALL NOT write any hook
configuration. That state is conformant, not degraded: the host runs on the git
and CI floor, which is where enforcement actually lives. Because the operator
did not request wiring that does not exist, this state does not exit non-zero.

#### Scenario: A host has a known skill directory and no confirmed wiring

- **WHEN** the installer binds such a host
- **THEN** the skills are bound into that host's skill directory
- **AND** no hook configuration file is created or modified for that host
- **AND** the host is reported as installed with wiring absent, not failed

### Requirement: A host is detected by evidence that it is installed

Auto-detection SHALL test for evidence that a host is actually installed — its
executable, or state only that host writes — and SHALL NOT infer a host from the
presence of a directory alone.

A directory can exist for unrelated reasons, and one skill directory in this
layout is shared by two hosts and by unrelated tools, so its presence identifies
no host at all. Wiring a host that is not installed writes configuration nobody
reads and reports an install that did not happen.

#### Scenario: A directory exists but the host does not

- **WHEN** a host's directory exists and that host is not installed
- **THEN** auto-detection does not report that host as present and does not wire it

#### Scenario: A skill directory is shared by more than one host

- **WHEN** a skill directory serves more than one host
- **THEN** the binding is reported once, as a shared binding, naming the hosts
  that read it
- **AND** it is not reported as evidence that any particular one is installed

### Requirement: The check mode reports state and changes nothing

The installer SHALL provide a check mode reporting, for each declared artifact
and binding: whether it is present, which version it holds, and whether it is
current with respect to the checkout. For each host it SHALL report whether
skills are bound and whether the hook is wired.

Presence alone is not a state worth reporting. A stale, downgraded or
hand-edited executable is present, and reporting it as installed tells the
operator the machine is in a condition it is not in.

**Currency SHALL be judged against the checkout by content, not by comparing
version markers.** A hand-edited artifact carries the marker it was published
with, so a marker comparison reports it current — which is the precise condition
an operator runs this mode to discover. Check mode SHALL distinguish an artifact
whose content matches the checkout, one whose version is behind, one whose
version is ahead, one carrying the same version as the checkout with different
content, and one that is present but cannot be read.

Check mode SHALL NOT create, modify, or delete any file, including files it
would create in a normal run.

#### Scenario: Check runs on an uninstalled machine

- **WHEN** check mode runs on a machine with nothing installed
- **THEN** it reports every host as unbound and every artifact as absent
- **AND** no file is created anywhere as a result of the run

#### Scenario: A published artifact is behind the checkout

- **WHEN** a published executable holds a version older than the checkout's
- **THEN** check mode reports the artifact as present, names both versions, and
  reports it as not current

#### Scenario: A published artifact was edited in place

- **WHEN** a published executable carries the same version as the checkout but
  its content differs
- **THEN** check mode reports it as not current, and distinguishes it from an
  artifact that is merely behind

#### Scenario: A published artifact cannot be read

- **WHEN** a published artifact is present but cannot be read, or its version
  marker cannot be parsed
- **THEN** check mode reports that state, and does not report the artifact as
  either current or absent

#### Scenario: Check reports a partial install

- **WHEN** one host is bound and another is not
- **THEN** the report distinguishes the two
- **AND** an unbound host that was not requested does not by itself make the
  exit status non-zero

### Requirement: Installing twice leaves the same machine as installing once

The installer SHALL be idempotent. A second run with the same arguments SHALL
produce the same machine state as the first and SHALL NOT duplicate a symlink, a
hook entry, or a configuration block.

Duplicate detection SHALL be semantic rather than textual. A configuration file
rewritten by a serialiser does not come back byte-identical, so a textual test
would either add a second copy of an entry that is already present or report a
change that did not happen.

#### Scenario: The installer runs twice

- **WHEN** the installer is run twice with identical arguments
- **THEN** the second run reports no new bindings created
- **AND** the machine state after the second run is identical to the state after
  the first

### Requirement: What the installer replaces with its own hands is recoverable

Before replacing or removing a binding or a host configuration file, the
installer SHALL preserve what it is about to destroy at a reported path, and
SHALL state how to restore it. Preserved copies SHALL NOT overwrite one another,
SHALL carry the permissions of what they preserve, and a preservation that fails
SHALL abort that step rather than proceed unprotected.

A rollback plan that names no artifact is not a rollback plan. The version log
records that a downgrade happened; it does not hold the bytes needed to undo one.

This guarantee does **not** extend to published artifacts, and SHALL NOT be
claimed for them. Publishing happens inside a delegated installer that holds a
lock across its own read-compare-write, so a copy taken before delegating can be
superseded before that lock is acquired — a backup that is only valid when
nothing else is running does not protect the case it exists for. For published
artifacts the protection is the arbitration itself: refusal to downgrade, and an
explicit opt-in with a stated reason for an operator who means it.

#### Scenario: A binding is replaced

- **WHEN** the installer replaces an existing binding or host configuration file
- **THEN** the previous content is preserved at a path the run reports
- **AND** the summary states the command that restores it

#### Scenario: A second run replaces the same target

- **WHEN** the installer replaces a target it has already preserved a copy of
- **THEN** the earlier preserved copy is left intact and the new one is written
  beside it

#### Scenario: A copy cannot be preserved

- **WHEN** the installer cannot write the preserved copy
- **THEN** it does not perform the replacement
- **AND** the step is reported as skipped

### Requirement: The installer is short enough to be read before it is trusted

The installer SHALL NOT exceed 250 executable lines, counting neither comments
nor blank lines. An operator is being asked to let it write into their home
directory and their host configuration, and the honest basis for that trust is
reading it.

> **The number was 200, and it was raised once, deliberately.** The first draft
> of this requirement was written before the second review round, which added
> behaviour rather than polish: currency judged by content rather than by
> version marker (13 lines), the archived-binding scan that must not consult the
> legacy manifest (14), `wire_opencode`, which the first draft created and never
> installed (10), the preserved-copy collision, permission and failure rules (8),
> and the second opt-in, separated from the first because one grants an editor
> config edit and the other grants deleting a directory (12). That is 57 lines
> the original 200 predates; without them the implementation measures ~189.
>
> The budget worked as designed here. It did not prevent the growth — it made
> the growth itemisable, and forced the choice to be made in this document
> rather than absorbed silently in the script. Raising it is the outcome the
> requirement's own escape clause prescribes, not a failure of it.

A budget with no stated order of sacrifice is a suggestion, because the choice of
what to drop then falls to whoever is writing the last line and is furthest from
the reasoning. So the specification SHALL fix, in advance, which behaviour is
mandatory and which may be deferred, and in what order.

Mandatory: every mode named in this specification, publishing, skill binding,
the legacy manifest, and every acceptance and preservation rule. None may be
omitted to fit.

Deferrable, in order: reporting distinctions within check mode that collapse into
a coarser but still correct state; then hook wiring for an individual host, which
leaves that host bound and unwired — a state this specification already defines
as conformant.

Anything deferred SHALL be reported to the operator, naming what was deferred and
why. If the mandatory behaviour alone exceeds the budget, the overage SHALL be
reported together with the behaviour responsible, and the budget SHALL be raised
by amending this specification rather than silently in the implementation.

#### Scenario: The budget is measured

- **WHEN** the installer's executable lines are counted
- **THEN** the count is at most 250

#### Scenario: The budget cannot be met

- **WHEN** the behaviour this specification requires cannot fit the budget
- **THEN** what is dropped is taken from the deferrable list, in the stated order
- **AND** each deferral is reported to the operator with the reason
- **AND** no mandatory behaviour is omitted to fit

#### Scenario: The mandatory behaviour alone exceeds the budget

- **WHEN** the mandatory behaviour alone cannot fit the budget
- **THEN** the overage is reported together with the behaviour responsible
- **AND** the budget is not raised without amending this specification
