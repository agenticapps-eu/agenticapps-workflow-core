# workflow-installation Specification

## Purpose
TBD - created by archiving change core-installer-one-entry-point. Update Purpose after archive.
## Requirements
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

**What follows from that, stated here because it belongs to the capability and
not to a security appendix: a checkout of this repository is live prompt code
for every bound host.** The symlink resolves through the working tree, so
whatever is checked out at load time is what the agents execute as their
instructions — which is the property that makes editing core reach every host
at once, and the same property that makes `gh pr checkout` of a branch touching
`skills/` arm every host on the machine with unreviewed instructions, before the
review, including the agent performing it. A branch carrying a skill change is
therefore reviewed by reading the diff. A machine that must do both SHALL bind
to a worktree pinned to the reviewed branch rather than to the one it reviews
from. This is a consequence to be stated and lived with, not a reason to copy;
copying trades it for the drift above, which is worse and permanent.

#### Scenario: A skill is bound into a host

- **WHEN** the installer binds a host whose skill directory is known
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

**One directory is recognised, and the exception SHALL be named here rather than
left in the code.** A directory occupying a name the legacy manifest lists is
this workflow's own copied skill, installed under a name only this workflow ever
used, and it is removed without acceptance for the same reason a symlink into an
unmaintained checkout is. Without this sentence the specification requires
acceptance for every directory and mandates the removal of that one, which is a
contradiction a reader has to resolve by guessing. The exception is bounded by
the manifest: a directory whose name the manifest does not list is someone's
work and needs acceptance, and widening the exception by inference is
prohibited. Removal under it is still preserved and reported like any other.

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
names it.

**"Known" means the four directories this installer binds, and one host reads a
fifth.** pi loads `~/.pi/agent/skills` as well as `~/.agents/skills`. The
installer neither binds nor sweeps the former, so a binding into an unmaintained
checkout placed there survives both the sweep and the negative test that exists
to catch exactly that. The bound scope is stated rather than left implied, and it
was measured before it was accepted: that directory holds 25 entries on this
machine, all of them relative symlinks into `~/.agents/skills`, none resolving
into an unmaintained checkout and none workflow-named. The gap is real and
currently empty. Widening the sweep to a directory the installer does not write
is a change of its own, because acting where you do not install is a different
promise. A check that consults the manifest to decide what to check cannot
detect the omission that matters, which is a name the manifest does not carry.

For an entry the manifest does not name, the installer SHALL rebind it to the
host-neutral equivalent where one is installed, and SHALL remove it where none
is. Reporting such an entry and leaving it is not sufficient: the operator
cannot act on a report of a binding they did not create and do not recognise,
and the binding breaks the moment the checkout is deleted either way. Both
outcomes SHALL be reported by name, together with the target replaced.

**The equivalence derivation SHALL be specified here rather than left to the
implementation.** The host-neutral candidate for a name is that name with a
leading host identifier removed and a trailing `-audit` removed.

**The host identifiers SHALL be enumerated, not described.** They are exactly
`codex-` and `opencode-`: the two archived host installers that vendored
host-prefixed copies. `claude-`, `pi-` and `omp-` are deliberately absent —
nothing ever installed under them — and the set SHALL NOT be widened by
inference from the host list. Three consequences follow and are accepted rather
than discovered later: a genuinely neutral skill whose own name begins `codex-`
would be mis-derived; an identifier appearing mid-name, as in
`update-opencode-agenticapps-workflow`, is not stripped and the entry falls
through to removal, which is the right outcome for that name and is not
guaranteed to be for every such name; and a host that starts vendoring under a
new prefix needs this list amended before its bindings can be swept. "A leading
host identifier" without this list is the load-bearing rule for eighteen
unconsented rebinds, resolved by whatever the implementation happened to code. A candidate
counts as installed only if a skill of exactly that name exists in a searched
skills directory **and is not itself a binding into an unmaintained checkout** —
one host's dead link is no better a target than another's, and rebinding to it
leaves a machine that looks converted while still resolving into a checkout
about to be deleted. If no such candidate exists, the entry SHALL be removed;
the derivation SHALL NOT be widened, retried, or fuzzy-matched to find one.

**What this derivation does not guarantee, stated plainly.** It is a name
transformation, not a capability comparison: `codex-impeccable-audit` derives
`impeccable`, and nothing mechanically establishes that the installed
`impeccable` does what the vendored audit copy did. Three reviewer rounds across
two vendors raised this, and the objection is correct on its own terms. It is
accepted rather than solved, on three bounds — the sweep only touches bindings
resolving into the four named unmaintained checkouts, so nothing independently
installed is in scope; every rebind is reported by name with both the previous
and the new target, so the guess is visible rather than silent; and the
alternative outcome for an entry with no derivable equivalent is removal, so the
derivation can only ever redirect a binding that was already about to break.

A reviewed explicit mapping would be stronger and is the right answer if a
mis-rebind is ever observed. It is not adopted now because the manifest already
owns every case needing judgement, and a table of 18 host-prefixed copies whose
own repositories are being deleted would be maintained exactly once.

#### Scenario: A legacy binding is present

- **WHEN** a host holds a binding under a legacy name the manifest lists
- **THEN** the installer replaces it with the current binding, or removes it
  when nothing current replaces it
- **AND** it reports which of the two it did, by name

#### Scenario: A derived candidate is itself an unmaintained binding

- **WHEN** the derived host-neutral name exists but is itself a binding
  resolving into an unmaintained checkout
- **THEN** it is not treated as an installed equivalent
- **AND** the entry is removed rather than rebound to it

#### Scenario: No equivalent can be derived

- **WHEN** the derivation yields a name that is not installed
- **THEN** the entry is removed and reported by name
- **AND** no wider or approximate match is attempted

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

#### Scenario: Nothing was requested that could not be done

- **WHEN** every step the operator asked for was performed
- **THEN** the run exits zero

### Requirement: The installer writes no host configuration

The installer SHALL NOT create or modify any file a host reads as
configuration. A host receives skill bindings, and nothing else.

The enforcement floor is git and CI, which every host shares. A per-host hook
was the only host-specific thing this installer did, and it was the weakest of
the three surfaces the gate fires at: with no active change the gate returns
satisfied, so the hook never enforced spec-before-code, and the condition it did
enforce is caught again at `git commit` and again in CI. It cost three
implementations, a JSON merge against a file other tools write to, an opt-in
flag, and a Tier 2 dependency.

Every host is therefore treated identically. There is deliberately no per-host
branch in the binding path: the moment one exists, the second is cheap.

#### Scenario: A host is bound

- **WHEN** the installer binds any host
- **THEN** that host's skills are bound by symlink
- **AND** no file that host reads as configuration is created or modified

#### Scenario: The removed opt-in is passed

- **WHEN** an operator or script passes the opt-in that formerly permitted a
  host configuration change
- **THEN** the run fails with an unknown-argument error naming it
- **AND** it is not accepted, ignored, or silently treated as a no-op

#### Scenario: Every host is bound the same way

- **WHEN** the installer binds two different hosts
- **THEN** neither is treated as a special case in the binding path

### Requirement: A host is detected by evidence that it is installed

Auto-detection SHALL test for evidence that a host is actually installed — its
executable, or state only that host writes — and SHALL NOT infer a host from the
presence of a directory alone.

A directory can exist for unrelated reasons, and one skill directory in this
layout is shared by two hosts and by unrelated tools, so its presence identifies
no host at all. Binding a host that is not installed creates symlinks nobody
resolves and reports an install that did not happen.

**Detection answers whether to bind; it does not answer where.** Binding a
detected host SHALL use the skill directory established for it by the requirement
above. An earlier revision specified only detection, and the shared-directory
reasoning here proved sharper than the mapping it governed: `~/.agents/skills` is
shared by pi and omp, and the spec noted the sharing without ever asking whether
either host reads it. pi does not. It reads `~/.pi/agent/skills`, a real directory
of per-skill symlinks core did not populate, and core's skill is absent from it —
so pi has been detected correctly and bound nowhere useful for as long as the
mapping has existed.

For omp the same directory is **correct, and established from omp's own
implementation**, which names both `~/.omp/agent/skills` and `.agents/skills`
(user home) as directories it loads. So the two hosts shared one mapping and only
pi was wrong about it.

The route to that conclusion is the part worth keeping. omp was first recorded
unverified because no `~/.omp/agent/skills` directory existed to find — absence of
a directory taken as absence of evidence. A host that ships its own loader is
evidence about itself, and it outranks anything inferred from the filesystem.
Where a host is recorded unverified, that SHALL mean its implementation was
consulted and settled nothing, not merely that no directory was found.

#### Scenario: A directory exists but the host does not

- **WHEN** a host's directory exists and that host is not installed
- **THEN** auto-detection does not report that host as present and does not bind it

#### Scenario: A skill directory is shared by more than one host

- **WHEN** a skill directory serves more than one host
- **THEN** the binding is reported once, as a shared binding, naming the hosts
  that read it
- **AND** it is not reported as evidence that any particular one is installed
- **AND** each named host's reading of that directory SHALL be established by
  evidence, because a shared directory is shared by assumption until it is not

#### Scenario: A detected host has an unverified skill directory

- **WHEN** a host is detected and no evidence establishes where it reads skills
- **THEN** the installer SHALL report the binding as unconfirmed and SHALL NOT
  count it toward a successful install

### Requirement: The check mode reports state and changes nothing

The installer SHALL provide a check mode reporting, for each declared artifact
and binding: whether it is present, which version it holds, and whether it is
current with respect to the checkout. For each host it SHALL report whether
skills are bound.

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
produce the same machine state as the first and SHALL NOT duplicate a symlink or
a hook entry.

> This requirement also forbade duplicating "a configuration block" and required
> semantic rather than textual duplicate detection, because a configuration file
> rewritten by a serialiser does not come back byte-identical. **The installer
> writes no configuration file**, so there is no serialiser and no block: those
> were testable `SHALL`s naming objects that stopped existing when the wiring was
> removed. Struck at round seven rather than left as text a conformance run could
> be written against.

#### Scenario: The installer runs twice

- **WHEN** the installer is run twice with identical arguments
- **THEN** the second run reports no new bindings created
- **AND** the machine state after the second run is identical to the state after
  the first

### Requirement: What the installer replaces with its own hands is recoverable

Before replacing or removing a binding whose content is not recoverable from the
report — a directory or a regular file — the installer SHALL preserve what it is
about to destroy at a reported path, and SHALL state how to restore it. A symlink
binding is the stated exception and is covered below. Host configuration files
were named here too and are struck at round seven: the installer writes none, so
the clause described an act that can no longer occur, which is dead text read as
a live guarantee. Preserved copies SHALL NOT overwrite one another,
SHALL carry the permissions of what they preserve, and a preservation that fails
SHALL abort that step rather than proceed unprotected.

A rollback plan that names no artifact is not a rollback plan. The version log
records that a downgrade happened; it does not hold the bytes needed to undo one.

A preserved copy taken from a host's skill directory SHALL be written outside
every host's skill directory. A preserved skill is still a skill: at least one
host loader discovers a `SKILL.md` nested below the directory it scans, so a
backup left in place re-registers under the name it was preserved from. The
installer would then delete one copy of a duplicated skill and create another
beside it — passing its own archived-binding scan, because the survivor is a
copy rather than a symlink, and reinstating the duplicate-trigger-skill
condition this change exists to end. Host configuration files are exempt: their
loaders match exact names, so an adjacent copy is inert and is the more obvious
restore.

**For a symlink binding the preservation is the reported target, and the
specification SHALL say so rather than leave the reader to infer it.** A symlink
has no content beyond the path it names, so copying it produces a second link
into the same checkout — and in the archived-binding sweep that checkout is the
one about to be deleted. The copy is dead on arrival. What restores a symlink is
its previous target, which the sweep SHALL report for every entry it rebinds or
removes, and which is sufficient to recreate it exactly. Copying is therefore
required for a directory or a regular file, where bytes would otherwise be lost,
and reporting is the whole of it for a symlink.

This was not stated, and the gap was real rather than cosmetic: the requirement
read as "every replaced or removed binding is preserved", the real run changed
26 symlink bindings and wrote one preserved directory, and nothing in the
specification explained why that was not a violation. A reviewer reading only
the requirement was right to call it one.

This guarantee does **not** extend to published artifacts, and SHALL NOT be
claimed for them. Publishing happens inside a delegated installer that holds a
lock across its own read-compare-write, so a copy taken before delegating can be
superseded before that lock is acquired — a backup that is only valid when
nothing else is running does not protect the case it exists for. For published
artifacts the protection is the arbitration itself: refusal to downgrade, and an
explicit opt-in with a stated reason for an operator who means it.

#### Scenario: A binding whose content the report cannot carry is replaced

- **WHEN** the installer replaces an existing binding that is a directory or a
  regular file
- **THEN** the previous content is preserved at a path the run reports
- **AND** the summary states the command that restores it

#### Scenario: A skill binding is preserved

- **WHEN** the installer preserves something it is removing from a host's skill
  directory
- **THEN** the preserved copy is written outside every host's skill directory
- **AND** no file or directory matching the preserved-copy naming remains in the
  skill directory the original was taken from

#### Scenario: A symlink binding is rebound or removed by the sweep

- **WHEN** the installer rebinds or removes a symlink binding into an
  unmaintained checkout
- **THEN** the previous target is reported by name alongside the outcome
- **AND** no copy of the link is written, because a copy would resolve into the
  same checkout and restoring from the reported target is exact

#### Scenario: A second run replaces the same target

- **WHEN** the installer replaces a target it has already preserved a copy of
- **THEN** the earlier preserved copy is left intact and the new one is written
  beside it

#### Scenario: A copy cannot be preserved

- **WHEN** the installer cannot write the preserved copy
- **THEN** it does not perform the replacement
- **AND** the step is reported as skipped

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
> hook and the foreign-binding refusal live in the binder and the gate, which
> carry no budget.
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

### Requirement: A host's skill directory is established by evidence, not assumed

The installer SHALL bind a host's skills into the directory that host actually
reads. That directory SHALL be established by evidence — the host's documented
skill path, an observed load, or **the host's own implementation** — and the
evidence SHALL be recorded alongside the mapping.

The third source is named because it settled a case the first two did not: omp
documents nothing useful and had no directory to observe, while its shipped code
names the paths it loads outright. A host is the authority on what a host reads.

Where no such evidence is available, the host SHALL be recorded as **unverified**
and its mapping SHALL NOT be asserted as correct.

This capability already requires a host to be *detected* by evidence that it is
installed. It never required the same of the *path*, and the gap is not
theoretical: pi has been bound to a directory it does not read for as long as the
mapping has existed, and nothing failed, because binding into the wrong directory
succeeds. A skill that is not there does not error — it is merely absent, and
absence is what nobody notices.

#### Scenario: A host's skill directory is known from its documentation

- **WHEN** a host documents the directory it loads skills from
- **THEN** the installer SHALL bind into that directory, and the mapping SHALL
  record the source

#### Scenario: A host is bound into a directory it does not read

- **WHEN** the installer binds a host into a directory the host does not load from
- **THEN** this SHALL be treated as a defect, not as a partial success, because
  the install reports success while the host resolves nothing

#### Scenario: No evidence establishes a host's skill directory

- **WHEN** a host is installed but neither documents a skill path nor exposes one
  to observe
- **THEN** the host SHALL be recorded as unverified, and the installer SHALL
  report that its binding is unconfirmed rather than reporting success

#### Scenario: A host's binding is confirmed by resolution

- **WHEN** a binding is claimed correct
- **THEN** it SHALL be confirmed by the host resolving the skill, not by the
  symlink existing — the symlink existing is what was already true for pi

#### Scenario: A corrected mapping has not yet been confirmed by resolution

- **WHEN** a mapping is corrected on the strength of a directory's contents, and
  no observation of the host resolving the skill has been made
- **THEN** the host SHALL be recorded as **corrected but unconfirmed**, not as
  fixed
- **AND** this applies to pi: `~/.pi/agent/skills` holding per-skill symlinks is
  the presence of a directory, which this very requirement refuses as evidence.
  Claiming pi fixed on that basis would apply to pi the standard this change was
  written to stop applying to omp

#### Scenario: A bound directory is shared with an unrelated tool

- **WHEN** the installer binds into a directory another tool populates, and a
  name it would write is already present
- **THEN** it SHALL NOT overwrite the other tool's entry, and SHALL report the
  collision naming both
- **AND** the co-tenancy SHALL be reported by the check mode thereafter, because
  the other tool can remove core's links on its own sweep and nothing else would
  notice

### Requirement: The openspec tooling is bound machine-level, not written per repository

The installer SHALL bind the `openspec` CLI's skill and command files into each
detected host's machine-level directories, and the project initializer SHALL
invoke `openspec init --tools none` so that no repository receives them.

`openspec init --tools <host>` is a per-project agent installer: it writes six
skills, and for most hosts a set of command files, into the repository. That is
behaviour in a repository, which is a *version* of behaviour, which is the drift
this workflow exists to remove. Binding it once per machine gives every
repository the same commands — including repositories that were never
initialized.

**The shape differs per host and SHALL NOT be inferred from another host.**
Measured 2026-08-07: the skills are uniform, six per host at
`<host>/skills/openspec-*/SKILL.md`. The command surface is not — claude uses a
nested `commands/opsx/` directory, opencode a flat `commands/opsx-*.md`, pi
`prompts/opsx-*.md`, and codex has no command surface at all. A single binding
pattern applied five times would put files where three hosts do not read them,
which is the defect this capability's evidence requirement already names.

The files SHALL be generated by the CLI rather than hand-copied, because only the
CLI knows their content, and SHALL be bound by symlink rather than copied, for
the same reason every other skill in this workflow is.

#### Scenario: A host is bound

- **WHEN** the installer binds a detected host
- **THEN** the openspec skills and that host's command files are bound into its
  machine-level directories
- **AND** `/opsx:*` resolves in a repository that carries no host directory at all

#### Scenario: A host's command surface has nothing to bind

- **WHEN** the CLI generates no command files for a detected host — as it does
  not for codex, whose `~/.codex/prompts` exists and is populated by other tools
- **THEN** its skills are bound and the empty command surface is recorded
- **AND** this SHALL NOT be reported as a partial or failed install, because the
  absence is on the generator's side rather than the host's

#### Scenario: A host has no bindable command directory at all

- **WHEN** a host exposes no global command or prompt directory — as pi does not,
  installing extensions as packages instead
- **THEN** its command surface SHALL be recorded **unverified**, and no directory
  SHALL be created to bind into
- **AND** a directory SHALL NOT be inferred from that host's *project-level*
  layout, because pi writing `.pi/prompts/` inside a repository is not evidence
  that pi reads `~/.pi/agent/prompts` outside one — that inference is the defect
  this capability's evidence requirement exists to prevent

#### Scenario: A command directory is assumed rather than established

- **WHEN** a host's machine-level command directory is chosen by symmetry with
  another host's
- **THEN** this is a defect, because the per-project shapes already differ across
  all four hosts measured

#### Scenario: A repository is initialized

- **WHEN** the project initializer creates `openspec/`
- **THEN** it SHALL pass `--tools none`, so the repository receives no skill,
  command, or prompt file

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

The cost is named rather than mitigated: an unenrolled repository that ought to
be governed is silently ungated, and nothing here reports it. A predicate whose
failures are invisible is a drifting list under another name, so a reporting
surface is owed — it is specified separately, because specifying it here would
describe a mode this change does not build.

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
- **AND** the intermediate state is published-but-unbound, which is a state the
  machine can be left in and a reader must be able to tell apart from bound

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
`~/.agenticapps/git-hooks/hooks.d/`. Anything verifying that `core.hooksPath`
"resolves to the published directory" needs those names to be normative, and
they are unverifiable while the directory is named only in prose.

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
  ignored. A hook that cannot run and says nothing is the failure this whole
  capability exists to remove, and it applies to the dispatcher's own execute
  bit as much as to an entry's.
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

#### Scenario: The gate override is not an absolute path

- **WHEN** `OPENSPEC_GATE` or `OPENSPEC_CHANGE_GATE` is set to a value that is
  not an absolute path
- **THEN** `--check` reports that it cannot speak for what actually runs, because
  the dispatcher resolves the override from each repository's hook directory and
  a value with no slash goes through `PATH`
- **AND** SHALL NOT report the gate as present or absent on the strength of
  resolving it from the directory the check was run in

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

