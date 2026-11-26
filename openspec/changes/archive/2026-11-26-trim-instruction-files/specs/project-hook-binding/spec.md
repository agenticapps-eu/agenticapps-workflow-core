## MODIFIED Requirements

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
hook has been switched off — and for the §18 gate, that its blocking
conditions are not running. A rate limit adopted to quiet a benign condition would
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
against `change-gate-enforcement`, which is explicit: the gate blocks an edit on
exactly one condition — `openspec validate --all` is not green — and a commit on
that and one more, an `AGENTS.md`/`CLAUDE.md` pair that differs, while the
reviewer count, the verdict grammar, reviewer independence, the trailer format
and the binding of a review to what it reviewed are computed and **reported,
never enforced**. So an absent gate loses three things, none of them a review
requirement:

1. **validation enforcement** — the one condition on which an edit is blocked,
   and one of the two on which a commit is;
2. **the instruction-pair check** — the other commit-time condition, lost
   wherever the pre-commit wrapper fails open with the shim (below); and
3. **the reporting** of review state, which was advisory before the gate went
   missing and is merely absent after.

Calling the loss "review enforcement" names a block the gate does not perform,
and passes over the ones it does. Every statement in this capability about what
a missing, unresolvable or overridden gate costs SHALL be written against the
blocking conditions.

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
