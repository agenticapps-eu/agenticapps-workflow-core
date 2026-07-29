## ADDED Requirements

### Requirement: This capability governs fleet-shared hooks only

These requirements apply to a workflow hook that more than one project binds. A
hook that exists in exactly one project is a host-specific extension hook, which
§02 permits, and it SHALL NOT be required to be a shim.

A project-local hook has nothing to drift against, and no shared implementation
to be authoritative elsewhere. Requiring every hook to be a shim would prohibit
what §02 explicitly allows.

#### Scenario: A project carries a hook no other project has

- **WHEN** a project defines a hook specific to its own stack or workflow
- **THEN** it MAY implement that hook in the project, and this capability's
  shim, resolution and authority requirements do not apply to it

#### Scenario: A project-local hook is adopted by a second project

- **WHEN** a hook that existed in one project is copied to another
- **THEN** it becomes fleet-shared, and these requirements apply from that point

### Requirement: A hook implementation is authoritative in one place

A **fleet-shared** workflow hook's behaviour SHALL be defined in exactly one
authoritative file. A project SHALL NOT carry a copy of that behaviour.

A shim resolves the authoritative file through an ordered lookup, and that
lookup naming several candidate locations does not make several
implementations: at most one is authoritative on a given machine, and the order
decides which.

**Maintained source and executed copy are distinct, and the link between them
SHALL be checkable.** The tracked file in core is what maintainers edit; the
copy under the shared install directory is what runs. Verifying only that the
executed copy is present and executable accepts one that is stale, hand-edited
or tampered with. The installer SHALL therefore record enough provenance — the
version marker and a content digest of what it published — for a later check to
establish that the executed copy is the maintained one.

**Publication of several implementations SHALL be atomic**, or ordered so that
no intermediate state leaves a project binding a hook whose implementation is
absent. Publishing one artifact per invocation with no grouping is how a
partially provisioned machine arises.

This is the rule the current fleet violates: two hook implementations copied
into seven projects produced three distinct versions of
`normalize-claude-md.sh` and of `database-sentinel.sh`.

#### Scenario: A hook's behaviour is changed

- **WHEN** a maintainer changes what a hook does
- **THEN** exactly one file is edited, and the change is live in every project
  on that machine once republished, without any per-project edit or migration

#### Scenario: Two projects are compared

- **WHEN** the same hook is compared byte-for-byte across any two projects that
  bind it
- **THEN** the two files are identical, because both are shims naming the same
  implementation

#### Scenario: The executed copy has drifted from the maintained source

- **WHEN** the copy in the shared install directory no longer matches what the
  installer published
- **THEN** the check reports it, rather than reporting the hook as installed
  because a file of that name exists and is executable

### Requirement: The shim contract itself has a propagation path

A shim is duplicated across every project that binds the hook, so a change to
the **shim contract** — resolution order, exit behaviour, identification — is a
change to N files, not one. Such a change SHALL name the projects it must reach
and SHALL be verified per project.

The one-authoritative-place rule covers implementations, not shims: shims are
deliberately copies, which is what makes them cheap and what makes a contract
change a fleet-wide edit. This change is itself an instance — it edits the
change-gate shim in seven repositories.

A shim SHALL carry a version marker for the contract it implements, so a project
running an older shim is detectable rather than discovered when it behaves
differently from its siblings.

#### Scenario: The shim contract changes

- **WHEN** the resolution order or exit behaviour required of shims is revised
- **THEN** every project binding an affected hook is enumerated and updated, and
  each is verified rather than assumed to have been reached

### Requirement: A project binds a hook through a shim

A project SHALL bind a hook by shipping a shim that locates and `exec`s the
authoritative implementation. The shim SHALL contain no behaviour of its own
beyond resolution, host self-identification, and `exec`.

The shim SHALL resolve in this order:

1. An explicit environment override, when set
2. `~/.agenticapps/bin/<hook>.sh` — the shared install

There is no third candidate. An earlier draft named `<repo>/bin/<hook>.sh`, and
that entry has no coherent reading: if `<repo>` is the product repository, the
fallback is the in-project copy this capability forbids two requirements above;
if it is the scaffolder's own checkout, a shim running inside a product repo has
no defined way to locate it. Either way the entry contradicted something, so it
is removed rather than clarified.

**The override is specified, not merely permitted:**

- Its variable name SHALL be per-hook and documented with the hook, so a project
  reading the shim can tell which variable governs it.
- It SHALL be honoured only when it names an **existing executable regular
  file**. When it is set but does not, the shim SHALL **report that specifically
  and allow the tool call**, exiting with the same non-blocking error code as an
  unresolvable shim. It SHALL NOT fall through to the shared install — a typo'd
  override that quietly runs a different implementation is worse than one that
  fails — and it SHALL NOT block, for the same matcher-breadth reason.

  A reviewer noted the previous wording forbade falling through without saying
  what happened instead, leaving two readings: allow silently, or block
  everything. Both are outcomes this capability rejects elsewhere; the third
  state is named here.
- It exists for **testing and staged rollout**. It is not a supported production
  configuration, and a machine relying on it has two implementations in play.

This does not weaken "authoritative in one place". That requirement is about
what is *tracked and maintained* — one file that maintainers edit — not about
what a test harness may substitute at runtime. A reviewer read the two as
conflicting, which they will be unless the distinction is stated.

#### Scenario: The override names a missing or non-executable file

- **WHEN** a hook's override variable is set but does not name an executable
  regular file
- **THEN** the shim reports that the override is invalid, and does not fall
  through to the shared install as though the override had not been set

#### Scenario: The shared install is present

- **WHEN** a hook fires and `~/.agenticapps/bin/<hook>.sh` is executable
- **THEN** the shim `exec`s it and the implementation decides the outcome

#### Scenario: An override is set

- **WHEN** the hook's override variable names an executable file
- **THEN** the shim `exec`s that in preference to the shared install, so a test
  can substitute an implementation without editing any project

### Requirement: An unresolvable shim allows, and the operator sees it

A shim that resolves no implementation SHALL allow the tool call and SHALL make
the failure visible in the session transcript, naming the missing implementation
and the installer that provides it.

**It SHALL exit with a non-blocking error code — not 0.** On the supported host,
a PreToolUse hook exiting 0 has its stdout written to the debug log and its
stderr discarded from the transcript entirely; only a non-zero, non-blocking
exit surfaces the first line of stderr to the operator. A shim exiting 0 with a
warning on stderr therefore warns nobody.

This is not a detail of presentation. Fail-open is acceptable *because* the loss
of protection is announced; an unannounced fail-open is silent protection loss,
which is the posture this capability rejected when it rejected fail-closed. A
previous revision specified exit 0 with a stderr message and would have shipped
exactly that.

It SHALL NOT block. A shim is registered against tool names, not paths, so a
shim that blocked on non-resolution would block **every command and every file
edit in the project**, not the narrow set the hook protects. Narrowing it would
require the shim to inspect the tool payload, which the shim contract forbids
and which would restore the duplicated logic this capability exists to remove.

**Absence is a provisioning failure, and SHALL be caught at provisioning time.**
The installer SHALL verify that every shimmed implementation is present and
executable, and a rollout SHALL publish and verify implementations before
replacing any project's copy with a shim. This is where the guarantee lives; a
per-tool-call block is not a substitute for it, and an earlier revision of this
capability required one.

A hook's class does not change this. Whether a hook is cosmetic or protective
determines how loudly its absence is reported and how urgently it is fixed — not
whether an unprovisioned machine can be used.

**This includes the §18 change gate, and the consequence SHALL be recorded
rather than passed over.** On an unprovisioned machine, PreToolUse enforcement
of the change gate is absent, so §18's review requirement is advisory at the
tool boundary until the installer has run. That is not a regression — the gate
shim already fails open, silently — and §18 already places the real guarantee in
the git pre-commit hook and the CI floor, neither of which a shim can weaken.

The **implementation** is free to take a different posture from the shim,
because the matcher-breadth argument does not apply to it: it inspects the
payload and knows what it is being asked about. In particular a gate
implementation MAY fail closed in `--ci` mode, where blocking costs a pipeline
run rather than an operator's session.

#### Scenario: The change gate's implementation is missing on a developer machine

- **WHEN** the shared install has not run and a code edit is attempted
- **THEN** the edit proceeds with the failure reported, and the change gate's
  guarantee rests on the pre-commit hook and the CI floor until the install is
  repaired

#### Scenario: A shim resolves no implementation

- **WHEN** a shim finds no override and no shared install
- **THEN** the tool call proceeds, and the shim exits with a non-blocking error
  code so the transcript shows the missing implementation and the installer that
  provides it

#### Scenario: The warning channel is verified, not assumed

- **WHEN** the fail-open posture is implemented
- **THEN** it is confirmed against the host that the operator actually sees the
  message, rather than assumed from the fact that something was written to
  stderr

#### Scenario: A project is cloned before the installer runs

- **WHEN** a project is cloned onto a machine where the installer has never run
- **THEN** the project is usable, every shimmed hook reports itself missing, and
  no protection is claimed that is not running

#### Scenario: The installer runs

- **WHEN** the shared artifacts are installed
- **THEN** the installer verifies each shimmed implementation is present and
  executable, and fails visibly if one is not

### Requirement: A shared hook's protections are described as what they are

A hook's documentation SHALL state its coverage boundary rather than describe it
as a security control when it is best-effort.

`database-sentinel` matches destructive SQL and `.env` paths by regex at the
tool-call boundary. It does not prevent `Bash` writing an `.env` file directly,
and indirection such as `psql -f script.sql` never presents the SQL to the
pattern.

**Consolidation itself creates an exposure the capability SHALL state.** Moving
implementations into one shared, user-writable directory turns that directory
into an arbitrary-code-execution concentration point: every shimmed hook is
executed on tool calls in every project that binds it, so anything able to write
one of those files runs code in all of them, at the tool boundary, with the
operator's privileges. That is a strictly larger claim than "write access
changes what `database-sentinel` enforces", which is how a previous revision put
it — the blast radius is every hook and every project, not one control.

This is the cost side of de-duplication and it is accepted rather than solved
here: seven copies drift, one copy concentrates. It is stated so the trade is
visible, and it is why provenance checking is required above rather than left to
"the file exists".

Overstating protection is not cosmetic either: describing the hook as a security
control with no floor beneath it is what motivated the fail-closed posture the
requirement above had to withdraw.

#### Scenario: An operator relies on the hook

- **WHEN** an operator reads what `database-sentinel` protects
- **THEN** the documentation names the bypasses and the shared-file tampering
  surface, so the hook is relied on as defence in depth rather than as a
  boundary

### Requirement: Reconciling divergent copies selects semantics deliberately

When copies of a hook have diverged, the canonical implementation SHALL be
chosen by comparing behaviour, not by recency. Where variants differ in what
they protect, the canonical implementation SHALL take the superset of
protection.

Choosing "the newest file" would have silently narrowed `.env` matching from a
wildcard to a four-item enumeration, dropping protection for any suffix nobody
enumerated.

#### Scenario: Variants differ in matched paths

- **WHEN** one variant matches `.env.*` by wildcard and another enumerates
  specific suffixes
- **THEN** the wildcard is canonical, together with any explicit allowance
  (`.env.example`, `.env.template`) the narrower variant did not need

#### Scenario: Variants differ in handled tools

- **WHEN** one variant handles a tool (`MultiEdit`) the others omit
- **THEN** the canonical implementation handles it

#### Scenario: A variant is deliberately inert

- **WHEN** a project documents in-file that its copy is intentionally
  unregistered
- **THEN** that decision is preserved: the project is not re-registered, and
  the variant is not treated as drift to be reconciled away

### Requirement: Removal is argued from the binding, never from the filename

A hook MAY be deleted without a §02 delta only when all three hold:

1. no §02 gate's documented binding names it;
2. it produces none of the §02 evidence artifacts; and
3. **it does not enforce a §02 gate** — it neither checks a gate's required
   evidence nor is depended on by anything that does.

A hook for which **any clause fails** SHALL NOT be deleted without a delta. (The
previous wording said "satisfies any one of the three", which forbade exactly
the deletions the clauses above permit — a reviewer caught the inversion.)

The third clause was missing and a reviewer supplied it. Binding, production and
enforcement are three different relationships: §02 says hosts SHOULD enforce
`plan-review` with a programmatic gate, which is neither the named skill binding
nor the producer of `REVIEWS.md`. A test that checked only the first two would
clear a hook that is a gate's only enforcement.

Nor does "it checks a sentinel §02 never names" prove the negative on its own —
it shows the hook is not checking *that* evidence, not that it enforces nothing.
The enforcement check is made explicitly rather than inferred.

Filenames are not authoritative **in either direction**. §02 states that a
gate's binding is host-specific data living in the host instruction file. So a
hook whose name matches no gate may still be a gate's binding, and a hook named
after a gate need not be one. An earlier version of this requirement inferred
"not named in §02 ⇒ extension hook", which is unsound in the first direction and
was corrected in review.

The test is therefore performed against two things §02 does define for every
gate: the binding recorded in the host instruction file, and the required
evidence artifact.

#### Scenario: A hook's name matches no §02 gate

- **WHEN** a hook is proposed for deletion and its name appears nowhere in §02
- **THEN** the host instruction file's gate bindings are still checked before
  deleting, because absence of the name proves nothing

#### Scenario: A hook shares a gate's name but is not its binding

- **WHEN** a hook is named after a §02 gate, that gate's binding is a skill named
  in the host instruction file, the hook writes none of the gate's required
  evidence, **and** the enforcement clause has been checked and also fails
- **THEN** deleting the hook removes no binding, and no §02 delta is required

#### Scenario: A hook checks a sentinel that is not the gate's evidence

- **WHEN** a hook gates on a file that §02 does not name as that gate's required
  evidence artifact
- **THEN** that fact alone does not settle the enforcement clause: the hook may
  still enforce the gate indirectly, and clause 3 is evaluated on its own rather
  than inferred from the sentinel's name

### Requirement: A canonical implementation carries no unreachable gate

Reconciling copies SHALL take the superset of protection, and SHALL NOT carry
forward a check whose precondition no surviving tool can satisfy. Such a check
is not protection: it is an unconditional block.

A gate whose precondition depends on tooling the fleet has removed is
unreachable in exactly this way: the remedy it prints cannot be performed, so
the block is permanent. Selecting such an implementation as canonical
propagates an unconditional block to every project that binds the hook.

Superset selection and dead-check removal are one requirement because they act
on the same file at the same moment. Superset selection reads for what a variant
*adds*; whether each addition can still fire is a separate question, and asking
only the first is how the defect nearly shipped.

(The instance that produced this requirement — which implementation, which
clause, which removed command — is recorded in the change's design note rather
than here, so the requirement stays true after the fleet has moved on.)

#### Scenario: The canonical copy contains a dead sentinel check

- **WHEN** the implementation chosen for its broader protection also gates on a
  sentinel no surviving command writes
- **THEN** that clause is removed as part of adopting the implementation, and
  its intent is either rebuilt on a real trigger or recorded as dropped

#### Scenario: A protection is genuinely broader in one variant

- **WHEN** variants differ in what they match
- **THEN** the broader matching is adopted, unchanged

### Requirement: Registration matches the implementation's tool coverage

When a shared implementation handles a tool, every project binding that hook
SHALL register a matcher that delivers it. An implementation's coverage of a
tool its matcher never delivers is inert.

A matcher composed only of tool names is an **exact-string** comparison on the
supported host: a matcher naming one tool does not deliver another whose name
merely contains it. Coverage therefore cannot be inferred from a matcher that
looks similar to the tool name, and SHALL be established against the host's
documented matcher semantics.

The claim in the other direction — that a matcher naming a tool implicitly
covers related tools — was raised in review and checked against the host
documentation, which contradicts it. It is recorded because it is the reading
that would silently make this requirement unnecessary, and it is wrong.

#### Scenario: A shared implementation gains a tool

- **WHEN** a canonical implementation handles a tool some projects' matchers omit
- **THEN** those projects' matchers are updated in the same change, and the
  update is verified per project rather than assumed

#### Scenario: A tool named in a matcher no longer exists on the host

- **WHEN** a matcher or implementation covers a tool the host no longer provides
- **THEN** the coverage is harmless but inert, and SHALL NOT be reported as a
  delivered protection

### Requirement: The scaffolder's templates carry the current shape

A change to the fleet's hook set SHALL update the scaffolder's project templates
and setup snapshot in the same change. A scaffolder that provisions the previous
shape re-creates whatever the change removed, in every project created after it.

A scaffolder may vendor the hook set in more than one place — project templates
and a setup snapshot are distinct copies — together with the matcher
configuration in its settings snapshot. Deleting a hook from every existing
project while leaving it in either means the next project is born with it.

This applies to matchers as well as files: a snapshot whose matcher omits a tool
the shared implementation handles provisions the inert configuration this
capability requires projects to fix.

#### Scenario: A hook is deleted fleet-wide

- **WHEN** a hook is removed from every project that carries it
- **THEN** it is removed from the scaffolder's templates and snapshot in the
  same change, so a newly scaffolded project does not receive it

#### Scenario: A project is scaffolded after the change

- **WHEN** the scaffolder provisions a new project
- **THEN** that project receives the shims, the current matchers, and none of
  the deleted hooks

### Requirement: The rules bind every fleet-shared hook, including the gate

These requirements apply to every fleet-shared hook without exemption. A hook
that predates them SHALL be brought into conformance or explicitly scoped out
with a recorded reason; it SHALL NOT be treated as conformant because it was the
pattern the rules were derived from.

The shim these requirements were modelled on violated several of them as
shipped, and was classified as "unchanged" while the rules it breaks were being
derived from it. A rule with an unstated exemption for its own exemplar is
advisory.

Where bringing an exemplar fully into conformance depends on another change
landing, the dependency SHALL be recorded and the residual non-conformance named
— rather than the exemplar being described as conformant on the strength of work
this change does not do.

#### Scenario: Conformance depends on another change

- **WHEN** part of a hook's non-conformance is resolved by a companion change
- **THEN** the landing order is recorded, and this change's claim is limited to
  the part it actually fixes

#### Scenario: The exemplar is checked against the rules

- **WHEN** requirements are derived from an existing hook
- **THEN** that hook is audited against them like any other, and either migrated
  or scoped out in writing

### Requirement: A hook does not write into archived directories

A hook SHALL NOT write to a directory the fleet designates as frozen history.

`.planning/` is frozen GSD history: read for context, never written, never
treated as the current plan. A hook writing live session data there
contradicts that designation and makes archived and live content
indistinguishable.

#### Scenario: A hook needs to persist session data

- **WHEN** a hook records telemetry or state across sessions
- **THEN** it writes outside `.planning/`, or it is removed

#### Scenario: Session data is read back into model context

- **WHEN** a hook prints stored content into a session's context
- **THEN** that content is treated as untrusted input, delimited as such — or
  the hook is removed rather than carried
