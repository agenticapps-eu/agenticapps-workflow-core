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
or tampered with. The installer SHALL therefore record enough provenance for a
later check to establish that the executed copy is the one that was published:

- **Hash contract** — `sha256`, computed over the file's exact bytes, recorded
  lowercase hex. Same algorithm and encoding as the review digest, so one
  vocabulary covers both.
- **Location** — a manifest beside the shared install directory, written by the
  installer, holding one row per published artifact: path, version marker,
  digest.
- **Trigger** — the check runs on demand (a conformance tool), not in the hook's
  hot path. A shim SHALL NOT hash its implementation before every invocation.
- **Comparison** — the check compares the executed copy against the manifest.
  Comparing it against the *maintained source in core* is a separate, stronger
  check that requires core to be present on the machine, and it SHALL be
  reported separately rather than conflated with the manifest check.

**This is drift detection, not tamper-proofing, and SHALL be described that
way.** The manifest sits beside the executable it describes, is writable by the
same user, and is not signed. Anyone able to alter the implementation can alter
its recorded digest in the same breath. It catches accidental drift — a
hand-edit, a stale copy, a half-finished install — and it catches an attacker
who did not think to update the manifest. It does not establish authenticity,
and no requirement here SHALL be read as claiming it does.

**Publication is atomic per artifact, and is NOT atomic across artifacts.** An
earlier revision required multi-artifact publication to be atomic and required
each manifest row to be "updated in the same operation as the file it
describes". A reviewer showed neither is achievable: two `rename(2)` calls are
two operations, so an implementation and its manifest row cannot be swapped as
one, and per-file renames do not compose into a multi-file transaction. A
guarantee that cannot be implemented is not a guarantee, and specifying one
here would have been discovered as a defect during implementation or, worse,
asserted as satisfied. What is achievable is specified instead:

- **Per-artifact atomicity** — each implementation SHALL be written to a
  temporary path in the destination directory and `rename`d into place. On a
  single filesystem that swap is atomic, so no reader observes a partial file.
- **Whole-manifest atomicity** — the manifest SHALL be rewritten in full to a
  temporary path and `rename`d, never edited row-by-row in place. A row-wise
  edit has its own torn-write window, and rewriting the whole file makes the
  manifest's own update atomic even though its atomicity cannot be *joined* to
  the artifact's.
- **Mutual exclusion** — a publishing run SHALL hold an exclusive lock for the
  duration of its critical section. Without one, two concurrent installers
  read-modify-write the shared manifest and the later writer silently discards
  the earlier's rows. This is a lost-update defect, not a torn-write defect,
  and the lock is what addresses it.
- **Ordering** — an artifact SHALL be renamed into place *before* the manifest
  row naming it is published. The reachable inconsistency is therefore an
  implementation present with no manifest row — a artifact that reports as
  unverifiable — rather than a manifest row promising a file that is absent.
  The direction is chosen deliberately: an unverifiable-but-working hook
  degrades to a reported warning, whereas a row pointing at nothing would make
  the check report a failure the operator cannot act on.

**The reconciliation is the check's job, not the installer's.** Because the two
renames cannot be joined, the manifest and the directory can disagree after a
crash. The conformance check SHALL treat that disagreement as a reportable
state in both directions rather than as an invariant violation.

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

#### Scenario: The implementation and its manifest row are altered together

- **WHEN** the executed copy is modified and its manifest digest is updated to
  match
- **THEN** the check passes, and this is a known and accepted limit of an
  unsigned manifest beside the artifact it describes — the property claimed is
  drift detection, not authenticity

#### Scenario: Publication is interrupted partway

- **WHEN** the installer is killed between publishing two implementations
- **THEN** every implementation it did publish is complete rather than
  truncated, and the manifest is either the pre-run version or the post-run
  version and never a torn mixture — the machine is left **partially
  provisioned**, which is a legitimate state that the check reports, not an
  invariant the installer promises cannot occur

#### Scenario: Two installers publish concurrently

- **WHEN** two publishing runs overlap
- **THEN** the second blocks on the exclusive lock rather than
  read-modify-writing the manifest in parallel, so neither run's rows are lost

#### Scenario: A crash leaves an implementation with no manifest row

- **WHEN** an artifact was renamed into place but the run died before the
  manifest was rewritten
- **THEN** the check reports that implementation as unverifiable — present but
  unattested — rather than reporting it absent or reporting the install clean

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

**A marker alone does not make anything detectable, and the previous revision
stopped at the marker.** A reviewer noted that it defined no format, no
authoritative expected value, no comparison procedure and no check — so nothing
could ever read a marker and conclude "this project is stale". All four are
specified:

- **Format** — a comment line `# shim-contract: <major>.<minor>.<patch>` within
  the shim's first 10 lines, semver, matching `^[0-9]+\.[0-9]+\.[0-9]+$`. Same
  shape and placement convention as the gate's `# gate-version:` marker, so one
  reading rule covers both.
- **Authority** — the expected version is the one recorded in the shim template
  under `reference-implementations/project-hooks/`. The template in core is the
  authority; a shim in a project is a copy that either matches it or is stale.
  No project-local file is authoritative for its own conformance.
- **Comparison** — a shim is **current** when its marker equals the template's,
  **stale** when it is lower, and **unrecognised** when it is absent, malformed
  or higher than the template's. Higher is not "newer and fine": it means the
  project carries a shim the tracked template cannot account for, which is the
  drift this marker exists to surface.
- **Check** — a conformance tool SHALL enumerate every project binding a shimmed
  hook, read each marker, and report each project's state. The marker's purpose
  is discharged by that report existing, not by the marker being present.

Bumping the contract version SHALL accompany any change to resolution order,
exit behaviour or identification — the same three things this requirement's
first paragraph calls a contract change.

#### Scenario: The shim contract changes

- **WHEN** the resolution order or exit behaviour required of shims is revised
- **THEN** every project binding an affected hook is enumerated and updated, and
  each is verified rather than assumed to have been reached

#### Scenario: A project carries a shim from before a contract change

- **WHEN** the conformance check reads a shim whose marker is lower than the
  template's
- **THEN** that project is reported stale by name, rather than the discrepancy
  surfacing later as one repo behaving unlike its siblings

#### Scenario: A shim carries no marker or a malformed one

- **WHEN** a shim has no `# shim-contract:` line in its first 10 lines, or one
  that is not semver
- **THEN** it is reported unrecognised — it is not treated as current by default,
  because an unmarked shim is exactly the pre-marker shim the check exists to find

#### Scenario: A shim's marker is higher than the template's

- **WHEN** a project's marker exceeds the version recorded in core's template
- **THEN** it is reported unrecognised rather than passed as up-to-date, because
  the tracked template is the authority and cannot account for that version

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

**This two-candidate order governs tool-boundary shims only. The git
`pre-commit` wrapper is a different artifact and is NOT brought under it.** A
reviewer observed that the capability claimed the pre-commit hook as the fallback
carrying the guarantee when a shim fails open, without establishing that it
survives the same conditions. Checked against
`reference-implementations/openspec-change-gate/pre-commit`, it does not:

```
GATE="${OPENSPEC_GATE:-${OPENSPEC_CHANGE_GATE:-$HOME/.agenticapps/bin/openspec-change-gate.sh}}"
[ -x "$GATE" ] || GATE="$(git rev-parse --show-toplevel)/bin/openspec-change-gate.sh"
```

Its last resort is `<repo>/bin/openspec-change-gate.sh` — **the very candidate
this requirement forbids** — and when that too is absent it prints a warning and
`exit 0`, fail-open by design so that a missing tool does not train operators
into `--no-verify`. So on an unprovisioned machine the PreToolUse shim fails open
*and* the pre-commit wrapper fails open, and the only enforcement left is CI. The
capability's own claim that "the guarantee rests on the pre-commit hook and the
CI floor" was half right, and the half that was wrong is the half that runs on a
developer's machine.

Two consequences are normative:

- The two-candidate rule SHALL NOT be applied to the `pre-commit` wrapper. Doing
  so would delete its `<repo>/bin/` fallback and leave it strictly weaker, which
  is the opposite of the rule's purpose. The wrapper is not a tool-boundary shim:
  it runs outside the host, has no matcher breadth, and its fallback is reached
  by an operator running `git commit`, not by every `Edit`.
- Any statement that the pre-commit hook backstops a fail-open shim SHALL name
  the provisioning state it assumes. It backstops a **provisioned** machine. On
  an unprovisioned one it fails open too, and **CI is the only floor** — which
  SHALL be stated wherever the fallback is claimed.

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
- **It is a kill switch, and SHALL be documented as one.** Setting a hook's
  override to a path that does not exist disables that hook on a machine whose
  shared install is perfectly healthy: the shim reports an invalid override and
  allows the call. For the §18 change gate that is a one-variable bypass of the
  review requirement at the tool boundary. This follows from fail-open — the
  alternative is blocking every `Bash`, `Edit` and `Write` in the project on a
  typo'd variable — but it SHALL appear in the hook's stated coverage boundary
  rather than only in this requirement, so an operator reading what the hook
  protects also reads what turns it off.
- **The prohibition on project-set overrides SHALL be enforced by configuration
  validation, not by the shim.** The previous revision required the shim to
  honour the variable "from the process environment only" and not "out of any
  project-controlled file". A reviewer showed that is unimplementable: when
  `.claude/settings.json` defines a variable in its `env` block, the host injects
  it into the hook process's environment, where it is **indistinguishable** from
  one the operator exported. A shim reads `$VAR`; there is no provenance to
  inspect. A behaviour-free shim cannot satisfy a rule about where a value came
  from, and specifying one produced a requirement no test could ever fail.

  The prohibition is real and is retained — a cloned repository must not be able
  to switch off the gate that governs it — but it moves to the only layer that
  can see provenance, the configuration itself:

  - A conformance check SHALL scan every project's `.claude/settings.json` (and
    any settings file the host merges) for an `env` block defining any shim's
    override variable, and SHALL report each occurrence.
  - The finding is reported against the **repository**, not suppressed at
    runtime: the value still takes effect on a machine that has it, which is
    precisely why it must be visible in review rather than silently ignored.
  - No project in the fleet sets `env` in `.claude/settings.json` today —
    verified across all seven — so this check starts green and exists to keep it
    that way.

  This is a weaker guarantee than the previous wording claimed, and the weakening
  is the point: the strong version was unenforceable, so it guaranteed nothing
  while reading as though it guaranteed everything.

This does not weaken "authoritative in one place". That requirement is about
what is *tracked and maintained* — one file that maintainers edit — not about
what a test harness may substitute at runtime. A reviewer read the two as
conflicting, which they will be unless the distinction is stated.

#### Scenario: The override names a missing or non-executable file

- **WHEN** a hook's override variable is set but does not name an executable
  regular file
- **THEN** the shim reports that the override is invalid, and does not fall
  through to the shared install as though the override had not been set

#### Scenario: A project's configuration sets the override

- **WHEN** a repository's own `.claude/settings.json` defines the override
  variable in its `env` block
- **THEN** the conformance check reports that repository by name, because the
  value **will** take effect at runtime — the shim cannot tell it apart from an
  operator-exported variable, so the defence is detection in review, not
  rejection at the tool boundary

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

**A machine is in exactly one of three provisioning states, and the invariants
differ per state.** A reviewer found the capability asserting, under publication,
that "no project binds a hook whose implementation is absent", while the
clone-before-install scenario below explicitly permits exactly that. Both
sentences were true of different states and neither said which, so the pair read
as a contradiction. The states are named here and every invariant elsewhere in
this capability SHALL be read as qualified by one of them:

| State | Definition | Invariant |
|---|---|---|
| **Unprovisioned** | the installer has never run on this machine | shims resolve nothing, report, and allow. Binding a hook whose implementation is absent is **expected and permitted** — it is the state a fresh clone is in |
| **Partially provisioned** | a publishing run was interrupted, or only some artifacts were published | each published implementation is complete and each is either attested by a manifest row or reported unverifiable. Mixed is legal; torn is not |
| **Provisioned** | a publishing run completed | every shimmed implementation is present, executable, and attested by a manifest row whose digest matches |

The rule that a project must never bind a missing implementation applies to the
**provisioned** state only. It is a post-condition of a completed install, not a
property of the fleet at all times — which is what made it look like it
contradicted a usable fresh clone.

A rollout SHALL move a machine to *provisioned* before any project's copy is
replaced with a shim, because that ordering is what keeps the window in which a
project has a shim but no implementation from being entered deliberately.

**It SHALL exit with a non-blocking error code — not 0.** On the supported host,
a PreToolUse hook exiting 0 has its stdout written to the debug log and its
stderr discarded from the transcript entirely; only a non-zero, non-blocking
exit surfaces the first line of stderr to the operator. A shim exiting 0 with a
warning on stderr therefore warns nobody.

**This exit rule is established for `PreToolUse` and SHALL be re-established
per event class, not assumed to generalise.** The three shimmed hooks are not
all one class: the change gate and `database-sentinel` are `PreToolUse`,
`normalize-claude-md` is `PostToolUse`. Host exit-code semantics differ by
event — a `PostToolUse` hook has no call to block, and `SessionStart` output is
injected as context rather than surfaced as a warning. A shim for an event class
not yet covered here SHALL have its warning channel verified against the host
docs for *that* event before the shim is written, and the verified behaviour
recorded alongside this requirement. Reusing the `PreToolUse` exit convention
untested is the same unverified-assumption failure that produced the exit-0
defect above.

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
shim already fails open, silently.

**What is beneath it, stated correctly.** An earlier revision of this paragraph
said §18 "places the real guarantee in the git pre-commit hook and the CI floor,
neither of which a shim can weaken". The CI half holds. The pre-commit half does
not, on the very machine this paragraph is about: the wrapper resolves the same
`~/.agenticapps/bin/` path the shim just failed to resolve, falls back to
`<repo>/bin/`, and then warns and exits 0. Unprovisioned means **both** layers
fail open, and **CI is the only floor**. A reviewer doubted the claim; reading
the wrapper confirmed the doubt. Any restatement of the fallback SHALL name the
provisioning state it assumes.

The **implementation** is free to take a different posture from the shim,
because the matcher-breadth argument does not apply to it: it inspects the
payload and knows what it is being asked about. In particular a gate
implementation MAY fail closed in `--ci` mode, where blocking costs a pipeline
run rather than an operator's session.

#### Scenario: The change gate's implementation is missing on a developer machine

- **WHEN** the shared install has not run and a code edit is attempted
- **THEN** the edit proceeds with the failure reported, and — because the
  pre-commit wrapper resolves the same absent shared install and then fails open
  itself — **CI is the only remaining floor**, which is reported as such rather
  than described as the pre-commit hook holding the guarantee

#### Scenario: The pre-commit wrapper is audited against the shim contract

- **WHEN** the two-candidate resolution order is applied to
  `reference-implementations/openspec-change-gate/pre-commit`
- **THEN** it is recorded as out of scope rather than corrected, because removing
  its `<repo>/bin/` fallback would leave it weaker than it is today

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
they protect, the superset of protection SHALL be the **default** choice.

Choosing "the newest file" would have silently narrowed `.env` matching from a
wildcard to a four-item enumeration, dropping protection for any suffix nobody
enumerated.

**The superset is a default, not an unconditional rule, and each difference
SHALL be reviewed before it is adopted fleet-wide.** A broader variant can be
broader because it is wrong: it may carry false positives that block legitimate
edits, encode a policy true of one project and not its siblings, or check a
sentinel that is reachable but obsolete. Unioning those across seven projects
propagates one project's bug to all of them — the same fleet-wide-blast-radius
argument this capability makes about the shared directory, applied to
semantics. For each behavioural difference the reconciliation SHALL record
which variant is canonical and why, and where a difference is deliberately
project-specific it SHALL be preserved as a documented opt-out rather than
dissolved into the union. `agents-task-viewer`'s `normalize-claude-md` opt-out
of 2026-07-21 is the worked example: it is a difference that survives
consolidation.

A difference that cannot be justified either way is not resolved by taking the
broader side; it is escalated to the operator, because adopting protection
nobody can explain is how the dead GSD sentinels in this fleet survived as long
as they did.

#### Scenario: Variants differ in matched paths

- **WHEN** one variant matches `.env.*` by wildcard and another enumerates
  specific suffixes
- **THEN** the wildcard is canonical, together with any explicit allowance
  (`.env.example`, `.env.template`) the narrower variant did not need

#### Scenario: Variants differ in handled tools

- **WHEN** one variant handles a tool (`MultiEdit`) the others omit
- **THEN** the canonical implementation handles it

#### Scenario: The broader variant is broader by mistake

- **WHEN** one variant blocks a path the others allow, and the block cannot be
  traced to a live gate or a stated project policy
- **THEN** the difference is escalated rather than unioned in, because a
  fleet-wide superset would propagate one project's false positive to all seven

#### Scenario: A variant is deliberately inert

- **WHEN** a project documents in-file that its copy is intentionally
  unregistered
- **THEN** that decision is preserved: the project is not re-registered, and
  the variant is not treated as drift to be reconciled away

### Requirement: Removal is argued from the binding, never from the filename

A hook MAY be deleted without a delta only when all three hold:

1. no gate's documented binding names it;
2. it produces none of the required evidence artifacts; and
3. **it does not enforce a gate** — it neither checks a gate's required
   evidence nor is depended on by anything that does.

A hook for which **any clause fails** SHALL NOT be deleted without a delta. (The
previous wording said "satisfies any one of the three", which forbade exactly
the deletions the clauses above permit — a reviewer caught the inversion.)

**The three clauses SHALL be evaluated against every applicable specification
section and against transitive consumers — not against §02 alone.** The previous
revision scoped all three to §02, which a reviewer showed could authorise
deleting a hook that §17, §18, another capability, or a project's own policy
depends on: passing a §02-only test says nothing about a §17 obligation. The
scope is therefore:

- **Every section that can bind or require a hook**, which today means at least
  §02's gates, §17's lifecycle-and-gate mapping and §18's change gate — and any
  section added later, without this list needing to be reopened, because the
  rule is "applicable specifications", not an enumeration.
- **Capability specs under `openspec/specs/`**, which can require a hook without
  any numbered section naming it.
- **Transitive consumers** — anything that invokes the hook, reads what it
  writes, or would change behaviour if it stopped running. The check is "what
  breaks if this file is gone", asked of the fleet and not only of the spec.
- **Project-local policy** — a repo may depend on a hook the fleet does not
  require. That dependency is the project's to waive, and SHALL be recorded as
  waived rather than overlooked.

Clearing §02 is necessary and not sufficient, and a deletion argued only from
§02 SHALL be treated as unargued.

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

#### Scenario: A hook clears §02 but another section requires it

- **WHEN** a hook satisfies all three clauses against §02, and §17 or §18 or a
  capability spec depends on it
- **THEN** it SHALL NOT be deleted without a delta, because clearing one section
  is not clearing the specification

#### Scenario: A hook nothing specifies is depended on by something that runs

- **WHEN** no specification names a hook, but another script invokes it or
  consumes what it writes
- **THEN** the transitive-consumer clause fails and the deletion is argued or
  abandoned, rather than cleared on the grounds that no spec mentions it

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

**This requirement binds hooks, and hooks are not the only writers — deleting
the two named in this change does NOT end the violation.** Measured while
revising: `agenticapps-workflow-core` carries 141 files under
`.planning/skill-observations/` while having **no `.claude/hooks/` directory at
all**. 137 of them are named `<stamp>--<sessionId>.{md,jsonl}`, which is the
naming of a *global* `SessionEnd` hook registered in `~/.claude/settings.json`
running `agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`,
whose own header states it "writes
`<projectRoot>/.planning/skill-observations/<stamp>--<sessionId>.{md,jsonl}`".
Only 4 match `skill-router-log.sh`'s `skill-router-{date}.jsonl` naming.

The producer that writes the overwhelming majority of this fleet's `.planning/`
traffic is therefore **not** a project hook, is registered globally rather than
per-project, and writes into every repository the operator opens — including
repositories that carry no hooks. It is out of this capability's scope, which
governs project hook binding, and is recorded as a follow-up rather than
silently left implied to be fixed.

Deleting `skill-router-log.sh` and `session-bootstrap.sh` remains correct: they
do write there, and they are hooks. What SHALL NOT be claimed is that their
deletion makes the fleet compliant with the frozen-archive policy. Identifying a
producer by the name of a nearby file, rather than by what actually writes, is
the same error this capability's deletion rule exists to prevent — found here in
this change's own evidence.

#### Scenario: A non-hook writer produces the same violation

- **WHEN** a directory designated frozen is being written and no hook accounts
  for the files
- **THEN** the actual producer is identified before any hook is credited with
  causing or curing the violation, and a fix scoped to hooks is reported as
  partial rather than complete

#### Scenario: A hook needs to persist session data

- **WHEN** a hook records telemetry or state across sessions
- **THEN** it writes outside `.planning/`, or it is removed

#### Scenario: Session data is read back into model context

- **WHEN** a hook prints stored content into a session's context
- **THEN** that content is treated as untrusted input, delimited as such — or
  the hook is removed rather than carried
