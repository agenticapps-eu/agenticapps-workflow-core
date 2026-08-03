## MODIFIED Requirements

### Requirement: An unresolvable shim allows, and the operator sees it

A shim that resolves no implementation SHALL allow the tool call and SHALL make
the failure visible in the session transcript, naming the missing implementation
and the installer that provides it.

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
| **Currency** | `current` / `stale` / `unknown` | `current` when every present implementation is byte-identical to the authority's file **as it exists on disk at the time of the check**; `stale` when any present implementation differs from it or the authority holds no such file; `unknown` when the authority path itself is not reachable |

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
and the remedy is to investigate, `stale` means the machine did exactly what it
was told and the world moved on, and the remedy is one command. Reporting both as
`drifted` would train an operator to answer every occurrence by re-running the
installer, which is the wrong response to real tampering.

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
- **`current`** — every present implementation is byte-identical to the
  authority's file as it exists on disk when the check runs.
- **`stale`** — the check names each artifact, both versions and the direction,
  and SHALL name the remedy. Where the authority holds no such file at all, it
  says that instead of citing a version, because the remedy is different. It SHALL NOT install anything: this capability's
  tools report and the installer installs, and a check that silently rewrote the
  shared bin would be doing the one thing `drifted` is forbidden to do.
- **`unknown`** — the authority path was not reachable, so currency was not
  computed. It SHALL NOT be reported as `current`. A result is a statement about
  what was checked, never about the machine — the same rule the override scan
  follows when it reports *no known vector found* rather than *no override is
  set*. The report SHALL name the path it looked for and SHALL say that this is
  the expected reading on a machine that holds the implementations without
  holding the authority, so an operator can tell an ordinary condition from a
  broken one.

**The licence to describe the fleet's protections as running as documented
requires `complete` + `attested` + `current`, and no other combination grants
it.** It previously attached to `attested` alone. That was too strong and was
observed to be false: a machine held `complete` + `attested` while running two
implementations missing three landed fixes, and was described as provisioned
throughout. `unknown` does not grant the licence either — an unchecked claim and
a verified one must not read the same.

**All three axes are computed from what is on disk, never from what happened.** The
previous revision defined *provisioned* as "a publishing run completed" and
*partially provisioned* as "a publishing run was interrupted". A reviewer showed
that history is not evaluable after the fact — nothing on the machine records
it — and, worse, that a completed install later deleted, hand-edited, replaced
or half-removed classified as **provisioned** under that definition. That is
precisely the condition the manifest check exists to detect, and the state table
was the one place it could not be named.

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

#### Scenario: A project is cloned before the installer runs

- **WHEN** a project is cloned onto a machine where the installer has never run
- **THEN** the project is usable, every shimmed hook reports itself missing, and
  no protection is claimed that is not running

#### Scenario: The installer runs

- **WHEN** the shared artifacts are installed
- **THEN** the installer verifies each shimmed implementation is present and
  executable, and fails visibly if one is not


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

#### Scenario: The authority holds no such artifact

- **WHEN** a present implementation has no counterpart in the authority — the
  authority is checked out at a commit predating it, or the artifact was renamed
  or removed upstream
- **THEN** it is reported `stale` with its own message, **not `unknown`**: the
  authority was reached, so "this artifact is not in it" is a finding rather than
  an inability to check, and its remedy differs from an ordinary version lag

#### Scenario: The machine carries a build ahead of the authority

- **WHEN** a present implementation's version marker is higher than the
  authority's
- **THEN** it is reported `stale` in that direction — the machine holds a build
  the authority cannot account for — rather than passed as newer-and-fine, for
  the same reason a shim marker ahead of the template is `unrecognised`

## ADDED Requirements

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
- **THEN** the check names the installer as the remedy and does not run it — this
  capability's tools report and its installer installs, and a check that rewrote
  the shared bin would resolve silently what it is required to surface
