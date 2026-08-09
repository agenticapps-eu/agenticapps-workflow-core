## ADDED Requirements

### Requirement: The workflow binds no host-specific hook surface

The workflow SHALL NOT bind a hook through a surface only one host reads.
`.claude/settings.json` is such a surface — Claude reads it, and Codex, opencode,
pi and omp read nothing from it — and this holds wherever the file sits, in
`$HOME` or in a repository. The enforcement floor SHALL be the machine-level git
hook, which fires for every host and for a person with an editor.

The host hook was deleted for three stated reasons: with no active change the
gate returns satisfied, so it never enforced spec-before-code; the condition it
did enforce is caught again at `git commit` and in CI; and it was every
host-specific line in the repository. **All three apply unchanged to the same
file inside a repository.** The surface was closed at `$HOME` and left open in
nine checkouts, and nothing recorded a reason for the distinction because there
is not one — the change simply did not reach that far.

The measurement that settles it: in `cparx` on 2026-08-07 there was no
`.git/hooks/pre-commit`, `core.hooksPath` was unset globally and locally, and the
only invoker of the gate shim was a `PreToolUse` entry. The gate fired at neither
of the two surfaces its own documentation claims. A Claude-only hook that returns
satisfied whenever no change is active was the whole of that repository's
enforcement.

A hook whose protection is genuinely pre-tool rather than pre-commit is not
excluded by this requirement — it is required to argue that, in the change that
keeps it, and to say what it protects that commit-time enforcement cannot.
**Making that argument successfully is necessary and not sufficient**: a
protection that reaches one host of five is not a floor, and the surface is not
closed while a single hook holds it open.

`database-sentinel` is the worked case and it is decided: **removed.** Its
destructive-SQL arms do make the pre-tool argument, and make it correctly —
`DROP TABLE` never enters git, so no commit-time or CI surface can see it, and
they are the only interception of an irreversible action in this workflow. It is
removed regardless, because it protects Claude sessions only.

**The protection is not reassigned, and this paragraph used to say it was.** The
earlier text sent it to "the host's own permission layer, which is the
operator's configuration and not core's to ship" — which reads as a handover and
is not one. Task 3.9d put the question directly and the answer, measured on
2026-08-08, is that no such rule is expressible: the hook matched *content* —
`DROP TABLE`, `TRUNCATE TABLE`, `DELETE` with no `WHERE`, case-insensitively,
anywhere in a Bash command — and host permission rules match a command *prefix*.
The nearest expressible rule denies `psql` outright, blocks every legitimate use,
and would be switched off within a day. So the hook was removed from five
repositories on 2026-08-08 and **nothing replaced it**. Commands that drop or
truncate tables are no longer intercepted before they run, on any host, in any
repository. That is the recorded end state, not an interim one.

#### Scenario: A hook is bound through a single-host surface

- **WHEN** the workflow would register a hook in a configuration file only one
  host reads
- **THEN** it does not
- **AND** the enforcement is placed at the machine-level git hook instead

#### Scenario: A hook claims a pre-tool protection

- **WHEN** a hook is proposed for retention on a host-specific surface
- **THEN** the change states what it protects that commit-time enforcement
  cannot
- **AND** a hook with no such statement is removed with the surface

#### Scenario: The pre-tool argument succeeds and the hook is still removed

- **WHEN** a hook's protection genuinely cannot be provided at commit time, and
  the surface carrying it reaches only one of the provisioned hosts
- **THEN** the hook is removed with the surface
- **AND** the change names what is lost
- **AND** the change names where the protection is reassigned, or records it as
  unmitigated when no reassignment is expressible
- **AND** the change SHALL NOT describe the protection as preserved
- **AND** the change SHALL NOT describe it as reassigned to a surface that
  cannot express it

### Requirement: No project binds any fleet hook once the surface is closed

After this change `SHIMMED-HOOKS` names no hook, and a project SHALL bind none.

The declaration held exactly two entries. `database-sentinel` is removed with
the host-specific surface, and `openspec-change-gate`'s project binding is
replaced by the machine-level git hook, so the set is empty rather than
shortened. That is a stronger and simpler rule than the one it replaces: the
reverse pass no longer asks whether a held hook appears in a declaration, it
asks whether any fleet hook is held at all.

**An empty declaration is not the same as an absent one, and the current
implementation cannot tell them apart.** `check-shims.sh:34` reads the
declaration with `sed 's/#.*//' "$1" 2>/dev/null | awk 'NF'` — the `2>/dev/null`
means a **missing file** yields exactly what an **empty file** yields, verified
by running it against both. With zero declared hooks the forward pass's inner
loop never executes, `bad` stays `0`, and line 91 prints *"Every declared hook
is bound with the authority's bytes"* and exits 0.

That is a vacuous truth published as a conformance statement, and it is the
exact failure this capability exists to prevent — a check reporting a clean
fleet while nothing was examined. This change **creates** that condition, so it
carries the fix:

- A declaration file that is absent SHALL be reported as an error, distinctly
  from one that is present and empty.
- A forward pass over an empty declaration SHALL report that it checked nothing,
  and SHALL NOT emit the conformance sentence.
- With the forward pass vacuous, the success message SHALL describe what was
  actually verified — which after this change is the reverse pass alone.

**The reverse pass needs a fleet-vs-project discriminator, and membership can no
longer supply it.** With the declaration empty, "is this hook declared" is
useless as a test, and a repository's own unrelated `PostToolUse` entry would
be reported as a defect. A hook is **fleet-shared** if its shim resolves an
implementation under `~/.agenticapps/bin/`, and that is the criterion. A hook a
project wrote and owns resolves nothing there and is not this capability's
business.

**A retired hook needs a durable name, not an inference.** Once
`normalize-claude-md` leaves the declaration, nothing distinguishes a stale
binding of it from a project-authored hook that happens to share the shape. The
declaration SHALL therefore carry retired names as **tombstones** — recorded,
not silently dropped — so that "declared", "retired" and "never ours" are three
states rather than two. Shrinking a declaration to nothing and inferring the
difference is the same shrinkage defect `ARTIFACTS` was written to prevent.

This does **not** remove the need for a sanctioned-transition mechanism, and an
earlier revision claimed it did. `OPT-OUTS` records a *missing* binding as
intended and has no axis for an *extra* one — and because retiring a hook in
core and unbinding it across nine repositories cannot be atomic, there is an
interim in which extras exist deliberately. That interim needs sanctioning
whether or not the end state is empty.

#### Scenario: A project holds no fleet hook

- **WHEN** both passes run against a repository carrying no fleet hook shim and
  no host configuration entry for one
- **THEN** it is reported conformant

#### Scenario: The declaration is empty

- **WHEN** the forward pass runs against an empty declaration
- **THEN** it reports that no hook was declared and therefore none was checked
- **AND** it SHALL NOT report that every declared hook is bound

#### Scenario: The declaration file is absent

- **WHEN** the declaration file does not exist
- **THEN** the check reports it as an error and exits non-zero
- **AND** the condition is distinguishable from an empty declaration

#### Scenario: A project holds a hook of its own

- **WHEN** a repository binds a hook whose implementation does not resolve under
  `~/.agenticapps/bin/`
- **THEN** it is not reported
- **AND** the reverse pass SHALL NOT treat an unrecognised hook as a fleet hook

#### Scenario: A project still holds a retired fleet hook

- **WHEN** a repository binds a hook recorded as a tombstone in the declaration
- **THEN** it is reported as a retired binding, distinctly from an undeclared one
- **AND** the check exits non-zero

#### Scenario: A project still holds a fleet hook

- **WHEN** a repository holds a shim or a host configuration entry for any fleet
  hook
- **THEN** the condition is reported, naming the repository and the hook
- **AND** the check exits non-zero
- **AND** no opt-out sanctions it

### Requirement: A project binds no hook the declaration does not name

A project SHALL NOT bind, in its host configuration or its project hook
directory, a fleet-shared hook that `SHIMMED-HOOKS` does not name. Retiring a
hook from the declaration SHALL be accompanied by removing the binding from every
repository that holds one, and the two SHALL NOT be separated across releases.

**The declaration detects a missing member and is blind to an extra one, and that
asymmetry is the whole of this requirement.** `ARTIFACTS`, `FLEET` and
`SHIMMED-HOOKS` exist because "an expected set discovered from the artifacts
cannot detect a missing artifact" — every one of them is checked by iterating the
declaration and asking whether the machine satisfies it. Nothing walks the other
direction and asks what the machine holds that the declaration does not.

The consequence is not hypothetical. `normalize-claude-md` is bound by six fleet
repositories — `agenticapps-dashboard`, `agenticapps-roadmap`, `callbot`,
`cparx`, `fbc-platform` and `fx-signal-agent`, measured 2026-08-07.
`agents-task-viewer` does **not** bind it, which is why it is the clean
reference — and the change retiring it removes it from `ARTIFACTS` and
`SHIMMED-HOOKS` in core while leaving all six bindings in place. Because
`install-project-hooks.sh` carries forward manifest rows outside the declared set
by design, the implementation stays on disk and the hook keeps running: a retired
hook rewriting `CLAUDE.md` on every edit in seven repositories, published by
nothing, attested by nothing, and reported by nothing. The conformance run that
inspected those same repositories the day before said "every declared hook is
bound with the authority's bytes", which was true and complete and did not
mention it.

A retirement that leaves the binding is not a retirement. It converts a shared
hook into an unmanaged one, which is strictly worse than the hook it replaced.

#### Scenario: A project binds a hook the declaration does not name

- **WHEN** a project holds a shim, or a host configuration entry, for a
  fleet-shared hook absent from `SHIMMED-HOOKS`
- **THEN** the condition is reported, naming the repository and the hook
- **AND** the check exits non-zero

#### Scenario: A hook is retired from the declaration

- **WHEN** a hook name is removed from `SHIMMED-HOOKS`
- **THEN** no repository retains a shim or a configuration entry for it
- **AND** the retirement and the removals are not separated across releases

#### Scenario: A project binds a hook that is declared

- **WHEN** a project holds a shim for a hook `SHIMMED-HOOKS` names
- **THEN** it is checked for the authority's bytes as it is today
- **AND** it is not reported as undeclared

### Requirement: The conformance check walks both directions

The fleet check SHALL make two passes over each declared repository: one that
iterates the declaration and asks whether the repository satisfies it, and one
that iterates what the repository holds and asks whether the declaration names
it. A pass that runs only the first SHALL NOT be described as reporting a
repository's conformance.

One pass answers "is anything missing". The other answers "is anything extra".
They are different questions, they fail in different directions, and a check that
answers only the first will report a clean fleet while a retired hook executes in
seven of its members.

#### Scenario: A repository holds only declared hooks

- **WHEN** both passes run against a repository whose hooks are exactly the
  declared set
- **THEN** it is reported conformant

#### Scenario: A repository holds a declared hook and an undeclared one

- **WHEN** both passes run against such a repository
- **THEN** the declared hook is reported bound and the undeclared one is reported
  as undeclared
- **AND** one clean pass does not suppress the other's finding

## MODIFIED Requirements

### Requirement: A hook implementation is authoritative in one place

A **fleet-shared** workflow hook's behaviour SHALL be defined in exactly one
authoritative file. A project SHALL NOT carry a copy of that behaviour.

A shim resolves the authoritative file through an ordered lookup, and that
lookup naming several candidate locations does not make several
implementations: at most one is authoritative on a given machine, and the order
decides which.

**Maintained source and executed copy are distinct.** The tracked file in core
is what maintainers edit; the copy under the shared install directory is what
runs. Where an implementation is published, the publishing installer SHALL write
it to a temporary path in the destination directory and `rename` it into place,
so no reader observes a partial file, and SHALL hold a lock that does not
outlive its holder for the duration of its critical section.

**Everything this requirement used to say about a manifest is removed, because
the only code that wrote one is deleted by this change.** The removed apparatus
was a `sha256` row per published artifact in a manifest beside the shared
install directory, an implementation version marker the manifest row carried, a
whole-manifest atomic rewrite, an ordering rule placing the artifact before its
row, and the crash-recovery behaviour that followed from that ordering. All of
it was satisfied by `install-project-hooks.sh` and by nothing else:
`install-shared-artifact.sh`, which survives and publishes the gate, the
reviewer CLI, the plan reviewer and the initializer, writes no manifest and
computes no digest. Retaining the requirement would leave this capability
demanding provenance that no surviving installer produces.

**The manifest it described had one reader, and that reader was its own test.**
Measured 2026-08-08: `~/.agenticapps/manifest.tsv` was consulted by
`tools/install.test.sh` and by no production code path. Its rows were carried
forward for artifacts a run did not touch and never expired, so the file
attested `normalize-claude-md.sh 1.0.1` — with a digest — for a path that held no
file. A drift instrument with no reader, whose only surviving claim was false, is
not provenance.

**The lock's named primitive goes with it, and the deviation is resolved rather
than left standing.** The removed text required `flock` on a lockfile and
excluded a create-and-check lock by name. Neither installer ever implemented it:
`flock(1)` does not ship on macOS, which is this fleet's only platform, so both
use an atomic `mkdir` plus the owning pid and break a lock whose owner is gone.
That deviation was recorded in both files rather than taken silently, and the
property it protects — a lock that does not outlive its holder — is what this
requirement now states, in place of a primitive the platform does not have.

#### Scenario: A hook's behaviour is changed

- **WHEN** a fleet-shared hook's behaviour is edited
- **THEN** it is edited in the one authoritative file
- **AND** no project carries a second copy of that behaviour to edit

#### Scenario: The executed copy has drifted from the maintained source

- **WHEN** the copy under the shared install directory differs from the tracked
  file in core
- **THEN** the difference is reported against the maintained source, which is
  the only remaining authority for what the executed copy should be

#### Scenario: Publication is interrupted partway

- **WHEN** a publishing run is killed after writing a temporary file and before
  the rename
- **THEN** no reader observes a partial implementation
- **AND** the lock it held is broken by the next run rather than waited on

### Requirement: The scaffolder's templates carry the current shape

A change to the fleet's hook set SHALL update the scaffolder's project templates
and setup snapshot in the same change. A scaffolder that provisions the previous
shape re-creates whatever the change removed, in every project created after it.

A scaffolder may vendor the hook set in more than one place — project templates
and a setup snapshot are distinct copies — together with the matcher
configuration in its settings snapshot. Deleting a hook from every existing
project while leaving it in either means the next project is born with it.

**The scaffolder now provisions no hook and no shim, and this requirement is
restated to say so.** Its previous scenario required a newly scaffolded project
to receive "the shims, the current matchers, and none of the deleted hooks",
which describes a fleet that no longer exists: `SHIMMED-HOOKS` names nothing, so
there are no shims to receive, and the matcher configuration lived in the
host-specific settings file this change closes. `init-project.sh` writes
`openspec/`, one instruction file, and the local enrolment key — and a
conforming scaffolder SHALL write no hook, no shim and no host settings file.

#### Scenario: A hook is deleted fleet-wide

- **WHEN** a hook is removed from every project that carries it
- **THEN** it is removed from the scaffolder's templates and snapshot in the
  same change, so a newly scaffolded project does not receive it

#### Scenario: A project is scaffolded after the change

- **WHEN** the scaffolder provisions a new project
- **THEN** that project receives no hook, no shim and no host settings file
- **AND** its enforcement comes from the machine-level git hook, which it
  reaches by being enrolled rather than by carrying anything

## REMOVED Requirements

### Requirement: A machine's provisioning is a triple, not a state name

**Reason**: The triple was (installer run, artifacts published, shims bound).
This change deletes the publisher, and `SHIMMED-HOOKS` names no hook to bind, so
two of the three terms have no referent and the third is not a triple. The
instrument that read the triple, `provisioning-check.sh`, was deleted on
2026-08-05 together with its suite, nothing else having called either — so the
requirement has had no implementation for four days and no consumer for longer.

**Migration**: None. What a machine now needs is `core.hooksPath` bound and each
repository enrolled, which `one-enforcement-floor` specifies and
`install.sh --check` reports.

### Requirement: Currency is judged against an authority checkout

**Reason**: Every scenario in it — the installed build older than the
authority's, the authority unreachable, versions agreeing while bytes differ,
the authority holding no such artifact, the machine ahead of the authority — is
about comparing a **published project-hook implementation** against core. With
`ARTIFACTS` empty there is no such implementation to compare. The surviving
installer publishes the gate, the reviewer CLI, the plan reviewer and the
initializer, and their currency is judged by the version-marker arbitration in
`install-shared-artifact.sh` and reported by `install.sh --check`, which is a
different mechanism this requirement never described.

**Migration**: None for any consumer. `install.sh --check` continues to report
each shared artifact as current or not, naming the checkout's version — the
behaviour an operator actually used this requirement for.

### Requirement: Provisioning is checked per machine, not only per repository

**Reason**: It requires a per-machine provisioning check, which was
`provisioning-check.sh`, deleted 2026-08-05. Its two scenarios are about a
machine pulling a shim without running the installer, and about rollout ordering
being offered as fleet-wide assurance. Neither has a subject once no shim is
pulled and no project-hook artifact is installed.

**Migration**: None. The per-machine question that remains — is the floor bound
and is this repository enrolled — is answered by the machine-level git hook,
which fails loudly at commit time in an unenrolled repository rather than
requiring a check to notice.

### Requirement: The implementation version marker is compared, not merely carried

**Reason**: It requires a check to compare a published implementation's
`# <hook>-version:` marker against the authority's and to refrain from fixing
what it found. The only markers it governed were on project-hook
implementations, and `database-sentinel.sh` is the last of them. The identically
named rule for shared artifacts lives in `workflow-installation` and is
unaffected.

**Migration**: None. `install-shared-artifact.sh` still refuses to overwrite a
published copy carrying a higher version, for the artifacts it publishes.

### Requirement: A shared hook's protections are described as what they are

**Reason**: Its single scenario is an operator relying on a shared hook's
protections, and it exists to stop those protections being described as broader
than they are. `database-sentinel` was the only hook with protections to
describe. The rule's substance is not lost — it is restated, sharper, in this
change's ADDED requirement "The workflow binds no host-specific hook surface",
which forbids describing a removed protection as preserved *or* as reassigned to
a surface that cannot express it.

**Migration**: None. The obligation moved rather than disappeared.

### Requirement: Reconciling divergent copies selects semantics deliberately

**Reason**: It governs reconciling variants of one hook across projects —
variants differing in matched paths, in handled tools, one broader by mistake,
one deliberately inert. It was written for the four divergent copies of
`database-sentinel` found across the fleet. There is now one copy of no hook, so
there is nothing to reconcile and no semantics to select.

**Migration**: None. Should a fleet-shared hook ever return, this requirement is
recoverable from the archive of this change; it is removed because it has no
subject, not because its reasoning was wrong.

### Requirement: A canonical implementation carries no unreachable gate

**Reason**: Both scenarios are about the canonical copy of a shared
implementation — a dead sentinel check inside it, and a protection genuinely
broader in one variant. The canonical copy this described is
`database-sentinel.sh`, deleted by this change.

**Migration**: None.

### Requirement: Registration matches the implementation's tool coverage

**Reason**: It governs the agreement between a hook implementation's tool
coverage and its registration in a host's settings file — matchers narrower or
wider than declared coverage, a declared hook registered nowhere, a tool that no
longer exists on the host. The registration surface it describes is
`.claude/settings.json`, which this change closes in every repository, and the
implementation it describes is the one being deleted. Both sides of the
agreement are gone.

**Migration**: None. This change's ADDED requirement "The workflow binds no
host-specific hook surface" forbids the surface outright, which is a stronger
statement than requiring a registration on it to be accurate.
