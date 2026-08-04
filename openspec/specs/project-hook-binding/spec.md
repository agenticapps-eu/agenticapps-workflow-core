# project-hook-binding Specification

## Purpose
TBD - created by archiving change shim-project-hooks. Update Purpose after archive.
## Requirements
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
- **The row's version marker is the *implementation's*, and it is defined here.**
  A reviewer noted the manifest demanded a version marker while the only marker
  this capability defined was `# shim-contract:`, which marks **shims** — the
  copies in projects — not the published implementations the manifest describes.
  The field named something that did not exist. An implementation SHALL carry
  `# <hook>-version: <major>.<minor>.<patch>` within its first 10 lines, semver,
  matching `^[0-9]+\.[0-9]+\.[0-9]+$` — the convention `run-plan-review.sh` and
  the change gate already use in this fleet, so no new reading rule is
  introduced. The **authority** is the tracked file in core, as it is for the
  shim template. The version SHALL be bumped whenever the implementation's
  behaviour changes, and an installer SHALL refuse to overwrite a published copy
  carrying a **higher** version than the one it holds, treating an unmarked file
  as `0.0.0` — the rule that already governs the shared directory's other
  artifacts. The two markers answer different questions and SHALL NOT be
  conflated: `# shim-contract:` says which contract a project's shim implements,
  `# <hook>-version:` says which build of the implementation is published.
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

  **The mechanism is named, because the obvious one is wrong.** The lock SHALL be
  an `flock` held on a lockfile beside the manifest, and SHALL NOT be a
  create-and-check lock file. A reviewer pointed out that "SHALL hold an exclusive
  lock" is not implementable as written and that the two candidate readings differ
  where it matters: a create-and-check lockfile survives the process that made it,
  so an installer killed mid-run leaves a lock nobody holds and the next run either
  blocks forever or learns to delete locks — which is no lock at all. `flock` is
  released by the kernel when the holder dies. The failure this whole requirement
  is about is an interrupted publishing run, so a locking scheme that breaks on
  interruption is the one scheme that must be excluded by name.
- **Ordering** — an artifact SHALL be renamed into place *before* the manifest
  row naming it is published. The reachable inconsistency is therefore an
  implementation present with no manifest row — a artifact that reports as
  unverifiable — rather than a manifest row promising a file that is absent.
  The direction is chosen deliberately: an unverifiable-but-working hook
  degrades to a reported warning, whereas a row pointing at nothing would make
  the check report a failure the operator cannot act on.

**The publication algorithm is specified, not left to the implementer.** A
reviewer showed the clauses above under-determine it and quietly conflict:
"the manifest is either the pre-run version or the post-run version" describes a
manifest written **once per run**, while the ordering clause describes a row
published **per artifact**, and both cannot hold. The algorithm is therefore
stated outright:

1. Acquire the exclusive lock.
2. Read the current manifest.
3. For each artifact: write it to a temporary path **in the destination
   directory** and `rename` it into place.
4. Once **every** artifact is in place, rewrite the manifest in full to a
   temporary path and `rename` it. The manifest is written **once per run**.
5. Release the lock.

Step 4 is what makes "pre-run or post-run, never a torn mixture" true of the
manifest. The per-artifact ordering clause above is satisfied by the whole of
step 3 preceding step 4, not by interleaving rows with renames.

**Both crash windows are covered, and the second was missing.** The previous
revision described only a first install:

- **Initial install, interrupted** — the artifact is in place and the pre-run
  manifest has no row for it. The check reports it **present but unattested**.
- **Upgrade, interrupted** — the artifact is in place at its *new* bytes and the
  pre-run manifest still carries its *old* row. The row is **stale, not
  missing**; the digest comparison fails. A reviewer noted that republishing over
  an existing artifact "leaves a stale row — not no row", which the previous text
  neither described nor classified. It resolves to **drifted**.

The remedy is identical in both cases — re-run the installer — which is why the
distinction costs nothing to state and misclassifies a machine if omitted.

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

#### Scenario: Two binders in the same profile are compared

- **WHEN** the same hook is compared byte-for-byte across any two projects that
  bind it under the **published-resolution** profile
- **THEN** the two files are identical, because both are shims naming the same
  implementation

#### Scenario: A self-hosting binder is compared against a project shim

- **WHEN** the repository that maintains an implementation is compared against
  any project that consumes it
- **THEN** the two files are expected to differ, and the difference is not drift
  — they implement different profiles, and each is checked only against the
  requirements its own profile carries

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
  version and never a torn mixture — the machine is left at completeness
  **`partial`**, which is a legitimate condition the check reports, not an
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

#### Scenario: A crash during an upgrade leaves a stale manifest row

- **WHEN** an artifact that already had a row is republished at new bytes and the
  run dies before the manifest is rewritten
- **THEN** the check compares the new bytes against the **old** row, the digest
  does not match, and the machine is reported **drifted** — not clean, and not
  unattested, because the row exists and is wrong

#### Scenario: An install completes and the implementation is later edited

- **WHEN** a publishing run finished and someone hand-edits, replaces or deletes
  a published implementation afterwards
- **THEN** the machine is reported **drifted**, because the state is computed
  from what is on disk now rather than from the fact that a run once completed

### Requirement: The shim contract itself has a propagation path

A shim is duplicated across every project that binds the hook, so a change to
the **shim contract** — resolution order, exit behaviour, identification,
reporting — is a change to N files, not one. Such a change SHALL name the
projects it must reach and SHALL be verified per project.

The one-authoritative-place rule covers implementations, not shims: shims are
deliberately copies, which is what makes them cheap and what makes a contract
change a fleet-wide edit. This change is itself an instance — it edits the
change-gate shim in the seven projects **and** in core, which gained its own
copy on 2026-08-02. Core's copy resolves its working-tree reference
implementation rather than the published one (ADR-0028's deliberate inversion),
which is the **self-hosting** profile defined two requirements below: the
resolution-order clauses do not reach it, while the version marker, the
behaviour-free rule and the fail-open-and-report rule do. Eight files, not
seven, and the count is not uniform in what it owes — which is why this
requirement says a contract change SHALL name the projects it must reach rather
than assume the set.

A contract change SHALL also name **which profile each binder implements**, for
the same reason it names the binders: a change that reaches all eight files and
applies one profile's clauses to both has not been verified, it has been
assumed uniform.

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
exit behaviour, identification or **reporting** — the same four things this
requirement's first paragraph calls a contract change.

**Reporting was added to that list by an instance, not by symmetry.** A change
altering what every shim writes when its report is suppressed touched none of
the other three: resolution order, exit codes and identification were all
byte-unchanged. Under the previous wording no bump was owed, so every deployed
shim would have differed from the template in what it says with no marker
difference to surface it — the blindness the marker exists to remove, reached
through the marker's own rule.

**A shim's behaviour is not confined to what it hands over to; what it says is
part of the contract**, because the report is the whole of what an unresolvable
shim delivers. On a machine where resolution fails, the message is the only
output the operator ever sees from that hook.

#### Scenario: The shim contract changes

- **WHEN** the resolution order, exit behaviour or reporting required of shims is
  revised
- **THEN** every project binding an affected hook is enumerated and updated, and
  each is verified rather than assumed to have been reached

#### Scenario: Only what shims say is changed

- **WHEN** a change alters a shim's report while leaving resolution order, exit
  codes and identification untouched
- **THEN** the contract version is bumped and the change propagates like any
  other contract change, rather than being treated as a documentation edit
  because no resolution or exit path moved

#### Scenario: The binders are enumerated from a declaration

- **WHEN** a contract change names the projects it must reach
- **THEN** the set comes from the declared fleet rather than from the projects
  the change happened to notice, because a binder omitted from an ad-hoc list is
  indistinguishable from one that passed

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
beyond this closed list:

1. resolution;
2. host self-identification;
3. `exec`;
4. **reporting** — the fail-open report and the invalid-override report required
   below; and
5. **reading and writing a single repetition marker**, where the shim's stated
   repetition policy needs one.

Items 4 and 5 are carve-outs, and they are enumerated here because a reviewer
found them added in their own sections while this sentence still read
absolutely — three clauses in the contract and five behaviours in the
capability. A rule that its own document contradicts is the defect this change
exists to remove, and it had grown one.

The list is **closed**. In particular no shim SHALL inspect the tool payload:
that is what makes narrow blocking impossible, which is what makes fail-open
necessary, and it is the duplication this capability exists to prevent.

The shim SHALL resolve in this order:

1. An explicit environment override, when set
2. `~/.agenticapps/bin/<hook>.sh` — the shared install

There is no third candidate. An earlier draft named `<repo>/bin/<hook>.sh`, and
that entry has no coherent reading: if `<repo>` is the product repository, the
fallback is the in-project copy this capability forbids two requirements above;
if it is the scaffolder's own checkout, a shim running inside a product repo has
no defined way to locate it. Either way the entry contradicted something, so it
is removed rather than clarified.

**Removing it is a real loss wherever that candidate currently resolves, and
SHALL be sequenced rather than asserted harmless.** A reviewer challenged the
claim that dropping the third candidate costs nothing because "the gate shim
already fails open". Checked across all seven projects: six carry no
`<repo>/bin/openspec-change-gate.sh`, and **`agents-task-viewer` carries one that
is present and executable**. In that repository the third candidate resolves
today, so an unprovisioned machine currently gets **enforced validation** there
and would get fail-open after the removal. The claim was true of six repositories
and asserted of seven.

Therefore: a binder whose third candidate currently resolves SHALL be moved to
completeness `complete` — verified by the per-machine check — **before** the
candidate is removed. The rule is kept, uniformly, and the enforcement window it
would otherwise open is closed by ordering rather than by an exception. Where
that ordering cannot be established for a binder, the removal SHALL be deferred
for that binder and the reason recorded, rather than the loss being taken
silently.

#### Scenario: A binder's forbidden third candidate currently resolves

- **WHEN** a project ships an executable `<repo>/bin/<hook>.sh` that the shim
  reaches today
- **THEN** removing that candidate is recorded as a loss of enforcement on
  unprovisioned machines, and the machine is verified `complete` first — the
  removal is not described as costless because it is costless in the other
  repositories

**That order is the *published-resolution* profile, and it is not universal.** A
reviewer showed the contract as previously written mandated shared-install
resolution **and** byte-identical shims for every binder, while the repository
that maintains an implementation deliberately resolves its own working tree — so
one contract, attested by one version marker, was being asked to represent two
incompatible bindings honestly. It cannot. Two profiles are therefore normative:

| Profile | Bound by | Resolves | Why |
|---|---|---|---|
| **published-resolution** | every project that consumes a shared hook | the override, then `~/.agenticapps/bin/<hook>.sh` | one implementation, published once, executed identically everywhere |
| **self-hosting** | the repository whose working tree is the authoritative source | the override, then that maintained file directly | scoring the published copy tests whichever host's installer ran last, not the bytes this repository ships (ADR-0028) |

Each binder SHALL declare its profile, and every requirement in this capability
SHALL be evaluated against the declared profile:

- **Both profiles honour the override; they differ in the second candidate
  only** — the shared install for one, the maintained working-tree file for the
  other. A previous revision of this table said a self-hosting binder "has
  neither candidate to carry", which a reviewer checked against
  `.claude/hooks/openspec-change-gate.sh` and found false: that file resolves
  `${OPENSPEC_GATE:-$ROOT/reference-implementations/...}`, so it honours the
  override exactly as a project shim does. The error was compressing "no shared
  install and no `<repo>/bin/` candidate" into "neither candidate", in a
  paragraph written after reading the file. It is corrected rather than
  explained.
- A self-hosting binder SHALL NOT be reported as violating the *shared-install*
  candidate it is exempt from.
- Byte-identity is required **within** a profile, never across profiles.
- The version marker, the behaviour-free rule, the fail-open-and-report rule and
  its repetition policy bind **both**. They are what the two profiles have in
  common, and they are the whole of what a single marker can honestly attest.

For any one hook, **at most one binder is self-hosting** — the repository that
maintains it. A second would be a second authority, which the first requirement
in this capability forbids.

#### Scenario: A self-hosting binder is audited against the resolution order

- **WHEN** the two-candidate order is applied to the repository that maintains
  the implementation
- **THEN** it is recorded as out of profile rather than as non-conformant, and
  the marker and fail-open clauses are still checked against it

#### Scenario: A contract change reaches binders in both profiles

- **WHEN** a shim-contract change is rolled out
- **THEN** each binder's profile is named, and clauses are applied per profile
  rather than uniformly across the file count

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
  gate's **only blocking condition** — `openspec validate --all` — together with
  the review *reporting* that accompanies it. (An earlier revision called it a
  bypass of "the review requirement". Per `change-gate-enforcement`, reviews are
  reported and never enforced, so that named an enforcement the gate does not
  have and understated the one it does.) This follows from fail-open — the
  alternative is blocking every `Bash`, `Edit` and `Write` in the project on a
  typo'd variable — but it SHALL appear in the hook's stated coverage boundary
  rather than only in this requirement, so an operator reading what the hook
  protects also reads what turns it off.
- **An override naming an existing executable is a code-execution path, and the
  previous revision covered only the missing-file case.** The invalid-override
  rule above makes a *broken* override safe: report and allow. A *working* one is
  the opposite. Whatever the variable names is `exec`d at the tool boundary, on
  every matched call, with the operator's privileges — and the matchers here are
  `Bash`, `Edit` and `Write`, so that is most of what a session does. If the
  value can be set by anything a repository ships (see the provenance clause
  below, and note that it can), then a clone can choose the code that runs on
  every matched call in it. That is a strictly larger exposure than switching the
  hook off, it was omitted where the kill switch was named, and it SHALL appear
  in the hook's stated coverage boundary beside it.
- **The prohibition on project-set overrides SHALL be enforced by configuration
  validation, not by the shim.** The previous revision required the shim to
  honour the variable "from the process environment only" and not "out of any
  project-controlled file". A reviewer showed that is unimplementable: when
  `.claude/settings.json` defines a variable in its `env` block, the host injects
  it into the hook process's environment, where it is **indistinguishable** from
  one the operator exported. A shim reads `$VAR`; there is no provenance to
  inspect. A behaviour-free shim cannot satisfy a rule about where a value came
  from, and specifying one produced a requirement no test could ever fail.

  **The sentence that stood here claimed a prohibition this capability does not
  deliver, and it is withdrawn.** It read: "a cloned repository must not be able
  to switch off the gate that governs it." A reviewer showed the mechanism
  contradicts it — a project-set override **does** take effect, and a check that
  reports it afterwards is detection, not prevention. What survives is two
  separate things, and they SHALL be stated separately:

  - a **policy**: a project SHALL NOT set any shim's override variable; and
  - a **detection**: the setting is visible in the repository's own tracked
    files, so it is found by reading them.

  Between them lies a window in which the value is live and unreported, and this
  capability SHALL NOT be read as closing it. Detection is what is on offer.

  **No automated scan is required, and one SHALL NOT be inferred from this
  sentence.** A scan was built, run across all seven repositories, and retired.
  It found no vector in any of them. What retired it was not its result but its
  cost: the instrument reached six times the size of the contract it measured,
  and every reading of its output produced another defect in the instrument
  rather than in the fleet. A capability that mandates measurement gets the
  measurement it mandates, so this one stops mandating it and states what a
  reviewer should look for instead:

  - The vectors are `.claude/settings.json`'s `env` block (and any settings file
    the host merges), repository-shipped environment files (`.envrc` and
    equivalents), bootstrap and setup scripts, task-runner definitions, and
    documented setup instructions. The first is the one the host injects
    directly; it is not the only one.
  - **Any detection is incomplete by construction and SHALL be described as
    such.** A repository can put the export in prose that a human then runs, and
    the resulting process environment is byte-for-byte identical to one the
    operator chose. Nothing distinguishes them, and no enumeration of file types
    is closed. A clean reading SHALL be reported as *no known vector found*,
    never as *no override is set*.
  - The concern is raised against the **repository**, not suppressed at
    runtime: the value still takes effect on a machine that has it, which is
    precisely why it must be visible in review rather than silently ignored.
  - As of 2026-08-04 no project in the fleet sets `env` in
    `.claude/settings.json`, and the retired scan reported no known vector across
    all seven for the wider set either. That is a dated observation about seven
    checkouts on one machine, not a property of the fleet, and it SHALL NOT be
    quoted as one.

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
- **THEN** the value **will** take effect at runtime — the shim cannot tell it
  apart from an operator-exported variable, so the defence is review of the
  repository's own files, not rejection at the tool boundary

#### Scenario: A repository sets the override outside the settings file

- **WHEN** a repository ships an `.envrc`, a bootstrap script, or setup
  instructions that export a shim's override variable
- **THEN** that violates the policy above and is raised against the repository,
  and where the export reaches the operator's shell by a route no reading of the
  repository can enumerate, a clean reading is reported as **no known vector
  found** rather than as a repository that sets nothing

#### Scenario: A repository points the override at code it ships

- **WHEN** the override names an executable file that exists — supplied by the
  repository rather than by the operator
- **THEN** the shim `exec`s it on every matched call, which is repository-chosen
  code running at the tool boundary with the operator's privileges, and the
  hook's coverage boundary SHALL name this alongside the kill switch

#### Scenario: The shared install is present

- **WHEN** a hook fires and `~/.agenticapps/bin/<hook>.sh` is executable
- **THEN** the shim `exec`s it and the implementation decides the outcome

#### Scenario: An override is set

- **WHEN** the hook's override variable names an executable file
- **THEN** the shim `exec`s that in preference to the shared install, so a test
  can substitute an implementation without editing any project

### Requirement: A shim that resolves no implementation allows the call and reports it

A shim that resolves no implementation SHALL allow the tool call and SHALL make
the failure visible in the session transcript, naming the missing implementation
and the installer that provides it.

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

**Until that verification is recorded, no operator-visible warning SHALL be
claimed for a shim in that class.** `normalize-claude-md` is the live instance:
it is `PostToolUse`, this capability records a verified channel for `PreToolUse`
only, and every statement that "both shims fail open with a loud warning"
therefore asserts a channel for one of them that nobody has checked. A reviewer
found this change writing the verification requirement and violating it in the
same revision — which is the failure mode the requirement exists to prevent,
demonstrated on its author. The rule is: fail-open-and-report binds every shim,
but the *report* half is claimable per event class only once verified, and a
shim whose class is unverified SHALL be described as failing open with its
reporting channel **unestablished** rather than as warning anyone.

**The report SHALL have a stated repetition policy.** A shim on an unprovisioned
machine is unresolvable on *every* matched call, so an unqualified "report each
time" emits a hook-error notice on every `Bash`, `Edit` and `Write`, indefinitely.
A reviewer observed that this is the same conditioning pressure this capability
uses to reject a fail-closed pre-commit wrapper: persistent unavoidable failure
teaches operators to stop reading. The asymmetry is real but only partial — a
non-blocking notice has no durable escape hatch to learn, where `--no-verify` is
one action that disables the floor permanently — and it does not dispose of the
objection, because an ignored notice and a suppressed one differ mainly in who is
doing the suppressing.

A shim SHALL state its repetition policy, and it SHALL be one of **per
invocation**, **once per session**, or **once per interval**. Leaving it unstated
is what the previous revision did, and an unstated policy defaults silently to
the noisiest of the three.

**The invalid-override report is carved out and SHALL be emitted per invocation,
whatever the policy.** A reviewer found that the policy as first written could
rate-limit the highest-severity thing a shim can say. The two reports are not
alike:

| Report | Condition | Policy |
|---|---|---|
| implementation unresolvable | the machine is unprovisioned — an expected condition a fresh clone is in, self-correcting once the installer runs | subject to the repetition policy |
| **override invalid** | a variable names a path that is not an executable file, on a machine whose shared install may be perfectly healthy | **per invocation, always** |

The second is the kill switch. Suppressing it suppresses the only signal that a
hook has been switched off — and for the §18 gate, that its one blocking
condition is not running. A rate limit adopted to quiet a benign condition would
have silenced the malign one, because the previous text wrote a single policy
covering both.

Per-session and per-interval both require a marker, which is behaviour beyond
resolution and `exec`. That carve-out is permitted, is bounded to reading and
writing a single marker path, and SHALL NOT extend to inspecting the tool
payload. It carries one obstacle that SHALL be established against the host
rather than assumed: the session identifier arrives in the hook's **stdin
payload**, which the shim must forward to its implementation intact, so a shim
that consumes stdin to read the identifier has taken the input the implementation
needs. If no session identifier is reachable without consuming stdin, the policy
SHALL be per-interval or per-invocation, and the reason SHALL be recorded.

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

**Two distinct non-resolutions, and this rule governs only the first.** A
reviewer checked `.claude/hooks/openspec-change-gate.sh` against this requirement
and found it failing **closed** — `exit 2` — with a long comment defending the
choice. Read precisely, that file separates two conditions this requirement had
collapsed into one:

- **The implementation is absent.** Tooling is not installed. The file allows and
  reports, which is what this requirement mandates. (It exits `0` rather than a
  non-blocking error code, so it is non-conformant on the *exit code* — a real
  finding, and one this change fixes under task 4b.2.)
- **The binder cannot determine where to look.** The root is unresolvable, so the
  hook cannot tell an absent implementation from one sitting beside it. That
  file fails **closed**, on the stated reasoning that an edit must not be
  reported as gated when the gate could not be located.

The second condition is **scoped out of this requirement**, with the reason
recorded here as the "rules bind every fleet-shared hook" requirement demands.
Fail-open is justified by the blast radius of blocking on a *missing optional
file*; it is not justified for a binder that has lost track of its own
repository, where allowing means silently ungating edits in a repo whose gate is
present and working. A binder MAY fail closed on an unresolvable root, and SHALL
document that it does. What it SHALL NOT do is fail closed on a merely absent
implementation.

The distinction was found by review rather than by this capability, which had
one rule where the fleet already had two.

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
of the change gate is absent. That is not a regression — the gate shim already
fails open, silently.

**What that actually loses, stated against the gate's real behaviour.** An
earlier revision said "§18's review requirement is advisory at the tool boundary
until the installer has run", and similar phrasing appeared wherever this
capability described a missing or overridden gate. A reviewer showed it is stale
against `change-gate-enforcement`, which is explicit: the gate blocks on exactly
one condition — `openspec validate --all` is not green — while the reviewer
count, the verdict grammar, reviewer independence, the trailer format and the
binding of a review to what it reviewed are computed and **reported, never
enforced**. So an absent gate loses two things, neither of them a review
requirement:

1. **validation enforcement** — the only condition on which the gate blocks; and
2. **the reporting** of review state, which was advisory before the gate went
   missing and is merely absent after.

Calling the loss "review enforcement" names a block the gate does not perform,
and passes over the one it does. Every statement in this capability about what a
missing, unresolvable or overridden gate costs SHALL be written against the
blocking condition.

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

#### Scenario: A shim's event class has no verified warning channel

- **WHEN** a shim is written for an event class whose channel this capability has
  not recorded as verified
- **THEN** it is described as failing open with its reporting channel
  unestablished, and no report of it claims the operator is warned

#### Scenario: A machine stays unprovisioned for a long time

- **WHEN** every matched tool call resolves nothing, session after session
- **THEN** the shim's stated repetition policy governs how often the operator is
  told, and the policy is recorded with the hook rather than left to whatever the
  implementation happens to do

#### Scenario: The installer runs

- **WHEN** the shared artifacts are installed
- **THEN** the installer verifies each shimmed implementation is present and
  executable, and fails visibly if one is not

### Requirement: A machine's provisioning is a triple, not a state name

**A machine's provisioning is reported on three independent axes, not as one list
of states.** A reviewer found the capability asserting, under publication, that
"no project binds a hook whose implementation is absent", while the
clone-before-install scenario below explicitly permits exactly that. Both
sentences were true of different conditions and neither said which, so the pair
read as a contradiction.

A previous revision answered that with a flat list of four states — unprovisioned,
partially provisioned, provisioned, drifted — and a reviewer showed the list is
**not mutually exclusive**: a manifest whose files are all absent is both
unprovisioned *and* drifted, and one unattested file beside one missing file is
both partially provisioned *and* drifted. A machine cannot be "in exactly one" of
a set whose members overlap. The things being conflated are **how much is
installed**, **whether what is installed can be attested**, and — added later,
after a machine was described as provisioned while running builds three fixes
behind — **whether what is installed is still what the authority ships**. All
three vary independently:

| Axis | Values | Observable definition |
|---|---|---|
| **Completeness** | `none` / `partial` / `complete` | how many shimmed implementations are present and executable: none of them, some of them, all of them |
| **Integrity** | `attested` / `drifted` | `attested` when every present implementation matches a manifest row; `drifted` when any present implementation's bytes disagree with its row, any row names an absent file, or any present implementation has no row |
| **Currency** | `current` / `stale` / `unknown` | judged over the **declared** artifact set only. `current` when every declared, present implementation is byte-identical to the authority's file **as it exists on disk at the time of the check**; `stale` when any differs, or the authority holds no file for a declared, present artifact; `unknown` when the authority cannot be read or is not an authority checkout |

**Currency is a third axis and not a value on either of the others**, for the
reason completeness and integrity were split from each other. Both of those are
computed from the machine alone: completeness asks how much is installed,
integrity asks whether what is installed still matches what was installed. Neither
can ask whether what was installed is still what the authority ships, because the
manifest records a publication that already happened. A machine can therefore be
`complete` + `attested` against a stale row indefinitely.

This was found by its consequence, not predicted. On 2026-08-03 a machine
reported `complete` + `attested` — "This machine is provisioned. The shims will
resolve." — while running `normalize-claude-md` 1.0.0 against core's 1.0.1 and
`database-sentinel` 1.0.0 against core's 1.1.0. Measured on the published copies:
`CLAUDE.md` went 0644 in and **0600** out, and `DELETE FROM public.users` was
**not** blocked. Both are defects the fleet believed were fixed. The check printed
`attested v1.0.0` throughout; the number was on screen and nothing compared it to
anything.

`stale` and `drifted` are deliberately **not** merged. They have different causes
and different remedies: `drifted` means a published file was edited or replaced
and the remedy is to investigate, `stale` most often means the machine did
exactly what it was told and the world moved on. Reporting both as `drifted`
would train an operator to answer every occurrence by re-running the installer,
which is the wrong response to real tampering — and, per the `stale` invariant
below, is also the wrong response to several kinds of staleness.

A machine's state is the **triple**. `none` + `drifted` is the all-files-deleted
case that broke the flat list, and it is now expressible: nothing is installed
*and* the manifest still claims otherwise, which is a different remedy from a
clean fresh clone. The vocabulary maps onto the old names where they were
unambiguous — *unprovisioned* is `none`+`attested`+any currency (no rows, no
files, so nothing to be stale), *provisioned* is `complete`+`attested`+`current`
— and those names MAY be used as shorthand for exactly those triples, never as a
classification in their own right. **`complete`+`attested`+`stale` is not
"provisioned"**, and calling it that is the specific error this revision exists
to stop.

The rule that a project must never bind a missing implementation applies to the
**provisioned** state only. It is a post-condition of a completed install, not a
property of the fleet at all times — which is what made it look like it
contradicted a usable fresh clone.

Invariants attach to a value on one axis, never to a state name:

- **`none`** — shims resolve nothing, report, and allow. Binding a hook whose
  implementation is absent is **expected and permitted**; it is what a fresh
  clone is.
- **`partial`** — each present implementation is complete rather than truncated.
  Mixed is legal; torn is not.
- **`complete`** — every shimmed implementation is present and executable.
- **`attested`** — every present implementation matches its row. This says the
  published bytes are the bytes that were published; it says nothing about
  whether those were the right bytes to publish.
- **`drifted`** — the check reports the specific disagreement and its direction,
  and SHALL NOT resolve it silently.

**All three axes are computed from what is on disk, never from what happened.** The
previous revision defined *provisioned* as "a publishing run completed" and
*partially provisioned* as "a publishing run was interrupted". A reviewer showed
that history is not evaluable after the fact — nothing on the machine records
it — and, worse, that a completed install later deleted, hand-edited, replaced
or half-removed classified as **provisioned** under that definition. That is
precisely the condition the manifest check exists to detect, and the state table
was the one place it could not be named.

#### Scenario: A project is cloned before the installer runs

- **WHEN** a project is cloned onto a machine where the installer has never run
- **THEN** the project is usable, every shimmed hook reports itself missing, and
  no protection is claimed that is not running

### Requirement: Currency is judged against an authority checkout

**Currency names a comparison the tooling already performs.** `--source-check`
compares each executed copy against the maintained implementation and its own
header states the case: *a machine can be perfectly attested against a manifest
that published last month's implementation.* What was missing is a **verdict**.
The comparison reported findings into a separate block, the summary was computed
without it, and so the tool printed "This machine is provisioned. The shims will
resolve." while that block read `DIFFERS` on every project hook. Reproduced. An
axis is what obliges the summary to agree with the comparison.

**The declared set, and nothing else.** The shared bin also holds artifacts
published by a different installer — the change gate, the reviewer CLI, the plan
review runner — which this manifest already reports as "not covered". They SHALL
NOT be judged for currency, and "the authority holds no such file" is a finding
only for an artifact this manifest declares. Stated because the opposite was
tried: an earlier revision of this delta made an absent authority file `stale`
without scoping it, and running it flagged three artifacts that were correctly
outside scope.

**The authority is a checkout, not a branch.** Currency is evaluated against the
content on disk in the authority path when the check runs — never against core's
`main` and never against any remote, because the check reads files and cannot
know what a branch elsewhere contains. A design implying otherwise would promise
something unimplementable.

The consequence is normative rather than hidden: **a stale checkout of the
authority yields a stale reading**, and that is the check being right about the
disk rather than wrong about the world. Currency against a *branch* is a
different question, answered by comparing `git show <ref>:<path>` — which is what
the fleet's own contract propagation used as its durable check.

Invariants on the currency axis:

- **`current`** — every **declared**, present implementation is byte-identical to
  the authority's file as it exists on disk when the check runs. It licenses the
  claim *"matches this authority checkout"* and never *"matches what core
  ships"*: an authority checkout that is itself behind agrees with an equally
  behind install, and the pair reports `current`. That limit SHALL be stated
  wherever the verdict is, rather than left for a reader to deduce — an
  unqualified `current` here would recreate, one level up, the false green this
  axis exists to remove.

- **`stale`** — the check names each artifact and SHALL name a remedy **chosen
  for that condition**. It SHALL name both versions and the direction **where
  both are readable**, and SHALL say the version could not be read rather than
  inventing one where either side carries no parseable marker; the verdict stands
  on bytes in both cases. The conditional matters because an authority file
  without a marker makes the unconditional form unimplementable, and a
  requirement that cannot be met is one an implementation quietly reinterprets.
  A single universal remedy is forbidden because it is wrong in most of them:
  re-running the
  installer cannot clear a published version *ahead* of the authority, since the
  installer refuses downgrades; cannot fix an authority checkout that is itself
  behind; and destroys evidence when a machine is `drifted` and `stale` at once.
  Direction is compared **component-wise numerically**, never lexically —
  a lexical compare places `1.10.0` below `1.9.0` and would point the operator at
  the opposite remedy.

- **`unknown`** — reported per its sub-cases, so that an unasked question is never
  dressed as a finding: the authority path is absent or unreadable; the path
  exists but holds no declared artifact at all, meaning it is not an authority
  checkout and reporting every artifact `stale` would be confidently wrong; or an
  individual file cannot be read, a failed read being distinct from a difference;
  or the comparison itself fails, which is likewise distinct from the two files
  differing and SHALL NOT be reported as a difference.
  Aggregation: any `stale` makes the machine `stale`, otherwise any `unknown`
  makes it `unknown` — a known finding outranks an unasked question.

  **Currency is judged over the declared artifacts that are PRESENT.** An
  artifact that is absent from the machine is completeness's finding and SHALL
  NOT also be reported by this axis, whether or not the authority holds it —
  reporting one fact on two axes is what made the flat four-state list
  unusable. The consequence is that `current` holds vacuously when nothing
  declared is installed, which is correct and harmless: the licence requires
  `complete` as well. It SHALL NOT install anything: this capability's
  tools report and the installer installs, and a check that silently rewrote the
  shared bin would be doing the one thing `drifted` is forbidden to do.
  `unknown` SHALL NOT be reported as `current`. A result is a statement about
  what was checked, never about the machine — the same rule the override scan
  follows when it reports *no known vector found* rather than *no override is
  set*. The report SHALL name the path it looked for and which question went
  unanswered, so an operator can tell an ordinary condition from a broken one.

**The licence to describe the fleet's protections as running as documented
requires `complete` + `attested` + `current`, and no other combination grants
it.** It previously attached to `attested` alone. That was too strong and was
observed to be false: a machine held `complete` + `attested` while running two
implementations missing three landed fixes, and was described as provisioned
throughout. `unknown` does not grant the licence either — an unchecked claim and
a verified one must not read the same.

**A strict mode SHALL fail on any currency value but `current`, `unknown`
included, and SHALL offer no flag that exempts it.** Declining to ask the
question and demanding a clean strict result are contradictory, and the
contradiction SHALL resolve as a failure rather than as a pass — an opt-out that
produced a green strict run would restore, in one flag, precisely the silent
pass this axis exists to remove. Two flags that contradict each other outright —
naming an authority while declining to consult one — SHALL be a usage error
rather than resolved by order of appearance, because last-one-wins silently
performs the opposite of half the instruction it was given.

#### Scenario: The installed build is older than the one the authority ships

- **WHEN** every declared implementation is present and matches its manifest row,
  but one of them differs from the authority's tracked source
- **THEN** the machine is `complete` + `attested` + **`stale`**, the check names
  that artifact with both versions and the direction, and the machine SHALL NOT
  be described as provisioned or as running its protections as documented

#### Scenario: The authority is not reachable from the machine

- **WHEN** the check runs where the authority's tracked source is not present
- **THEN** currency is reported `unknown` rather than `current`, and the licence
  to describe the protections as running as documented is withheld — an
  unchecked claim and a verified one must not read the same

#### Scenario: The versions agree and the bytes do not

- **WHEN** a present implementation's version marker equals the authority's while
  its bytes differ
- **THEN** it is reported `stale` and the report says the versions agree while the
  bytes do not, because that is a build error or a hand-edit rather than the
  ordinary lag a lower version indicates

#### Scenario: The comparison reports a difference and the summary does not

- **WHEN** the source comparison reports that an executed copy differs from the
  maintained implementation
- **THEN** the machine's summary SHALL reflect it. Reproduced before this
  revision: the comparison printed `DIFFERS` for every project hook while the
  summary printed "This machine is provisioned. The shims will resolve.",
  because the finding fed a separate block and no verdict

#### Scenario: The stronger question is never asked

- **WHEN** the currency comparison does not run
- **THEN** the report says which question went unanswered, and the summary does
  not read as it would had the question been asked and answered. A comparison
  that is optional and silently skipped is indistinguishable from one that passed

#### Scenario: The authority checkout is as old as the installation

- **WHEN** the authority checkout and the installed copies are equally behind, so
  they agree
- **THEN** the verdict is `current` **qualified as matching this authority
  checkout**, and SHALL NOT be stated as matching what the project ships — the
  check reads a checkout and cannot see a branch

#### Scenario: The authority holds no such artifact

- **WHEN** a **declared and installed** artifact has no counterpart in an
  authority that does hold other declared artifacts — the checkout predates it,
  or it was renamed upstream
- **THEN** it is reported `stale` with its own message and its own remedy, **not
  `unknown`**: the authority was reached and holds the rest, so "this one is not
  in it" is a finding rather than an inability to check
- **AND** a declared artifact that is absent from the machine *and* from the
  authority is **not** judged for currency at all — completeness already reports
  it, and a second report on a second axis says nothing new
- **AND** an artifact the manifest does not declare — one published by a
  different installer into the same directory — is **not** judged at all, because
  the authority was never expected to hold it

#### Scenario: The machine carries a build ahead of the authority

- **WHEN** a present implementation's version marker is higher than the
  authority's
- **THEN** it is reported `stale` in that direction — the machine holds a build
  the authority cannot account for — rather than passed as newer-and-fine, for
  the same reason a shim marker ahead of the template is `unrecognised`

### Requirement: Provisioning is checked per machine, not only per repository

Every check this capability requires elsewhere is evaluated against a
**repository** — shim markers, byte-identity within a profile, the
override-provenance scan. None of them can observe whether the machine executing
those shims holds the implementations. A conformance check SHALL therefore report
the **machine's** provisioning state, computed observationally per the state
table above, independently of any repository check.

A reviewer found the gap by its consequence, which is a real regression this
capability introduces. Before it, `database-sentinel` ran on any clone with zero
provisioning, because the implementation was in the repository. After it, the
protection exists only where the installer has run — and **every existing
developer machine enters the unprovisioned state at the moment it pulls the
shim**, through an ordinary `git pull`, with no step that would prompt anyone to
notice. The change trades a protection that travelled with the repository for one
that travels with the machine, and only the second needs a check that did not
previously have to exist.

The rollout ordering — publish and verify before replacing project copies —
orders exactly **one** machine: the one performing the rollout. It says nothing
about any other machine that later pulls the result, and SHALL NOT be cited as
though it did.

A rollout SHALL move a machine to *provisioned* before any project's copy is
replaced with a shim, because that ordering is what keeps the window in which a
project has a shim but no implementation from being entered deliberately.

#### Scenario: A machine pulls the shim without running the installer

- **WHEN** a developer pulls a project after its copies have been replaced with
  shims, on a machine where the installer has never run
- **THEN** that machine is unprovisioned and reports as such under the
  per-machine check — rather than the condition being invisible because every
  repository-level check passes

#### Scenario: The rollout ordering is offered as fleet-wide assurance

- **WHEN** publish-before-replace is cited as evidence that no binder is left
  without an implementation
- **THEN** the claim is limited to the rollout machine, and the per-machine check
  is what covers every other one

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

**Accepted is not the same as unmitigated, and the previous revision stopped at
"accepted".** A reviewer observed that the capability names an
arbitrary-code-execution concentration point and then specifies nothing about who
may write to it — no ownership, no permission bits, no symlink handling — while
requiring an unsigned digest check whose whole value depends on the directory not
being writable by anyone who fancies it. Four requirements, all cheap, all
checkable by the conformance tool that already exists:

- **Ownership** — the shared install directory and every published artifact SHALL
  be owned by the user executing the hooks. A published artifact owned by another
  user SHALL be reported, not executed silently.
- **Permissions** — neither the directory nor any artifact SHALL be group- or
  world-writable. A group-writable shared directory makes every member of that
  group an author of every hook in every project on the machine.
- **Symlink-safe publication** — the installer SHALL write the temporary file and
  `rename` within the destination directory, and SHALL NOT follow a symlink at
  the destination path. Publishing through a symlink writes wherever the symlink
  points, which relocates the concentration point without moving the check.
- **The manifest is covered by the same three rules**, because a digest record an
  attacker can rewrite is the limitation this capability already admits, and
  leaving its file mode unspecified widens it for no reason.

None of this makes the directory a security boundary — the drift-detection
disclaimer above still stands, and a user who can write their own files can
still change what all seven projects enforce. It removes the cases where somebody
*else* can.

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
3. **it does not enforce a gate by any means** — checking a gate's required
   evidence is one way to enforce one, and is not the only way. A hook also
   enforces a gate when it gates on a **proxy** for the evidence (a sentinel
   file, a marker, a naming convention), on a **result** from elsewhere (an API
   response, an exit status, a CI verdict), or on any other condition that
   stands in for the gate being satisfied — and when anything that does one of
   those depends on it.

   A reviewer showed the previous wording ("neither checks a gate's required
   evidence nor is depended on by anything that does") still tested one
   mechanism. A hook enforcing `design-shotgun` by checking a sentinel rather
   than the rendered variants would clear that test while being the gate's only
   enforcement. The scenario below acknowledged exactly this case and added no
   operative test; clause 3 now carries one. The question is **"does this hook
   make some gate harder to pass?"**, asked of any mechanism, not "does it read
   the named artifact".

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

**Broadening clause 3 changes the argument for one deletion in this change, and
that is recorded rather than absorbed.** A hook that gates on a sentinel standing
in for a gate's evidence now *does* enforce that gate, by the clause above. So
"it checks a sentinel §02 never names" no longer clears such a hook for deletion
— it convicts it. What clears it instead is **unreachability**: when no surviving
tool can write the sentinel, the check can never pass, and a condition that can
never be satisfied does not enforce a gate. It blocks unconditionally, which is a
different thing and is argued under the unreachable-gate requirement below.

The distinction matters because the two arguments have different lifetimes. "Not
the named evidence" would license deleting a *working* proxy enforcement.
"Unreachable" licenses deleting only one that cannot fire. A deletion resting on
the first SHALL be re-argued on the second.

#### Scenario: A hook checks a sentinel that is not the gate's evidence

- **WHEN** a hook gates on a file that §02 does not name as that gate's required
  evidence artifact
- **THEN** that fact alone does not settle the enforcement clause — and, under
  clause 3, points the other way: a sentinel is a proxy, and gating on a proxy is
  enforcement. The hook is cleared only if the proxy is **unreachable**, not
  because it is unnamed

#### Scenario: A hook enforces a gate without reading its evidence

- **WHEN** a hook makes a gate harder to pass by checking a marker, an exit
  status, an API result, or any condition standing in for the evidence
- **THEN** clause 3 fails and the hook SHALL NOT be deleted without a delta,
  regardless of whether it ever opens the artifact the gate names

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

**The declared coverage is stated here.** It was previously kept in a separate
declaration file read by one tool; that tool was retired on 2026-08-04 and the
file went with it, because a declaration whose only reader is gone is data that
looks maintained and is not.

| Hook | Event | Matcher |
|---|---|---|
| `database-sentinel` | `PreToolUse` | `Bash\|Edit\|Write\|MultiEdit` |
| `openspec-change-gate` | `PreToolUse` | `Edit\|Write\|MultiEdit\|NotebookEdit` |
| `normalize-claude-md` | `PostToolUse` | `Edit\|Write\|MultiEdit` |

A registration is **conformant** when it names the declared event and covers the
declared tool set; **narrow** when it omits any declared tool; **wider** when it
adds tools beyond it; and **absent** when no entry names the hook at all. Narrow
and absent are defects. **Wider is acceptable** — a project may guard more than
the fleet requires, and treating that as non-conformant would push projects
toward removing coverage.

**NOTHING CHECKS THIS, AND THAT IS THE DELIBERATE STATE.** A previous revision
required a conformance tool to evaluate every declared hook in every scanned
project, on the argument that "a requirement with no check makes nothing
detectable". That argument is correct and it is not free: acted on, it produced
an instrument of nearly two thousand lines against the three hundred it
measured, and six of the eight changes archived in the following week were
repairs to the instrument rather than to the fleet. The check is withdrawn and
the cost of withdrawing it is stated rather than hidden:

- A narrow or absent registration is **not** detected. It surfaces when the hook
  does not fire, which is how the defect below was found in the first place —
  before any check existed and by a person, not a tool.
- The failure is real and has happened: five repositories registered
  `database-sentinel` on `Bash|Edit|Write` against a declared
  `Bash|Edit|Write|MultiEdit`, so a `MultiEdit` to a `.env` file invoked nothing.
  Protection absent rather than degraded, and every axis then in existence
  reported those repositories clean.
- The event that can invalidate a registration is a change to an
  implementation's tool coverage. The scenario below already requires such a
  change to update every project's matcher and verify it **per project**. That
  obligation sits on the change, where the knowledge is, rather than on a
  standing instrument.

A future revision may reinstate a check. If it does, it SHALL be reinstated as
a check and not as a capability: a comparison inside an existing script, with no
requirements of its own to be defective in.

**An absent registration is the strongest form of this defect**, not a lesser one.
A hook registered nowhere is one whose every tool is inert — protection absent
rather than degraded — and it is reachable by exactly the edit a contract rollout
performs: rewriting a project's `settings.json`. Treating the narrowed case as
serious while a hook wired to nothing passes unremarked inverts the severity this
requirement already distinguishes, and it is the absence-reads-as-clean shape
ruled out for shim files two requirements above. **Whoever rewrites a
`settings.json` SHALL confirm the hook is still named in it**, which is the whole
of what the retired check did for this case.

A hook a project has **declared** it does not bind is exempt: for it, no
registration is the correct state, and reporting it would leave the opt-out
declaration meaning nothing on this axis.

#### Scenario: A shared implementation gains a tool

- **WHEN** a canonical implementation handles a tool some projects' matchers omit
- **THEN** those projects' matchers are updated in the same change, and the
  update is verified per project rather than assumed

#### Scenario: A tool named in a matcher no longer exists on the host

- **WHEN** a matcher or implementation covers a tool the host no longer provides
- **THEN** the coverage is harmless but inert, and SHALL NOT be reported as a
  delivered protection

#### Scenario: A declared hook is registered nowhere

- **WHEN** a project's settings name no entry for a hook it is declared to bind,
  while its shim file is present, current and byte-identical to the authority
- **THEN** that project is **not bound** for that hook, and the shim's presence,
  currency and byte-identity SHALL NOT be read as coverage — three green facts
  about a file that never runs

#### Scenario: A registration is narrower than the declared coverage

- **WHEN** a project registers a hook on fewer tools than the table above names
- **THEN** the tools it omits are unprotected in that project, and the
  registration is corrected rather than the declaration relaxed

#### Scenario: A registration is wider than the declared coverage

- **WHEN** a project registers a hook on tools beyond the declared set
- **THEN** that is acceptable and is not a defect, because a project may guard
  more than the fleet requires

#### Scenario: A project has declared it does not bind the hook

- **WHEN** a hook is declared as a project's opt-out and that project registers
  no matcher for it
- **THEN** no registration is the correct state for it, on the same terms the
  absent-shim rule applies to the same declaration

#### Scenario: The registration cannot be read

- **WHEN** the settings file is absent, does not parse, or cannot otherwise be
  read
- **THEN** nothing about that project's coverage has been established, and
  whoever could not read it SHALL say so — "not read" is a different statement
  from "read and correct", and it stays different when the reader is a person

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
the two named in this change does NOT end the violation.** Observed on the
author's machine on **2026-08-02**: `agenticapps-workflow-core` holds **29** files
under `.planning/skill-observations/`, **all 29** named
`<stamp>--<sessionId>.{md,jsonl}` and **none** matching `skill-router-{date}.jsonl`,
in a repository carrying **no `.planning`-writing project hook** — no
`.claude/hooks/` directory at all when first measured, and since 2026-08-02
exactly one `PreToolUse` change gate, which writes nothing there. That naming is
a *global* `SessionEnd` hook registered in `~/.claude/settings.json` running
`agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`, whose own
header states it "writes
`<projectRoot>/.planning/skill-observations/<stamp>--<sessionId>.{md,jsonl}`".

**These are dated single-machine observations, not measurements of the
repository, and SHALL be read as such.** A reviewer re-ran the count and got
different numbers from the ones a previous revision recorded (141 total, 137
`<stamp>--<sessionId>`, 4 `skill-router-*`), which is how the framing defect
surfaced: the directory is **gitignored local state**, so it differs per machine,
changes every session, and no reviewer can reproduce a figure from it. Citing it
as though it were a property of `agenticapps-workflow-core` invited exactly the
contradiction that followed. What the observation supports is the **ratio and its
direction** — a repository with no `.planning`-writing hook accumulating such
files anyway — and that conclusion is now stronger than when it was first drawn,
the non-hook producer accounting for 29 of 29 rather than 137 of 141.

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

### Requirement: The implementation version marker is compared, not merely carried

This capability defines two version markers and requires a comparison for one of
them. `# shim-contract:` has a defined format, a named authority, a comparison
rule and a check. `# <hook>-version:` was defined alongside it — format, authority
in the tracked file in core, bumped on any behaviour change — and **no check ever
read it against that authority.** The installer reads it, only to refuse
overwriting a higher published version.

That is this capability's own argument left unapplied to its own second marker: a
marker with no check makes nothing detectable, and the marker's purpose is
discharged by the report existing rather than by the marker being present.

A conformance check SHALL therefore compare every present implementation against
the authority's tracked source and report the result, by artifact name.

- **Authority** — the implementation file under
  `reference-implementations/project-hooks/` in core, **as it exists on disk in
  the authority path when the check runs**. No published copy and no manifest row
  is authoritative for its own currency, for the same reason no project-local
  shim is authoritative for its own conformance. The authority is a checkout: if
  it is old, the reading is old, and the check is reporting the disk correctly.
- **Comparison** — byte-identity against the authority's file, with an absent
  authority file reported `stale` in its own right rather than skipped. The version
  markers supply the *message*, never the verdict: a file whose bytes differ while
  its marker matches is exactly the case a version-only comparison cannot see, and
  it is the case that was already caught once for shims, where a marker attested
  a string about the file rather than the file.
- **Report** — each stale artifact named with both versions, the direction, and
  the remedy. A check that detects a condition without naming how to clear it is
  a check operators learn to ignore.

#### Scenario: A published implementation is compared against the authority

- **WHEN** the per-machine check runs with the authority reachable
- **THEN** every present implementation is compared to the authority's tracked
  source and its currency is reported by artifact name, rather than the marker
  being printed with nothing to compare it against

#### Scenario: The check is asked to fix what it found

- **WHEN** a stale implementation is reported
- **THEN** the check names the remedy **for that condition** and does not run it
  — this capability's tools report and its installer installs, and a check that
  rewrote the shared bin would resolve silently what it is required to surface
- **AND** where that remedy is the installer, naming it is still not running it;
  where it is not the installer — a published version ahead, a lagging authority
  checkout, or `drifted` and `stale` together — the installer SHALL NOT be named.
  An earlier revision of this scenario said the check "names the installer as the
  remedy", contradicting the `stale` invariant above in the same delta

### Requirement: A non-zero exit always carries a message

A shim SHALL NOT exit non-zero having written nothing to stderr. The exit code
and the message are one signal, not two: this capability requires a non-blocking
error code **because** it is the only thing that surfaces stderr to the operator,
so an exit code with no accompanying line invokes the mechanism and supplies
none of its content.

**This binds the shim's own exits, before `exec`, and no others.** Once a shim
`exec`s, the process is the implementation and its exit code is the
implementation's to choose; a shim that tried to constrain it would have to stop
`exec`ing and start wrapping, which the behaviour-free rule forbids. A stderr
write that itself fails is likewise outside the rule — the shim SHALL attempt the
line, not guarantee its delivery through a broken descriptor.

**It binds an event class only where that class's channel is verified.** This
capability records a verified warning channel for `PreToolUse` and requires the
exit rule to "be re-established per event class, not assumed to generalise". The
invariant is argued from `PreToolUse` rendering — a non-zero exit surfacing the
first stderr line — so it is claimed for `PreToolUse` and for any class whose
channel is later verified and recorded. For a class whose channel is unverified,
`normalize-claude-md`'s `PostToolUse` being the live instance, a shim SHALL still
write its line before exiting non-zero, and no report SHALL claim the operator
sees it. Writing the line costs nothing and is what makes the claim available the
day the channel is verified; claiming the operator was warned is what this
capability forbids.

The host renders such a call as `hook error — No stderr output`. That notice
costs the operator exactly what a real report costs — it interrupts, it names a
hook, it implies something is wrong — and returns nothing they can act on. It is
strictly worse than either alternative: worse than reporting, which at least
says what broke, and worse than silence, which at least does not interrupt.

This is stated as an invariant rather than as a fix to one code path because it
binds every future report a shim learns to make, including ones whose rate
limit, filter or guard has not been written yet. The rule is: **whatever
suppresses a report SHALL also be asked what the exit code should be**, and the
answer SHALL NOT be "leave it non-zero and say nothing".

#### Scenario: A report is suppressed but the call still fails to resolve

- **WHEN** a shim on an event class with a verified channel suppresses the full
  report for a call whose implementation is still unresolvable
- **THEN** the shim writes at least one line to stderr before exiting non-zero,
  so the operator sees a notice that names the hook and its state rather than an
  empty one

#### Scenario: The suppressed line is written for an unverified class

- **WHEN** the same condition arises on an event class whose channel is not
  verified
- **THEN** the line is still written and the exit code is still non-zero, and its
  wording states only what is true of that class — for a `PostToolUse` hook, that
  the hook did not run, never that a call "was allowed", since the call has
  already completed and nothing was gated

#### Scenario: A shim is audited for contentless exits

- **WHEN** a shim's pre-`exec` exit paths are enumerated
- **THEN** every path that exits non-zero is shown to write at least one stderr
  line first

#### Scenario: An exit path has nothing to say

- **WHEN** a pre-`exec` path would exit non-zero with nothing to report
- **THEN** it exits 0 **only if** it carries no announcement obligation — a path
  that fails open and loses protection SHALL be given a message rather than a
  zero exit, because exit 0 discards stderr entirely and converts the announced
  fail-open into the silent one this capability rejects

#### Scenario: The class's channel is not verified

- **WHEN** a shim binds an event class for which no warning channel is recorded
- **THEN** it writes its line and exits by the contract anyway, and every report
  of it says the channel is unestablished rather than that the operator was
  warned

#### Scenario: A resolution candidate exists but cannot be executed

- **WHEN** a path a shim resolves is present but is not an executable regular
  file — a directory, a device, or a non-executable file — on **any** candidate,
  not only the override
- **THEN** the shim reports it in its own words and exits by this contract,
  rather than `exec`ing it and letting the interpreter's own failure stand as the
  report: `exec` on a directory yields exit 126 and a message naming the path but
  neither the hook nor the fact that the call was allowed, which is the
  contentless exit this requirement forbids wearing a different exit code

  The rule was previously stated of the override alone. `-x` is true of any
  searchable directory, so the bare test admits exactly the case it looks like it
  excludes, and stating the rule of one candidate left the other holding the
  defect the first was repaired for.

  A candidate that is present but unusable SHALL be reported as **occupied**
  rather than as absent. "Not installed" is false of a path something occupies,
  and it sends the operator to the installer when the remedy is to find out what
  is sitting there.

### Requirement: A rate limit governs verbosity, not the operator's notice

A repetition policy of **once per interval** SHALL reduce what a suppressed
report says, not whether it says anything. On a call inside the suppression
window the shim SHALL emit a single line naming the hook and its unchanged
state, and SHALL retain the exit code the unsuppressed report would have used.

The reason is that the two halves of the report are not equally suppressible. The
message can be shortened at no cost to the guarantee; the exit code cannot be
withheld without converting an *announced* fail-open into a silent one, which is
the posture this capability rejected when it rejected fail-closed. A policy
written as though both were suppressible produces neither outcome: it suppresses
the half that carries meaning and keeps the half that carries only interruption.

**The saving a once-per-interval policy actually delivers is therefore verbosity,
and it SHALL be described as that.** It does not reduce how often the operator is
interrupted, because the exit code interrupts on every matched call regardless.
An interval policy that claims to reduce frequency is claiming a saving the exit
code takes back.

A shim MAY still choose **per invocation** and repeat the full report. What it
SHALL NOT do is claim an interval policy and deliver a contentless notice for the
rest of the interval.

**The suppressed line SHALL carry four things**, so that "a line was written" is
not discharged by a line that says nothing: the hook's name, that the condition
is unchanged, that the call was allowed, and a reference to the full notice
already made. A suppressed line that merely repeats the first line of the full
report is non-conformant — the operator could not then tell a repeat from a fresh
failure, which is the one fact the suppressed line exists to add.

**The interval SHALL be described in the units the marker actually keeps.** A
marker holding `epoch/3600` is a wall-clock **hour bucket**, not a rolling hour:
two calls four seconds apart can fall in different buckets and both report in
full. The suppressed line SHALL therefore say *this hour* rather than imply a
rolling window, and any documentation of the policy SHALL do the same.

**The report SHALL be emitted before the marker is written**, so that a failure
between the two leaves the next call reporting in full rather than claiming a
notice nobody received. Ordering it the other way makes the suppressed line's
reference to an earlier notice a claim the shim cannot support.

**A report that could not be recorded SHALL NOT suppress the next one.** The rule
binds the *recording* step, not the reading one: if the state directory or the
marker file cannot be written after a full report, the next matched call reports
in full again, because suppressing on the strength of a write that failed
suppresses on a state that was never recorded.

Where a marker was written successfully and *later* becomes unreadable or
unwritable, the shim suppresses on what it can read and attempts no write, which
is correct — it is acting on a record that exists. The distinction matters
because the two cases look identical at the call site and only one of them is a
lie.

#### Scenario: A second unresolvable call arrives within the interval

- **WHEN** a shim reported in full earlier this hour and matches another call
  whose implementation is still unresolvable
- **THEN** it emits one line naming the hook, stating that the condition is
  unchanged and that the call was allowed, referring to the full notice already
  made, and exits with the same non-blocking code

#### Scenario: The report is emitted but recording it fails

- **WHEN** a full report is written and the marker write then fails
- **THEN** the next matched call reports in full again, rather than suppressing
  on the strength of a record that was never made

#### Scenario: An existing marker is readable but the path is no longer writable

- **WHEN** a marker written earlier this hour is read on a later call and no
  write is attempted
- **THEN** the call is suppressed normally, because the shim is acting on a
  record that exists

#### Scenario: An interval policy is described in a report or document

- **WHEN** the effect of a once-per-interval policy is stated
- **THEN** it is stated as a reduction in verbosity, not in how often the
  operator is interrupted, because the exit code is not subject to the interval

