# project-hooks — fleet-shared workflow hooks

The canonical implementations of the workflow hooks that more than one project
binds, plus the shim template every project binds them *through*.

Seven repos used to carry a full copy of each of these files. Four of the eight
copied hooks had drifted into two or three distinct versions; the one hook that
was never copied — `openspec-change-gate.sh`, a ~13-line shim — had zero drift
across all seven. This directory is that observation applied to the rest.

**Authority.** For a hook in the `published-resolution` profile, the file in
*this* directory is authoritative and the project copy is a shim that `exec`s
it. The shim template here — not any project's copy of it — is the authority
for shim conformance.

---

## The shim contract

A shim is a project-local file, registered in that project's
`.claude/settings.json`, whose entire job is to find the implementation and hand
over to it.

### Resolution order (published-resolution profile)

**Two candidates, in order:**

1. `$<HOOK>_OVERRIDE` — an explicit path naming an **executable regular file**,
   when set to a non-empty value.
2. `~/.agenticapps/bin/<hook>.sh` — the shared install, likewise an **executable
   regular file**.

There is **no third `<repo>/bin/` candidate.** A repo-local copy is the drift
this directory exists to remove; keeping it as a fallback keeps the drift and
hides it, because the fallback only runs on the machines nobody is looking at.

**Regular file, and the word is load-bearing (shim-contract 1.1.0).** `-x` on a
directory tests the search bit, which every ordinary directory has. Until 1.1.0
the shims tested `-x` alone, so an override naming a directory was called
executable and `exec`ed: bash exited **126** with its own "is a directory"
message, the invalid-override report never fired, and the exit code was not the
1 this contract states. Fail-open was preserved throughout, so this was a
conformance and diagnostics defect rather than a safety one — but the report is
the whole mechanism by which an operator learns a hook is switched off, and it
was the one thing that did not happen.

**It applied to candidate 2 as well, and 1.1.0 fixed only candidate 1
(shim-contract 1.2.0).** The bare `-x` survived on the shared-install branch
eleven lines below the comment explaining why it was wrong on the override
branch, so a directory at `~/.agenticapps/bin/<hook>.sh` reproduced finding 6
exactly: exit 126, bash's message, no sentence naming the hook or the allowance.
A rule stated of one of two candidates is a rule about one of them. Found in the
Stage-2 review of the 1.2.0 change, which is also where the same shape was found
in the test suite — every 1.2.0 assertion had been made of the template, and the
sibling shim was reached by none of them.

A candidate that **exists but is not usable** is now reported as *occupied*
rather than as *not installed*, and is not rate limited. "Not installed" is false
of a path something occupies, and it points the operator at the installer when
the question is what is sitting there.

**An override set to the empty string falls through, deliberately.** `FOO=` is
the conventional way to neutralise a variable — it is how an operator says "no
override", not how they name a broken one — so **"set" in this contract means
set to a non-empty value.** Reporting `FOO=` as invalid would make the ordinary
way of clearing the kill switch print an error on every matched call. This was
the second half of Stage-2 finding 6, whose actual complaint was that the
behaviour was a decision nobody had written down. It is asserted in
`tools/project-hook-shim.test.sh`; behaviour nothing asserts is behaviour nobody
chose.

#### Contract revisions

| Version | Change | Binders updated |
|---|---|---|
| 1.0.0 | initial — two-candidate order, fail-open-and-report, the marker | 21 |
| 1.1.0 | an override must name an executable **regular file**; empty means unset | 21 |
| 1.2.0 | a suppressed report still emits one line; **candidate 2** must also name an executable regular file, and an occupied path is reported as occupied | in progress |

A contract change must name **which profile each binder implements**, because a
change that reaches every file and applies one profile's clauses to both has not
been verified, only assumed uniform. For 1.1.0 that is **20 `published-resolution`
binders** — three each in `agenticapps-dashboard`, `agenticapps-roadmap`,
`callbot`, `cparx`, `fbc-platform` and `fx-signal-agent`, and two in
`agents-task-viewer`, which ships no `normalize-claude-md` file at all (design
Decision 8) — plus **one `self-hosting` binder**, core's own
`.claude/hooks/openspec-change-gate.sh`.

The two profiles answer an unusable override differently, and 1.1.0 does not
change that. A published-resolution shim has two candidates, so it reports the
invalid override and exits 1 without falling through. The self-hosting binder
resolves one path, and its stated answer to a path it cannot use is to warn,
name it, and fail open; a directory now reaches that branch instead of exiting
126. What 1.1.0 makes uniform is that **no binder `exec`s a directory**.

### The reporting channel, verified per event class (task 2.10)

The `PreToolUse` exit-1 convention must not be reused for `PostToolUse`
untested — the two events do not share exit semantics, and this change wrote
that requirement into its own delta. So it was checked rather than assumed.

**Verified against the host's hook documentation on 2026-08-02.** Two rules
that are easy to conflate, kept apart here deliberately:

| | `PreToolUse` | `PostToolUse` |
|---|---|---|
| exit `0` | proceed; stdout parsed for JSON | proceed; stdout parsed for JSON |
| exit `2` | **blocks** the tool call; stderr → **Claude** | cannot block (the tool already ran); stderr → **Claude** |
| any other non-zero | non-blocking error; transcript shows a `<hook> hook error` notice plus **the first line of stderr**; full stderr → debug log | same general rule | 

The exit-2 row is a per-event table. The any-other-non-zero row is a single
general rule the docs state once, qualified as applying "**for most** hook
events" — that qualifier is why the empirical check below is not redundant.

**Consequences, which the shims implement:**

1. **Exit 1, never 2, on both event classes.** Exit 2 from `PreToolUse` blocks,
   which is the one thing an unresolvable shim must not do. Exit 2 from
   `PostToolUse` cannot block but routes the message to Claude rather than to
   the operator's transcript — the wrong audience for a provisioning fault.
2. **The first line carries the whole message.** Only the first stderr line
   surfaces in the transcript; the rest reaches the debug log. Every report in
   `shim-template.sh` is written that way.
3. **`normalize-claude-md` uses the same exit code as the `PreToolUse` shims —
   but by verification, not by inheritance.** The general rule is what makes it
   correct, not the `PreToolUse` convention.

### The empirical leg (task 2.3a) — SETTLED 2026-08-04: the channel is established

**Result first, because this section previously said the opposite.** On
2026-08-04 the interactive check below was carried out. The notice **renders in
the interactive TUI transcript**, carrying the shim's first stderr line intact:

```
PreToolUse:Bash hook error
Failed with non-blocking status code: database-sentinel hook: not installed at
/Users/donald/.agenticapps/bin/database-sentinel.sh — this hook did NOT run, and
the tool call was allowed
```

Method: `~/.agenticapps/bin/database-sentinel.sh` was renamed away, the
rate-limit marker at `${XDG_STATE_HOME:-$HOME/.local/state}/agenticapps/` was
deleted so a stale hour could not suppress the report, and a Bash call was made
in `agenticapps-dashboard` — the one fleet repo in its family that binds the
hook through a real shim rather than an inlined copy. The implementation was
restored immediately afterwards and re-verified: benign call exit 0, `DROP
TABLE` exit 2.

**So exit 1 IS observable, and the shims do warn.** The prohibition that stood
here — that no report may describe either hook as "warning" anyone — is
withdrawn. What survives from the headless run is narrower and still true: exit
1 produces no `hook_response` event in `--output-format stream-json`, so
**programmatic** consumers cannot see it. The channel is human-visible and
machine-invisible, which is a different statement from "unestablished".

#### Why the earlier probe concluded the opposite

The headless run was sound and its negative was an artifact of the surface it
could reach, not of the hook. Headless mode has no transcript, so the one place
the notice actually renders did not exist in that environment. The probe
correctly recorded this as "genuinely unknown" rather than refuted — but the
summary line then hardened it into UNESTABLISHED, and that wording is what
propagated for nine sessions.

Worth keeping as a method note: **absence of evidence on the only surface you
can observe is not evidence of absence on the surfaces you cannot.** The
original text got this right in its caveat and wrong in its conclusion.

#### A defect this settled probe exposed — FIXED at shim-contract 1.2.0

**Fixed.** A suppressed call now emits one line — naming the hook, the unchanged
state, that the call was allowed, and that the full notice was already made this
hour — and keeps its non-blocking exit code. The rate limit governs verbosity,
which is the only thing it can govern: the exit code interrupts regardless. The
rule generalises beyond this instance and is now normative — a shim never exits
non-zero having written nothing, so whatever suppresses a report must also be
asked what the exit code should be.

What follows is the defect as found, kept because the reasoning is what argued
the fix.

The report was rate-limited to once per hour per hook per machine. **The exit
code was not.** So the first unresolved call that hour reported properly, and
every subsequent one exited 1 with empty stderr, which the host renders as:

```
PreToolUse:Bash hook error
Failed with non-blocking status code: No stderr output
```

Reproduced directly: three consecutive invocations against an unresolvable
shared install gave `exit=1` with the message, then `exit=1` silent, then
`exit=1` silent.

This defeats the rate limit's own stated purpose. The limit exists because
reporting every time is the alarm fatigue this directory rejects elsewhere — but
a *contentless* alarm fires exactly as often as the message would have and tells
the operator nothing at all, which is worse than the repetition it was adopted
to prevent. **If it is worth exiting non-zero, it is worth saying why; if it is
not worth saying, it should exit 0.**

Of the two remedies named here, the second was taken. Exiting 0 when suppressed
would have delivered the interval policy's intent and made every remaining call
that hour an *unannounced* fail-open — silent protection loss, which is the
posture this directory rejected when it rejected fail-closed.

#### The original headless run, retained for provenance

A headless `claude -p` session was driven against a
scratch project registering **real, unresolvable shims** on both `PreToolUse`
and `PostToolUse`, with the rate-limit marker directory isolated so it could not
lie. 2026-08-02, Claude Code 2.1.220.

**What is confirmed:**

- **Both shims ran, on both event classes.** Both wrote their rate-limit
  markers, which only happens on the unresolvable-and-reporting path.
- **Fail-open works, live.** The `Write` proceeded and the file was created.
  This is no longer an argument from exit codes; it was observed.

**What is refuted — or at best unsupported:**

- **The exit-1 report did not reach the agent.** Asked to report any hook error
  notices verbatim, it answered "none".
- **No `hook_response` event for either hook appeared in `--output-format
  stream-json`.** Eight such events were emitted for `SessionStart` hooks in the
  same run, so the surface exists and was being populated; the two `ToolUse`
  hooks produced none.

The contrast with `database-sentinel` is sharp and was measured in the same
sitting: its **exit 2** block *did* reach the agent, which quoted the message
back. Exit 2 is observable. Exit 1 was not observable anywhere this probe could
look.

**What was then unknown — and is now answered:** whether the notice renders in
the *interactive* TUI transcript. Headless mode has no such surface, so this
probe could not settle it. The check named below was carried out on 2026-08-04
and **the notice does render**; see the result at the top of this section.

~~So the wording of task 2.10a stands … the reporting channel UNESTABLISHED.~~
**Withdrawn 2026-08-04.** The channel is established for a human at an
interactive session. The accurate statement is narrower: the shims fail open and
report, the report reaches the operator's transcript, and it does **not** reach
programmatic consumers of `--output-format stream-json`.

> **The check that settled it**, for a human at an interactive session: on a
> machine where `~/.agenticapps/bin/database-sentinel.sh` is absent, open one of
> the fleet repos **that binds the hook through a shim** and run any Bash call.
> Clear the rate-limit marker first, or a report already made this hour will be
> suppressed and the result will read as a false negative.
>
> Carried out 2026-08-04 in `agenticapps-dashboard`. The notice appeared. Note
> the repo choice is load-bearing: three of the four repos in that family carry
> an inlined copy of the implementation rather than a shim, so renaming the
> shared file has no effect on them and the probe would have shown nothing for
> reasons unrelated to the channel.

### Unresolvable → fail open, and report

If neither candidate resolves to an executable file, the shim **allows the tool
call** and **reports on stderr**. It does not block.

The reasoning is scope, and it is worth stating because an earlier revision of
this change had it the other way. These hooks are registered on broad matchers —
`database-sentinel` on `Bash|Edit|Write|MultiEdit`. A shim that blocks when it
cannot resolve an implementation therefore blocks *every Bash command and every
file edit in the repository*, not `.env` and dangerous SQL. Narrowing that would
require the shim to inspect the tool payload, which is exactly the behaviour the
contract forbids and exactly the duplicated logic this directory exists to
remove.

The guarantee moves to where it can be enforced without duplicating anything:
the installer verifies the implementations are present and executable, and a
per-machine provisioning check reports the machine's state. Absence becomes a
provisioning failure — caught once, visibly — rather than a per-tool-call
outage.

### The report's repetition policy (tasks 2.11, 2.11a, 2.11b, 2.11c)

An unresolvable shim fires on **every** `Bash`, `Edit`, `Write` and `MultiEdit`,
indefinitely, for as long as the machine stays unprovisioned. An unstated
policy therefore defaults to the noisiest one — a hook-error notice on
essentially every tool call — which is the same alarm fatigue this change uses
to reject a fail-closed pre-commit wrapper, pointed at the transcript instead.

**Policy: once per hour, per hook, per machine — and per-invocation for the
override fault.** The two conditions are governed separately.

| Condition | Repetition | Why |
|---|---|---|
| implementation unresolvable | once per hour | persistent, benign, self-correcting once the installer runs |
| override set but unusable | **every invocation** | it is the kill switch — see below |

**Why an interval and not a session (task 2.11a).** Once-per-session is the
policy you would want. It is unreachable: the session identifier exists only in
the `session_id` field of the stdin payload, the host exports no equivalent
environment variable, and a shim that reads stdin to find it has consumed the
implementation's input. The remaining options are per-interval and
per-invocation. An hour approximates a session closely enough to serve, while
guaranteeing that a long session sees the condition more than once. Recorded
here rather than the option being dropped silently.

**The marker stays inside the carve-out (task 2.11b).** One path —
`${XDG_STATE_HOME:-$HOME/.local/state}/agenticapps/<hook>.unresolved-report` —
read and written, holding an integer hour. No tool payload is inspected.

**Why the override fault is exempt (task 2.11c).** An unusable override is the
only signal that a hook has been deliberately switched off on an otherwise
*healthy* machine. A single policy covering both conditions would mean a rate
limit adopted to quiet the benign one also silences the kill switch. They are
different signals with different urgency, so they get different policies.

### Behaviour-free — a closed list

A shim does exactly these five things and nothing else:

1. resolves the implementation,
2. host self-identification (the change-gate shim only; being retired),
3. `exec`s the implementation, passing **stdin and argv** through untouched,
4. reports when it cannot resolve, or when an override is set but unusable,
5. reads and writes **one** repetition marker, if its report is rate-limited.

In particular it **inspects no tool payload**. A shim that reads stdin to look
at the payload has consumed the implementation's input.

**Forwarding argv is part of handing over, and it is not optional.**
`normalize-claude-md` is registered as
`.../normalize-claude-md.sh "$CLAUDE_PROJECT_DIR/CLAUDE.md"` — with an
argument. Given none, the implementation falls back to `./CLAUDE.md` relative to
the hook's CWD, reports `input not found`, and does nothing. A shim that `exec`s
without `"$@"` therefore turns the hook into a **silent no-op in every repo that
binds it**. That is the PR #59 defect exactly — the change-gate wrapper
discarded its arguments and made `--ci` a silent green — and it was reintroduced
here and caught by the first repo's rollout rather than by the suite. It is in
the suite now.

### Profiles

Not every binder of a shimmed hook resolves a *published* copy.

| | `published-resolution` | `self-hosting` |
|---|---|---|
| Who | the seven consuming projects | `agenticapps-workflow-core` itself |
| Resolves | override → `~/.agenticapps/bin/` | its own working-tree reference implementation |
| Resolution order applies | yes | **no** |
| Byte-identity across projects applies | yes | **no** |
| Contract version marker applies | yes | yes |
| Behaviour-free rule applies | yes | yes |
| Fail-open-and-report applies | yes | yes |

Core's `.claude/hooks/openspec-change-gate.sh` is `self-hosting` by design, not
by omission: per ADR-0028 core must score the bytes it *ships*, not whichever
host's installer last wrote `~/.agenticapps/bin/`. A shim there would test the
wrong file.

**A hook has exactly one `self-hosting` binder.** Two would be two authorities,
which the `project-hook-binding` capability's first requirement forbids.

### Version markers — two of them, deliberately distinct

| Marker | Lives in | Says |
|---|---|---|
| `# shim-contract: <semver>` | every **shim** | which contract revision the shim implements |
| `# <hook>-version: <semver>` | every **implementation** | which build of the implementation this is |

Both sit within the first 10 lines, matching the `# gate-version:` convention
`openspec-change-gate.sh` already uses. The implementation marker is what the
install manifest's rows reference; the shim marker is what a per-project
conformance scan compares against the template in this directory.

---

## Coverage boundary

Stated so the hooks can be relied on correctly. A control described as stronger
than it is invites exactly the wrong decisions.

### `database-sentinel`

**It is best-effort defence in depth, not a security boundary.**

- The `Bash` arm matches `DROP TABLE`, `TRUNCATE TABLE`, and `DELETE FROM`
  without a `WHERE`, by regex on the command string. Indirection defeats it:
  `psql -f script.sql` never presents the SQL to the regex, and neither does a
  heredoc fed to a client, an ORM call, or a migration runner.
- It does **not** stop `Bash` writing `.env`. The `.env` arm reads
  `tool_input.file_path`, which `Bash` does not supply; `echo SECRET > .env`
  passes.
- The implementation is a **user-writable file in a shared directory**, executed
  by seven projects. Anyone who can write `~/.agenticapps/bin/` can change what
  all seven enforce. That is the cost of consolidation, and the reason the
  maintained copy lives here in core rather than the published one being
  authoritative.
- On an unprovisioned machine it does not run at all. It reports and allows.

### `normalize-claude-md`

- `PostToolUse`, so it observes an edit that has already happened. It is a
  normalizer, not a gate, and blocks nothing.
- It rewrites `CLAUDE.md` in place. Its failure mode is a mangled instruction
  file, not a leaked secret.

### The override, in both hooks — it is a kill switch

`$<HOOK>_OVERRIDE` exists for testing and staged rollout. It is **not** a
production configuration mechanism, and it cuts two ways:

- **Pointing it at a non-existent path disables that hook on a healthy
  machine.** For the §18 change gate that is a one-variable bypass of the gate
  at the tool boundary.
- **Pointing it at an executable regular file that *exists* gets that file
  `exec`d** on every `Bash`/`Edit`/`Write`/`MultiEdit`, with the operator's
  privileges. Since shim-contract 1.1.0 a directory is not such a file and is
  reported rather than run; that narrows the diagnostics gap, not the exposure,
  because a directory was never something an attacker would point this at. Combined
  with the vectors below, that is repository-supplied code running at the tool
  boundary. The missing-file case is the *safe* one.

A shim cannot defend against this, and pretending otherwise was tried and
withdrawn (design Decision 13). The host injects `.claude/settings.json` `env`
values into the hook process's environment, where they are indistinguishable
from an operator's own `export`. A behaviour-free shim reads `$VAR` and has no
provenance to inspect. The answer is a **conformance scan that reports the
repository by name**, not a runtime suppression — the value takes effect, which
is precisely why it must surface in review.

The scan must cover more than `settings.json`: an `.envrc` (direnv), a bootstrap
or setup script, a task-runner definition, or README instructions can each
export the override into the operator's shell. A green result therefore reads
**"no known vector found"**, never "no override is set".

---

## Provisioning — and the regression it answers

Publish with `install-project-hooks.sh`; check with `tools/provisioning-check.sh`.

**The state is a triple, not one of four** (design Decision 12, third axis added
2026-08-03):

| axis | values | asks |
|---|---|---|
| `completeness` | `none` / `partial` / `complete` | how much is installed |
| `integrity` | `attested` / `drifted` | does it match what was installed |
| `currency` | `current` / `stale` / `unknown` | is that still what the authority holds |

The flat list overlapped — a manifest whose files are all absent is both
*unprovisioned* and *drifted* — and every state here is **observed**, never
inferred from history. "The installer has never run" is not evaluable after the
fact, and a history-based definition calls a completed-then-hand-edited install
*provisioned*: the exact condition the manifest exists to detect.

### The counter-example that added the third axis (2026-08-03)

Recorded with its date, because **a rule with a recorded counter-example is
harder to quietly re-weaken** than one stated as a principle.

This document said, of `attested`, that it was *"the only value on either axis
under which the fleet's protections may be described as running as documented"*.
On 2026-08-03 this machine held `complete` + `attested` and was described as
provisioned — by this tool, in those words — while running:

| artifact | published | core shipped | measured behaviour of the published copy |
|---|---|---|---|
| `normalize-claude-md` | 1.0.0 | 1.0.1 | `CLAUDE.md` 0644 in → **0600** out |
| `database-sentinel` | 1.0.0 | 1.1.0 | `DELETE FROM public.users` **not blocked** |

It held for fifteen hours. The check printed `attested v1.0.0` throughout: the
number was on screen and **nothing compared it to anything**.

The licence to describe the protections as running as documented now requires
**`complete` + `attested` + `current`**, and no other combination grants it —
`unknown` included, because an unchecked claim and a verified one must not read
alike.

### What made it possible, which was not a missing check

The comparison already existed. `--source-check DIR` byte-compared each executed
copy against core's maintained implementation and carried a comment stating the
premise exactly — *a machine can be perfectly attested against a manifest that
published last month's implementation.* Pointed at a stale tree it correctly
reported `DIFFERS` on both artifacts, and the summary printed "This machine is
provisioned. The shims will resolve." anyway, because the finding fed a separate
block and no verdict.

Three narrower defects, all fixed:

1. the summary was computed without the comparison, so it could contradict it;
2. the comparison was **opt-in and off by default**, and its absence was
   undisclosed — a run without the flag read exactly like a run where the
   stronger question was asked and passed;
3. the vocabulary could not express the result, so code was ahead of spec.

`currency` is on by default now, resolved from the tool's own location inside
core. `--source-check DIR` names a different authority; `--no-source-check` opts
out and says so.

### What `current` does and does not license

`current` means **byte-identical to this authority checkout**, never "matches
what core ships". The check reads files on disk; it cannot know what a branch
elsewhere contains, so an authority checkout that is itself behind agrees with an
equally behind install and the pair reports `current`. That is the check being
right about the disk rather than wrong about the world — and the limit is
printed with the verdict, because an unqualified `current` would recreate the
false green one level up. `git show <ref>:<path>` is how to ask the branch
question, and is what the fleet's contract propagation used as its durable check.

### `stale` names a remedy per condition — there is no universal one

Re-running the installer is right in exactly one of these, and actively harmful
in another:

| condition | remedy |
|---|---|
| published **behind** the authority | re-run `install-project-hooks.sh` |
| published **ahead** of the authority | **not** the installer — it refuses downgrades. Update the checkout, or investigate a build published from a tree nobody has |
| versions equal, bytes differ | investigate: a build error or a hand-edit, not a lag |
| the authority holds no file for a **declared** artifact | check out the authority at a commit that has it, or reconcile `ARTIFACTS` |
| `drifted` **and** `stale` together | investigate first — re-installing overwrites the evidence of the edit |

Direction is compared **component-wise numerically**. A lexical compare places
`1.10.0` below `1.9.0` and would hand the operator the opposite remedy, which is
worse than handing them none.

### Scope, and the mistake that pinned it down

Currency judges the artifacts named in `ARTIFACTS` and nothing else. The shared
bin also holds `openspec-change-gate`, `reviewer-cli` and `run-plan-review`,
published by `install-shared-artifact.sh`, which the manifest check already
reports as *"not covered — published by another installer"*.

This was learned rather than designed: an earlier revision made "the authority
holds no such file" a `stale` finding **without** scoping it, and running it
flagged exactly those three. Scoped to the declared set, an absent authority file
is a genuine finding again, because every declared artifact must exist in the
authority.

`--strict` counts currency, `unknown` included. That makes it **newly able to
fail** on a machine whose authority checkout lags or is absent — a behaviour
change, not a reporting one.

### The regression this answers (task 3.6a)

State it plainly, because the change makes something worse before the check
makes it visible.

**Before:** `database-sentinel` ran on any clone with **zero provisioning**,
because the implementation was *in the clone*.
**After:** the protection travels with the **machine** instead of the
repository — and **every existing developer machine enters the unprovisioned
state the moment it pulls the shim.** An ordinary `git pull`. No prompt, no
install step, no error. Only the first arrangement was automatic.

Every other conformance check this change specifies is per-*repository*, so
none of them can see it. That is why a per-machine check exists at all.

### Publish-and-verify orders exactly one machine (task 3.6b)

The rollout publishes before it replaces any project copy. **That constrains the
rollout machine and nothing else.** It is not fleet-wide assurance, and must not
be cited as any. Other machines are ordered by being *told to run the
installer* — and by the shim reporting, once an hour, that it could not resolve.

### Verified behaviour of the published copies (tasks 3.4, 3.5)

Ten payloads, run against the published implementation and against the two
project copies it replaces. Exit 2 = blocked, 0 = allowed.

| payload | canonical | `callbot` | `dashboard` |
|---|---|---|---|
| `Bash` `DROP TABLE users` | 2 | 2 | 2 |
| `Bash` `DELETE FROM users;` | 2 | 2 | 2 |
| `Bash` `DELETE FROM users WHERE id=1;` | 0 | 0 | 0 |
| `Edit` `.env` | 2 | 2 | 2 |
| `Edit` `.env.production` | 2 | 2 | 2 |
| `Edit` `.env.example` | 0 | 0 | 0 |
| `Edit` `src/app.ts` | 0 | 0 | 0 |
| `Edit` `migrations/001.sql` | **0** | **2** | **2** |
| `Edit` `.env.vercel` | **2** | 2 | **0** |
| `MultiEdit` `.env` | **2** | 2 | **0** |

Against `callbot` — the copy reconciled as canonical — the only difference is
the dropped `migrations/` clause, which is what task 3.4 admits. Against
`dashboard` — an enumerated-list copy — the two further differences are the
novel `.env` suffix now caught (task 3.5) and `MultiEdit` coverage, which is
forward-compatibility until task 4.8 settles whether the host provides that
tool.

---

## Reconciliation record

Task 1.3a requires that each behavioural difference between project copies be
resolved *with a reason*. The superset is the default, not an unconditional
rule: a clause that traces to no live gate or stated policy is escalated rather
than unioned, and a deliberate project-specific difference is preserved as a
documented opt-out.

Measured on this machine, 2026-08-02, across all seven repos.

> **Corrected the same day, by the instrument.** The note below counted three
> repos in one family, because one family is what was looked at.
> `project-hook-conformance.sh --fleet ~/Sourcecode` reads the declared set and
> reports **five** repos carrying unmarked inlined copies of **all three**
> shimmed hooks — `agenticapps-roadmap`, `agents-task-viewer`, `callbot`,
> `fbc-platform`, `fx-signal-agent` — across two families. Only
> `agenticapps-dashboard` and `cparx` bind through contract shims.
>
> The count came from the repos the author happened to open rather than from
> `FLEET`, which is the failure `FLEET` was written to prevent: a binder missing
> from an ad-hoc list is indistinguishable from one that passed. The paragraph is
> kept rather than rewritten, because the correction is the point.
>
> **Re-measured 2026-08-04: the reconciliation has not propagated.** Of the four
> repos in the `agenticapps` family that bind `database-sentinel`, only
> `agenticapps-dashboard` binds it through a shim. The other three —
> `agenticapps-roadmap`, `agents-task-viewer` and the
> `agenticapps-dashboard-add-agent-board` checkout — still carry a standalone
> 68-line copy, **byte-identical to each other** and predating the 1.1.0
> reconciliation. Consequences, all verified rather than inferred:
>
> - **`MultiEdit` is not covered in those three.** Their matcher is
>   `Bash|Edit|Write`; the reconciled implementation declares
>   `Bash|Edit|Write|MultiEdit`. A `MultiEdit` to `.env` never invokes the hook
>   at all, so the protection is absent rather than degraded.
> - **Nothing declares what they are, so currency cannot judge them.** The
>   version marker `provisioning-check.sh` reads is `# <artifact>-version: X.Y.Z`
>   in an implementation's first ten lines (`provisioning-check.sh:381-385`), and
>   it is read from the *published* copy in the shared bin — not from a project
>   hook file. `grep -c database-sentinel-version` therefore returns 0 in all
>   four repos, the shim included, and is not what separates them; the shim
>   carries `# shim-contract: 1.1.0` and delegates to a shared implementation
>   that the declared artifact set does cover. An inlined copy is an
>   implementation no declaration names, compared against no authority, so the
>   currency axis is structurally blind to it. The copies most likely to be stale
>   are precisely the ones staleness cannot be reported for.
> - **The 1.1.0 fixes are absent**, including the jq-absence handling that
>   otherwise aborts at the first command substitution with exit 127 and nothing
>   explaining why (Stage-2 finding 11).
>
> This is the failure mode the shim contract exists to remove, observed intact
> two days after the reconciliation that was supposed to end it. Publishing to
> the shared bin does not reach a project that never bound a shim. Recorded here
> rather than fixed: converting the three is a change, not an edit.

### `database-sentinel` — three distinct variants

| Variant | Repos |
|---|---|
| `a5030f…` (68 lines) | dashboard, roadmap, agents-task-viewer, fbc-platform, fx-signal-agent |
| `211cac…` (71 lines) | callbot |
| `dabf20…` (72 lines) | cparx |

**Difference 1 — `.env` matching: enumerated list vs. wildcard.**
Five copies enumerate `.env{,.local,.production,.staging,.development}` and the
`*/`-prefixed forms. `callbot` uses `.env|.env.*|*/.env|*/.env.*` plus an
explicit `*.env.example|*.env.template` allowance.
**Canonical: the wildcard.** It is a strict superset — every enumerated path
matches it — and the enumeration misses any novel suffix, which is the exact
case a secrets guard exists for. The `.example`/`.template` allowance is
required *by* the wildcard (those paths match `.env.*`) and restores parity with
the enumerated variants, which never blocked them either. **Nothing is lost.**

**Difference 2 — `MultiEdit` in the tool test.**
Only `callbot` tests for it. **Canonical: include it.**
Coverage of a tool the host does not provide is not protection gained — see
task 4.8, and note that `MultiEdit` appears to be absent from the current host's
tool set. This is forward-compatibility. It must not be reported as closing a
live gap unless 4.8 finds otherwise. It is also inert without the matching
`settings.json` matcher change, which is why the rollout edits six matchers.

**Difference 3 — the `migrations/` arm. Dropped, not carried, and it is in all
seven copies rather than one.**
Every variant blocks `migrations/*` and `*/migrations/*` unless
`.planning/current-phase/migrations-approved` exists, and prints a remedy naming
`/gsd-discuss-phase` — a command removed 2026-07-28. Measured: **six of the
seven repos have no such sentinel**, so every migration edit in those six is
blocked today, with an unactionable remedy. Only `cparx` has the file.
This is the same dead-sentinel mechanism as `design-shotgun-gate`, inside the
hook the first draft of this change classified as healthy.
**This corrects the change's own artifacts, which scoped the live defect to
`callbot` alone.** The remedy is unchanged — the clause goes — but the reported
impact is six repos, not one.

**Difference 4 — `cd "${CLAUDE_PROJECT_DIR:-$PWD}"`.**
`cparx` only. It exists to resolve the repo-relative sentinel path in the
`migrations/` arm against the project root rather than the hook's CWD.
**Canonical: dropped.** With difference 3 removed, no surviving check reads a
repo-relative path — every remaining test reads `tool_name`, `command`, or
`file_path` from the payload. The `cd` becomes inert, and an inert `cd` in a
hook that must stay behaviour-free is worth removing rather than inheriting.

### `normalize-claude-md` — three distinct variants

| Variant | Repos |
|---|---|
| `5a06d7…` (288 lines) | roadmap, callbot, cparx, fbc-platform, fx-signal-agent |
| `0dc500…` (287 lines) | dashboard |
| `14af2d…` (314 lines) | agents-task-viewer |

**Difference 5 — the `workflow` slug branch (resolves design open question 1).**
`dashboard`'s 2026-07-26 fix always collapses the block. The other five fall
back to injecting a `> Workflow defaults. Migration 0009 not yet applied.` stub
whenever `.claude/claude-md/workflow.md` is absent — which, since workflow
v3.0.0 moved the canonical document to `docs/WORKFLOW.md` and the vendored copy
was removed, is both false and stale in every repo.
**Canonical: `dashboard`'s.**

`agents-task-viewer`'s 314-line variant is **this file's predecessor plus a
26-line opt-out banner comment** — diffed, and it contains no functional
addition. Design open question 1 resolves to *nothing to fold in*.

**Difference 6 — the opt-out itself is preserved, as an opt-out.**
`agents-task-viewer` deliberately does not register this hook (in-file note
dated 2026-07-21): the hook collapsed CLAUDE.md's inlined stack block into a
pointer link, and that block carries pinned-version constraints the project's
correctness depends on. It had been manually reverted ~3 times.
**Per task 4.3 that repo receives no file at all** — the opt-out forbids wiring
the hook, it does not require an unwired file to exist, and a shim nothing
invokes is a copy that can drift unnoticed.

> **Carry the rationale forward.** The 26-line banner is currently the *only*
> record of why the opt-out exists. Deleting the file without relocating that
> note destroys the reason and invites the next migration to re-add the
> registration — which the note explicitly warns against. See task 4.3.

---

## Audit: other checks with dead preconditions (task 1.8)

Task 1.4 removed one check whose precondition no surviving command can satisfy.
Task 1.8 asks whether either canonical implementation contains another. Both
files were read end to end.

**`database-sentinel` — none remaining.** After difference 3, every test reads
the tool payload. No sentinel file, no marker, no external command.

**`normalize-claude-md` — one stale remedy, no dead gate.**

- Line ~160, the `profile` slug branch, emits
  `> Run \`/gsd-profile-user\` to generate.` into `CLAUDE.md`.
  `/gsd-*` commands were removed on 2026-07-28. This is the same *class* as
  task 1.4 — a remedy naming a dead command — but it is **not** a gate: it
  writes a stub, it blocks nothing, and no precondition is being tested.
  **Recorded, not changed.** Editing it would alter this hook's output in seven
  repos, which task 3.4's "behaves identically apart from the dropped
  `migrations/` clause" does not admit. It belongs to the §02 GSD-vocabulary
  cleanup that `docs/PLAN-lightweight-fleet.md` step 5 owns.
- Lines ~107–112 map source labels to paths under `.planning/`. This hook
  **reads** that directory and rewrites `CLAUDE.md` to *link into* it. The
  fleet's frozen-archive policy forbids **writing** there, which this hook does
  not do — but pointing the live instruction file at frozen history is a real
  smell, and it is the same step 5 root cause. **Recorded, not changed.**

Neither finding blocks this change. Both are logged here so the next revision of
`docs/PLAN-lightweight-fleet.md` step 5 inherits them rather than rediscovering
them.

---

## Files

| File | What |
|---|---|
| `database-sentinel.sh` | canonical implementation, published to `~/.agenticapps/bin/` |
| `normalize-claude-md.sh` | canonical implementation, published to `~/.agenticapps/bin/` |
| `shim-template.sh` | the authority for shim conformance |

---

## The local telemetry logs `skill-router-log` already wrote (tasks 4.11, 4.11a)

Deleting a producer does not remove what it produced. The logs are gitignored in
every repo and tracked in none — so nothing durable was *added* to the repos —
but the existing data sits on developer machines and may contain repository
paths and session activity.

- **Location** — `<projectRoot>/.planning/skill-observations/`, one file per day
  per project, named `skill-router-<YYYY-MM-DD>.jsonl`. Each line is a JSON
  object `{ts, skill, phase, tool}`.
- **Inventory** —
  `find . -path '*/.planning/skill-observations/skill-router-*.jsonl'`
- **Cleanup** — the same expression with `-delete`, run per repo.

**The operator runs it, not this change.** The files are local, untracked, and
may be wanted as history, so the decision belongs to the machine's owner.

**Scope limit, stated in the same breath (task 4.11a).** This removes only what
`skill-router-log` wrote. The `<stamp>--<sessionId>.{md,jsonl}` files beside them
come from `meta-observer`, whose producer stays registered — they will reappear
at the next session end. Cleaning them without unregistering it is housekeeping
that undoes itself.

## `meta-observer` is the dominant `.planning/` writer — recorded, not fixed (task 4.12)

The global `SessionEnd` hook in `~/.claude/settings.json` runs
`agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`, which
writes `<projectRoot>/.planning/skill-observations/<stamp>--<sessionId>.{md,jsonl}`
in **every repo opened**.

Observed on this machine on 2026-08-02: core held **29** files under
`.planning/skill-observations/`, **all 29** in that naming, and **none** in
`skill-router-log`'s `skill-router-<date>.jsonl` — in a repo carrying no
`.planning`-writing project hook at all.

**That is a dated single-machine observation, and must never be quoted as a
measurement of the repository.** The directory is gitignored local state; it
varies per machine, grows every session, and no reviewer can reproduce a figure
from it. An earlier revision recorded 141/137/4 as a measurement, review re-ran
the count and got different numbers, and that is what surfaced the framing error.

**So this change REDUCES the frozen-archive violation; it does not end it.** No
report of it may claim the fleet becomes frozen-archive compliant. Fixing the
dominant writer is a different repo, global wiring, and an operator-level change
— out of scope here, and recorded as proposal follow-up 3.
