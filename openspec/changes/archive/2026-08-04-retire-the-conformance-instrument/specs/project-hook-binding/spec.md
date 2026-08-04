## REMOVED Requirements

### Requirement: An absent shim is a finding, not a silence

**Reason**: This requirement specifies the reporting behaviour of
`tools/project-hook-conformance.sh`, which this change deletes. Every sentence in
it is about how an instrument counts — what it reports as a finding, what it
passes over, and how a declared opt-out is distinguished from a deletion. With no
instrument there is nothing for it to bind.

The migration it exists to protect completed on 2026-08-02: all seven declared
repositories bind all three shimmed hooks, byte-identical to the authority, and
the check that established that is being replaced by a 40-line script run by hand
after a contract bump. The requirement's substantive claim — that an absent shim
must be visible rather than skipped — survives as behaviour of that script, which
prints one line per (repository, hook) and exits non-zero on a missing or drifted
shim.

**Migration**: None for any consumer. `reference-implementations/project-hooks/OPT-OUTS`
is retained as a plain declaration the replacement script reads, so the one live
opt-out (`agents-task-viewer`/`normalize-claude-md`) is still reported as an
opt-out rather than as a missing file. No other tool, template or host reads this
requirement.

### Requirement: The authority's own binder is scored, never assumed

**Reason**: This requirement exists because `--fleet` structurally excluded core,
so a fleet-wide zero could be quoted as covering a repository it could not
contain. The replacement script has no fleet mode and no exclusion: it takes core
and the declared repositories in one list and prints a line for each, so the
condition this requirement guards against cannot arise in the tool that replaces
the one it governed.

The concrete defect it records — that at contract 1.1.0 core's own binder failed
open by exiting 0 with a warning on stderr, where a `PreToolUse` hook's stderr is
discarded — is a fact about the *shim contract*, and the requirements that govern
it ("A shim that resolves no implementation allows the call and reports it") are
untouched by this change.

**Migration**: None. Core is included in the replacement script's default target
list, which is the mechanism rather than the prose that keeps it scored.

## MODIFIED Requirements

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
