## Context

`docs/PLAN-lightweight-fleet.md` step 3 says projects should carry almost
nothing. The evidence for how was already on disk: `openspec-change-gate.sh` is
the only hook bound by a shim rather than a copy, and the only hook with no
drift.

Measured across the seven repos that carry `.claude/hooks/`, before designing:

| Hook | Lines | Versions | Binds a §02 gate? | Disposition |
|---|---|---|---|---|
| `openspec-change-gate` | 46 | 1 | **yes** — `plan-review`'s programmatic gate, retargeted by §18 | Template — unchanged |
| `normalize-claude-md` | 288 | 3 | no | Shim |
| `database-sentinel` | 71 | 3 | no — see below | Shim |
| `skill-router-log` | 67 | 2 | no | **Delete** |
| `session-bootstrap` | 29 | 1 | no | **Delete** |
| `design-shotgun-gate` | 41 | 2 | no — shares a gate's *name* only | **Delete** |
| `phase-sentinel` | 20 | 1 | no | **Delete** |
| `architecture-audit-check` | 72 | 1 | no | **Delete** |

The table is the design. Five of eight hooks earn deletion; only two are worth
a shim. That ratio was not visible from the plan, which assumed the hooks were
live machinery needing cheaper maintenance.

Re-measured 2026-08-02, the Lines and Versions columns are unchanged, with one
exception: `design-shotgun-gate` now exists in **six** copies rather than seven.
`agenticapps-dashboard` deleted its own on 2026-08-01 (its PR #88, "it blocks
every fresh clone"), reaching this table's disposition for that one row without
this change. Its two versions survive across the remaining six, and
`claude-workflow` still vendors the file twice, so the deletion is local and
reversible by the next scaffold — which is the argument for doing it at the
source instead.

**The middle column was wrong in an earlier revision, in the way this change
warns against.** It recorded `database-sentinel` as binding §02's
`database-security` gate because the names match. They do not correspond: §02
binds `database-security` to "a database-security audit skill" and requires "a
database-audit report referenced from SECURITY.md or VERIFICATION.md" — that is
the `database-sentinel:audit` skill, which produces a report. The PreToolUse
hook produces no report and is named in no binding. It is kept because it is
useful, not because §02 requires it.

Getting this wrong in the change's own evidence table, while correctly
identifying the identical error for `design-shotgun-gate`, is the strongest
argument for stating the rule normatively: filename identification is a mistake
that survives being told about itself.

## Goals / Non-Goals

**Goals**

- One authoritative implementation per surviving hook.
- Delete what cannot fire, what blocks wrongly, and what violates the
  `.planning/` policy — rather than making any of it cheaper to maintain.
- Stop `design-shotgun-gate` blocking 204 design files.
- Propagate `dashboard`'s `normalize-claude-md` fix to the five that lack it and
  will run it (`agents-task-viewer` is shipped no file — Decision 8).

**Non-Goals**

- **Retargeting §02 from GSD vocabulary to OpenSpec.** Every §02 gate still
  triggers on "a phase", `CONTEXT.md`, `*-PLAN.md`. §18 already retargeted
  `plan-review` out of it. That staleness is the root cause of which these dead
  hooks are symptoms, and it is plan step 5.
- **Moving instruction content** to `~/.claude/CLAUDE.md`. That is step 3b and
  carries a cost this change does not: rules stop being repo-portable.
- **Re-vendoring to the four hosts.** Plan step 2 says publish, not re-vendor.
- **Building the two deferred advisory prompts.**

## Decisions

### Decision 1: Shim against the shared bin, not a symlink or a package

**Chosen:** override → `~/.agenticapps/bin/`, then `exec`. Two candidates, not
three.

The third candidate, `<repo>/bin/<hook>.sh`, was in the earlier draft and is
removed. A reviewer showed it contradicts whichever way it is read: if `<repo>`
is the product repository, it is the in-project copy this change forbids; if it
is the scaffolder's checkout, a shim running inside a product repo has no
defined way to find it. A resolution order is a contract, and an entry that
cannot be implemented in one reading and is prohibited in the other is not one.

*Alternative — symlink into `~/.agenticapps/bin/`.* Zero resolution logic.
Rejected: a home-directory symlink breaks on clone and in CI with no fail path
— the hook simply errors.

*Alternative — publish as an npm/brew package.* Real versioning. Rejected as
the disease the plan names: a second binding mechanism alongside the shared
bin, when principle 3 says use the one that exists, and it reintroduces
per-project version pinning.

### Decision 2: Delete `design-shotgun-gate` — §02 binds a skill, not a hook

**Chosen:** delete.

This reverses an earlier decision in this change to *repair* the hook, which
rested on reading §02's "removing a gate is non-conformant" as covering any
file bearing a gate's name. It does not. §02 binds `design-shotgun` to "a
multi-variant design generation skill"; in this fleet that is gstack
`/design-shotgun`, named in the host instruction file. The PreToolUse shell
hook is a separate enforcement mechanism that shares the name.

The reviewer caught this. The correction matters beyond one hook: it means a
hook's *filename* is not evidence of a §02 binding, which is now a requirement
in the spec delta so the same mistake is harder to repeat.

Deleting also dissolves a problem the repair created. The repair proposed a
three-state rule — allow if `.planning/current-phase/` is absent, block if
present without the sentinel. But since GSD's removal *no* repo can produce
that sentinel, so any repo with a stale `current-phase/` directory would block
forever. `claude-workflow` is in exactly that state today. The repair would
have introduced the bug it was fixing, somewhere else.

### Decision 3: Delete the telemetry pair, do not relocate it

`skill-router-log` writes into `.planning/`; `session-bootstrap` reads it back.
`.planning/` is designated frozen archive — "never write to them". The
violation is live: core's `.planning/` was written at 08:39 on 2026-07-29.

**Chosen:** delete both.

**The evidence sentence above is wrong, and the way it is wrong matters.**
Core's `.planning/` writes cannot be `skill-router-log.sh`'s doing: **core
carries no `.planning`-writing project hook.** It had no `.claude/hooks/`
directory at all when this was measured; since 2026-08-02 it carries exactly one
file, the `PreToolUse` change-gate installed by `core-self-enforcement`, which
writes nothing under `.planning/`. Either way no project hook of core's produced
those files. Observed on this machine on 2026-08-02 — core holds **29** files
under `.planning/skill-observations/`, **all 29** named
`<stamp>--<sessionId>.{md,jsonl}` and **none** matching `skill-router-log.sh`'s
`skill-router-{date}.jsonl`.

**A previous revision recorded 141 / 137 / 4 here and cited it as a measurement
of core.** Round 9 re-ran the count and got different figures, which is the
finding: this directory is gitignored per-machine local state, so it differs
between machines, grows every session, and cannot be reproduced by any reviewer.
Precise counts from it are dated observations, and the numbers moving does not
weaken the conclusion — it strengthens it, the non-hook producer now accounting
for 29 of 29 rather than 137 of 141. What is corrected is the epistemic claim,
not the direction.

The `<stamp>--<sessionId>` files come from a **global** `SessionEnd` hook in
`~/.claude/settings.json` running
`agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`, whose
header states it writes exactly that path.

So the dominant producer of this fleet's `.planning/` traffic is not a project
hook, is registered once globally rather than seven times per-project, and writes
into **every** repository opened — not just the seven this change touches.

The decision to delete the pair is unchanged: they are hooks, they do write
there, and the policy is real. What changes is the claim attached to it. This
change **reduces** the violation; it does not end it, and no report of it SHALL
say the fleet is compliant with the frozen-archive policy afterwards.
`meta-observer` is recorded as a follow-up (see Deferred follow-ups) rather than
pulled into scope: it lives in another repository, it is wired through global
host settings rather than any project's `settings.json`, and unregistering it is
an operator-level change this change has no mandate to make.

The lesson is the one this change already teaches about `design-shotgun-gate`
and about `database-sentinel`'s middle column: **a producer was identified by the
name of a nearby file rather than by what actually writes.** Three rounds of
vendor review and six revisions did not catch it, because every reviewer read the
sentence as evidence rather than checking whether the named hook exists in the
repository the evidence cites.

*Alternative — relocate storage outside `.planning/` and keep the feature.*
Preserves session-start context warm-up and keeps the existing bats tests
meaningful. Rejected: the logs are gitignored in every repo and tracked in
none, so nothing durable is being preserved; and relocating is more work than
deleting for a feature whose whole output is ephemeral and local.

**"The only consumer of the log is the other hook" was part of that rejection and
is withdrawn until it is shown.** Round-8 opencode identified it as exactly the
inference this change indicts three times over — `design-shotgun-gate`,
`database-sentinel`'s middle column, and the `meta-observer` misattribution above
— a consumer identified by name proximity rather than by a search. It is also the
claim Decision 11's own transitive-consumer clause exists to require evidence
for: "anything that invokes the hook, reads what it writes, or changes behaviour
if it stops running." Applying that clause to every hook except the one whose
deletion this decision argues is the exemption pattern Decision 9 rejects.

The claim is therefore **pending**, and task 5.0c is what discharges it: the
fleet-wide search for readers of `skill-router-*.jsonl` is run and cited, not
implied. The deletion does not depend on the outcome — the hooks write into a
frozen directory and that alone justifies it — but the *rejection of relocation*
does, because a second consumer would mean deleting the producer breaks something
that is not being deleted with it.

*Alternative — keep in place and delimit on read.* Rejected: it closes the
injection path but leaves both hooks writing into a folder that is supposed to
be frozen, so the policy contradiction survives for the next reader.

**On the injection risk specifically:** it was initially relayed as "a
committed log line can inject into every session fleet-wide". That is false
here — the logs are gitignored everywhere and tracked nowhere, so injection
requires local filesystem write access, and anyone holding that can edit
`CLAUDE.md` or the hooks directly. It is local-only, not a propagation vector.
Deletion is justified by the policy violation and the low value, not by an
overstated §14 risk.

### Decision 4: Both shims fail open and warn; provisioning carries the guarantee

*This reverses the previous revision, which had `database-sentinel` fail closed.
The reversal is forced, not preferred.*

The fail-closed argument was: nothing backstops this hook, so allowing on
non-resolution drops a control silently. That reasoning is sound and the
conclusion still does not work, because a shim cannot block narrowly. Hooks are
registered against **tool names**, and the registration is on disk:

| Repos | `database-sentinel` matcher |
|---|---|
| six of seven | `Bash\|Edit\|Write` |
| `callbot` | `Bash\|Edit\|Write\|MultiEdit` |

A shim that blocks when it resolves nothing therefore blocks **every Bash
command and every file edit in the repository** — not `.env` and `migrations/`,
which is what the previous revision claimed it would block. To block only the
protected set, the shim would have to parse the tool payload and apply the
path and SQL patterns itself: behaviour the shim contract forbids, and a second
copy of exactly the logic this change exists to de-duplicate. The reviewer's
finding was that these two requirements cannot both hold. They cannot.

**Chosen:** both shims allow the call when they resolve nothing, and make the
failure visible in the transcript. The guarantee moves to provisioning, where it
costs nothing to enforce:

- the installer verifies each shimmed implementation is present and executable;
- the rollout publishes and verifies before replacing any project copy.

*Alternative — fail closed anyway and accept the blast radius.* Rejected: it
converts a missing optional file into an unusable repository, and the operator's
recovery path runs through the tools it blocks.

*Alternative — narrow the matchers so fail-closed is survivable.* Rejected:
matchers select tools, not paths, and every tool this hook inspects is one the
repo needs constantly.

*Alternative — let the shim inspect the payload just enough to decide.*
Rejected: this is the drift the change removes, reintroduced in seven places
and in the one file per repo that is hardest to keep in sync.

What makes the reversal acceptable rather than merely necessary is Decision 7:
the control was never a boundary, so failing open loses less than the earlier
framing implied.

**The exit code is not incidental — round 5 found the warning had no channel.**
Two reviewers questioned whether stderr from an exit-0 PreToolUse hook reaches
anyone. Checked against the host documentation: it does not. On exit 0 stdout
goes to the debug log and is not shown in the transcript, and stderr is surfaced
only for non-zero exits, where "the transcript shows a `<hook name> hook error`
notice followed by the first line of stderr".

So "fail open with a loud warning" as written would have been fail open with no
warning — silent protection loss, the precise outcome the fail-closed posture
was adopted to avoid, arrived at from the other direction.

The fix is in the same mechanism: **exit 1, not 0.** Exit 2 blocks; any other
non-zero code is a *non-blocking* error whose first stderr line is shown. That
gives exactly the primitive this design assumed existed — allow the call, tell
the operator — and it is now specified rather than left to a stderr write whose
visibility nobody had checked.

**That finding covers `PreToolUse` only, and this decision's heading claims both
shims.** Round-8 opencode found the gap: the delta requires a shim's warning
channel to be verified against the host docs for *its own event class* before the
shim is written, and `normalize-claude-md` is `PostToolUse`, whose exit semantics
differ — exit 2 feeds stderr back to the model, other non-zero codes go to the
operator, and there is no call left to block. Nothing here recorded that. So the
change wrote the verification requirement and shipped a claim that violates it,
in one revision.

**Corrected:** "both shims fail open and warn" is true of `database-sentinel` and
the change gate, both `PreToolUse`. For `normalize-claude-md` the posture is
**fail open with the reporting channel unestablished** until task 2.10 records
the verified `PostToolUse` behaviour. The distinction is not pedantic — it is the
exact shape of the exit-0 defect this decision exists to fix, one event class
over.

### Decision 5: `callbot`'s `database-sentinel` semantics are canonical — minus its dead clause

Its `.env` matching is a wildcard (`.env|.env.*|*/.env|*/.env.*`) with an
explicit `.env.example`/`.env.template` allowance; `dashboard` and `cparx`
enumerate four specific suffixes and would miss `.env.secret` or any other
novel name. `callbot` also handles `MultiEdit`, which the others omit.

Reconciling by recency would have narrowed the protection. This is why the
spec delta requires reconciliation to take the superset rather than the newest.

**But the selected copy also carries a live blocking defect, and the previous
revision would have shipped it to all seven repos.** Lines 57–67 block every
`migrations/` edit unless `.planning/current-phase/migrations-approved` exists,
and the remedy printed at line 63 names `/gsd-discuss-phase`, removed from the
fleet on 2026-07-28. `callbot` has no `.planning/current-phase/` directory, so
**every migration edit in that repo is blocked today** — the same dead-sentinel
mechanism as `design-shotgun-gate`, in the hook this design classified as
healthy, found by review rather than by the measurement pass that produced the
table above.

**Chosen:** adopt `callbot`'s matching and drop the `migrations/` clause
entirely. Its intent — a human decision before schema changes — is served by the
deferred advisory database-review prompt, which fires on a real trigger instead
of a sentinel file.

The lesson is narrower than "check harder": superset selection reads for what a
variant *adds*, and this clause was an addition. Reading for additions is not
the same as reading for whether each addition still fires.

### Decision 6: `MultiEdit` coverage requires a `settings.json` edit in six repos

Adopting an implementation that handles `MultiEdit` changes nothing in a repo
whose matcher never delivers `MultiEdit`. Six of the seven are in that state.

**Chosen:** the rollout updates the matcher in those six as part of replacing the
copy with a shim, and verifies per repo rather than assuming the edit took.

This is recorded as a decision because the previous revision listed
"two projects gain `.env` protection" as a delivered behaviour change while the
mechanism to deliver it was absent — an impact claim ahead of its implementation.

**Round 5 challenged the premise, and the challenge does not survive checking.**
A reviewer argued that the host's `Edit` matcher also matches `MultiEdit`, which
would make `callbot`'s explicit entry redundant and this decision unnecessary.
The host documentation says the opposite: a matcher composed only of letters,
digits and separators is an **exact string** comparison — "`Bash` matches only
the Bash tool" — and matching both requires a regex such as `Edit|MultiEdit`.
The decision stands.

**A different fact does reduce its value, and is worth stating.** `MultiEdit`
does not appear in the host's current tool reference, and is not present in the
tool set of the Claude Code version running this change. The matcher edit is
therefore correct and harmless, but it may be provisioning coverage for a tool
this host no longer offers. Task 4.8 verifies against the host in use rather
than asserting delivery, and the spec requirement is written generically rather
than around this tool's name.

### Decision 7: Describe the hook as best-effort, because it is

`database-sentinel` was called "a security control with no CI floor beneath
it". That framing is what produced the fail-closed posture Decision 4 had to
withdraw, and it is not accurate. Review named the gaps and they check out
against the implementation:

- the `Bash` arm matches `DROP TABLE`, `TRUNCATE TABLE` and `DELETE FROM`
  without `WHERE`. Writing `.env` from `Bash` is not matched at all, and
  `psql -f script.sql` never presents SQL to the regex;
- the implementation is a user-writable file in a shared directory executed by
  seven projects — write access to it changes what all seven enforce.

**Chosen:** call it best-effort defence in depth, name the bypasses in the
capability, and let the fail posture follow from that rather than from an
overstated claim. A control described accurately can be relied on correctly.

### Decision 8: `agents-task-viewer` receives no `normalize-claude-md` file at all

Its `normalize-claude-md.sh` carries an in-file note dated 2026-07-21 stating
it is deliberately not wired into `settings.json`. It was initially miscounted
as a drifted third version; the rollout would have re-registered it and undone
a deliberate decision.

**The previous revision said it "is shimmed like the others and stays
unregistered", while task 4.3 left the choice open between shipping an
unregistered shim and shipping nothing.** A reviewer found that the proposal
asserted one outcome, the tasks permitted either, and the impact counts
("eight hooks become three", "six projects receive the fix") silently assumed
the first. Three artifacts, three positions.

**Chosen:** ship **no file**. The opt-out forbids wiring the hook; it does not
require an unwired file to exist, and task 4.3's own reasoning is decisive — a
shim nothing invokes is a copy that can drift unnoticed, which is the exact
failure mode this change exists to remove. Shipping it unregistered would create
the fleet's only file that is simultaneously required to be byte-identical across
projects and guaranteed never to run, so nothing would ever detect it rotting.

Consequences, applied consistently everywhere they appear:

- `agents-task-viewer` carries **two** hooks (`openspec-change-gate` shim and
  `database-sentinel` shim), not three.
- "Eight hooks become three" holds for **five** of the seven. `agents-task-viewer`
  is eight-becomes-two. `agenticapps-dashboard` is **seven**-becomes-three, having
  deleted `design-shotgun-gate.sh` itself on 2026-08-01; this consequence list
  said "six of the seven" until that deletion made it false.
- **Six projects run `normalize-claude-md`; five gain something from it.** The two
  are not the same count and the earlier text used one number for both.
  `agents-task-viewer` deliberately does not run it. `agenticapps-dashboard` runs
  it but already carries the 2026-07-26 fix, so it receives no fix it lacked — it
  is the source of the canonical version, not a recipient.
- The opt-out is preserved more strongly than before — there is no file to be
  re-registered by a later rollout that has forgotten why.

### Decision 9: The change-gate shim is migrated, not exempted

**Subject of this decision, stated by path because round 9 showed the name is now
ambiguous.** It is `<project>/.claude/hooks/openspec-change-gate.sh` **in the
seven consuming projects** — the published-resolution shim. It is *not*
`agenticapps-workflow-core/.claude/hooks/openspec-change-gate.sh`, which did not
exist when this table was measured, arrived on 2026-08-02 with
`core-self-enforcement`, and is the self-hosting binder covered by Decision 17
and task 4b.10.

A round-9 reviewer read this table as describing core's file and reported two of
its three rows as already fixed. Checked against the projects: `agents-task-viewer`,
`cparx` and `callbot` each still carry four references to the `<repo>/bin/`
candidate and each still exports `OPENSPEC_GATE_SELF`. The table is accurate for
its subject — but it never named that subject, and a same-named file now exists
one repository over. That is the escaped-pipes lesson again: an artifact that
renders its own referent ambiguously invites a false reading, and the fix belongs
in the artifact.

The measurement table classified `openspec-change-gate.sh` as "Template —
unchanged" and the design built the shim contract from it. A reviewer then
checked the template against the contract derived from it. It fails three ways:

| Requirement | The exemplar |
|---|---|
| two resolution candidates | carries the third, `<repo>/bin/`, now forbidden |
| unresolvable shims report | `[ -x "$GATE" ] \|\| exit 0` — silent |
| identity is not hardcoded | `export OPENSPEC_GATE_SELF="${OPENSPEC_GATE_SELF:-claude}"` |

Its header also states the `>= 2` reviewer floor, in all seven projects — sites
the companion change's enumeration missed precisely because this change said
the file was untouched. The two changes' scopes had a seam, and the defect was
sitting in it.

**Chosen:** migrate the first two. The identity line is left to the companion
change, which retires `OPENSPEC_GATE_SELF` as an identity source — both changes
editing one line would conflict.

**So this change does not make the gate shim fully conformant, and the audit
table above must not be read as saying it does.** A reviewer caught the
overstatement: two of the three violations are fixed here, the third is fixed by
`track-and-conform-plan-review`, and until that change lands the shim still
hardcodes an identity. Correspondingly, "identity is not hardcoded" is *not* a
requirement in this change's delta — the shim contract here permits host
self-identification, because retiring it belongs to the other change.

**Landing order:** either change may land first; the identity line is only
resolved once `track-and-conform-plan-review` has. If this change lands alone,
the residual non-conformance is that one line, and it is recorded rather than
claimed away.

*Alternative — scope it out as pre-existing.* Rejected: the rules were derived
from this file, so exempting it makes them advisory for the one hook every
project runs on every edit.

### Decision 10: `claude-workflow` is in scope, because the scaffolder rebuilds what this deletes

`claude-workflow` vendors all eight hooks in `templates/.claude/hooks/` **and**
`setup/snapshot/hooks/`, plus pre-change matchers in
`setup/snapshot/claude-settings.json`. Every project scaffolded after this
change would receive the five deleted hooks, un-shimmed copies of the two
survivors, and a `Bash|Edit|Write` matcher — including `design-shotgun-gate`
and the `migrations-approved` clause, so a new project would be born with both
live blocking defects this change exists to remove.

**Chosen:** update templates and snapshot in the same change, keeping
`migrations/check-snapshot-parity.sh` green.

*Alternative — follow-up change.* Rejected: the window between them is exactly
when new projects are scaffolded, and the failure is silent at scaffold time and
loud only much later, in the new project.

This also corrects the non-goal. "Not re-vendoring to the four hosts" is about
pushing workflow content outward; removing stale vendored hooks is the reverse
operation, and reading the non-goal as covering it is what excluded the repo.

### Decision 11: Deletion requires an enforcement check, not just a binding check

The round-4 test was "no documented binding, and produces no evidence artifact".
A reviewer showed that is insufficient: a hook can **enforce** a §02 gate by
checking its evidence without being the named skill binding and without
producing the artifact. §02 itself describes exactly that arrangement for
`plan-review`, where hosts SHOULD enforce with a programmatic gate.

**Chosen:** a third clause — the hook neither checks a gate's required evidence
nor is depended on by something that does. All three must hold.

The correction has a pattern to it. Round 3 replaced "not named in §02" with
"not the documented binding"; round 4's version was still one relationship short.
Binding, production and enforcement are three distinct things, and each round
found the previous test collapsing two of them.

**Round 7 found the pattern had one more instance: all three clauses were scoped
to §02.** A reviewer pointed out that a hook can clear every §02 test and still
be required by §17, §18, a capability spec under `openspec/specs/`, or a
project's own policy — and that the rule as written would authorise deleting it.
The three clauses were sound; the *universe* they quantified over was one section
wide.

**Chosen:** the clauses are evaluated against every applicable specification and
against transitive consumers — anything that invokes the hook, reads what it
writes, or changes behaviour if it stops running. Clearing §02 is necessary, not
sufficient.

**Round 9 found the fifth instance of the same pattern, and this one reverses an
argument inside this change.** A reviewer showed clause 3 still tested one
*mechanism*: a hook can enforce a gate through a proxy — a sentinel file, a
marker, an exit status, an API result — without ever reading the evidence
artifact the gate names. The clause is broadened to "does not enforce a gate by
any means", with the question being *does this hook make some gate harder to
pass*.

That has a consequence the change has to own rather than absorb.
`design-shotgun-gate.sh` gates on `.planning/current-phase/design-shotgun-passed`
— a sentinel, which is to say a **proxy** — so under the broadened clause it
*was* an enforcement of the `design-shotgun` gate, and "it checks a sentinel §02
never names" no longer clears it for deletion. It convicts it.

The deletion still holds, on a different argument that this change already makes
elsewhere: **unreachability**. Since GSD's removal no surviving tool can write
that sentinel, so the check can never pass; it does not enforce a gate, it blocks
unconditionally. The two arguments have different lifetimes, which is why the
substitution matters — "not the named evidence" would license deleting a working
proxy enforcement, while "unreachable" licenses deleting only one that cannot
fire.

Fifth round, same shape: each time, the test was right about a relationship and
wrong about its extent.

That this is the fourth consecutive round to narrow the same rule is itself
worth recording. Each earlier round fixed *which relationship* was tested and
left *what it was tested against* unexamined, because §02 is where gates are
listed and the question "which spec?" never surfaced. A test can be
right in form and wrong in scope, and reviewing the form repeatedly does not
surface the scope.

### Decision 12: Publication is atomic per artifact, never across artifacts

The previous revision required multi-artifact publication to be atomic and
required each manifest row to be "updated in the same operation as the file it
describes". A reviewer showed both are impossible: two `rename(2)` calls are two
operations, so a file and its manifest row cannot be swapped together, and
per-file renames do not compose into a multi-file transaction. It also noted the
shared manifest needs locking, which nothing specified.

The change had already half-noticed this — task 3.2c described a *per-artifact*
crash guarantee while task 3.2b demanded a multi-artifact one, and the two sat
four lines apart.

**Chosen:** specify what is achievable and say plainly what is not.

- per-artifact atomicity via temp-write + `rename` in the destination directory;
- whole-manifest atomicity — rewrite the file entire and `rename` it, never edit
  rows in place;
- an exclusive lock around the publishing critical section, which addresses the
  *lost-update* failure that atomicity does not touch;
- artifact renamed before its manifest row, so the reachable inconsistency is
  "present but unattested" rather than "attested but absent";
- reconciliation is the check's job, reported in both directions.

*Alternative — a journal or two-phase commit.* Rejected: it builds a transaction
manager to install three shell scripts, and the failure it prevents is already
detectable and repairable by re-running the installer.

The general point: an unachievable guarantee is worse than a modest one, because
it reads as stronger and is discovered only by whoever tries to implement it —
or, if nobody checks, never.

**Round 8 showed the achievable guarantee was still under-specified, in two
ways.**

*The interruption contract described two different algorithms.* "The manifest is
either the pre-run version or the post-run version" is a manifest written **once
per run**; "an artifact is renamed before the manifest row naming it" reads as a
row **per artifact**. codex found both sentences in the same requirement. The
algorithm is now written out — lock, read manifest, rename every artifact, then
rewrite the manifest once, unlock — and the per-artifact ordering clause is
satisfied by all of step 3 preceding step 4 rather than by interleaving.

*And it covered a first install only.* Republishing over an artifact that already
has a row leaves, on a crash, a **stale row rather than no row** — the artifact
is at its new bytes and the manifest still attests the old ones. The previous
text had no classification for that: "present but unattested" is wrong, because
the row exists, and "clean" is wrong, because the digest does not match.

That gap turned out to be the same one as codex's objection to the state table,
approached from the other end. The three states were defined by **history** —
"the installer has never run", "a publishing run completed" — which nothing on
the machine records, and which classifies a completed-then-deleted or
hand-edited install as *provisioned*: the precise condition the manifest check
exists to detect, in the one place it could not be named.

**Chosen:** define provisioning by what a check can **observe**, on **two axes**
rather than one list.

The first attempt at this added a fourth state, *drifted*, alongside the three —
and round 9 showed a flat list cannot work, because the members overlap: a
manifest whose files are all absent is both *unprovisioned* and *drifted*; one
unattested file beside one missing file is both *partially provisioned* and
*drifted*. "Exactly one of four" was false of a set I had just written.

The two things being conflated are **how much is installed** (`none` / `partial`
/ `complete`) and **whether what is installed can be attested** (`attested` /
`drifted`). They vary independently, so the state is the pair, and the case that
broke the list — everything deleted while the manifest still claims otherwise —
is `none` + `drifted`, which needs a different remedy from a clean fresh clone
and previously had no name. The interrupted upgrade and the tampered install both
land on `drifted`; the remedy for both is re-running the installer.

Observational definitions are also what make either axis computable at all; the
earlier ones could only be asserted.

### Decision 13: The no-project-override rule moves from the shim to configuration validation

Task 2.7b required a failing test proving the override is honoured "from the
process environment only" and that a value in a project's `.claude/settings.json`
`env` block does not disable the hook. A reviewer showed this is unimplementable:
the host injects `env` values into the hook process's environment, where they are
indistinguishable from operator-exported ones. A behaviour-free shim reads `$VAR`
and has no provenance to inspect.

This is a requirement no test could fail, which is the same defect class as an
unachievable guarantee: it reads as protection and delivers none.

**Chosen:** keep the prohibition **as policy**, and move enforcement to the only
layer that can see provenance — where it becomes detection rather than
prevention. A conformance check scans every project for repository content that
sets an override variable and reports each occurrence against the repository. The
value still takes effect at runtime — that is precisely why it must be visible in
review rather than silently dropped.

**Round 8 found two things wrong with how that was written up.**

*First, "a cloned repository must not be able to switch off the gate that governs
it" survived into the delta as though the mechanism delivered it.* It does not:
the override takes effect, and the check reports it afterwards. codex put it
exactly right — detection is not prohibition. The sentence is struck. What
remains is a policy (projects SHALL NOT set the variable) and a detection
(violations are reported), with a live window between them that the delta now
names instead of eliding.

*Second, the scan covered one provenance vector out of several.* opencode noted
that a repository can ship an `.envrc`, a bootstrap script, or setup instructions
a human then runs, and the resulting environment is indistinguishable from an
operator's own choice. The scan is broadened to those vectors — and, more
importantly, it is now required to **report its own incompleteness**: a green
result means *no known vector found*, never *no override is set*. A check that
cannot be complete and says so is worth having; one that reads as complete is the
same defect class as the unimplementable requirement it replaced.

**And a third exposure was omitted entirely, on the other side of the same
variable.** Both the kill-switch note and the invalid-override rule address an
override pointing at a file that is *missing*. An override pointing at a file
that **exists** is `exec`d — on every `Bash`, `Edit` and `Write` — with the
operator's privileges. Combined with the provenance vectors above, that is
repository-supplied code execution at the tool boundary, which is strictly worse
than the hook being switched off and was nowhere in the coverage boundary. codex
named it; it is now normative in the delta and belongs in the hook's documented
boundary rather than only in a requirement.

*Alternative — remove the override entirely*, as the reviewer also offered.
Rejected: the override is what makes staged rollout and testing possible without
editing seven projects, and Decision 4's fail-open posture depends on being able
to substitute an implementation. Removing it to enforce a rule about it costs
more than the rule is worth.

The guarantee is now weaker than the previous text claimed, and that is the
correction rather than a regression.

### Decision 14: The git `pre-commit` wrapper is out of scope, and the fallback claim it supported was false

The capability said an unprovisioned machine still has the pre-commit hook and CI
beneath a fail-open shim. A reviewer doubted the pre-commit half. Checked against
`reference-implementations/openspec-change-gate/pre-commit`, the doubt is
correct, and sharper than stated: the wrapper resolves `$OPENSPEC_GATE` →
`$OPENSPEC_CHANGE_GATE` → `~/.agenticapps/bin/` → **`<repo>/bin/openspec-change-gate.sh`**,
then prints a warning and `exit 0`.

Two things follow. First, its last resort is exactly the `<repo>/bin/` candidate
Decision 1 removes from shims — so the change's own resolution rule, applied
here, would strip this wrapper's final fallback and leave it *weaker*. Second, on
a machine with no shared install, shim and wrapper fail open together and **CI is
the only floor**.

**Chosen:** exclude the wrapper from the two-candidate rule explicitly, and
require any claim that pre-commit backstops a fail-open shim to name the
provisioning state it assumes. It backstops a provisioned machine. It does not
backstop the case the claim was made about.

*Alternative — bring the wrapper under the shim contract.* Rejected: it is not a
tool-boundary shim. It runs outside the host, has no matcher breadth, and its
fail-open exists for a documented reason — a commit hook that hard-fails on
missing tooling trains people into `--no-verify`, disabling the floor
permanently.

### Decision 15: The shim version marker gets a format, an authority, a comparison and a check

Tasks 2.9 and 4b.6 already stamped a marker, so the reviewer claim that the
change "does not add this marker" is wrong. The companion objection is right and
is the one that matters: a marker with no defined format, no authoritative
expected value, no comparison procedure and no check cannot make anything
detectable. It is a string in a comment.

**Chosen:** `# shim-contract: <semver>` in the first 10 lines, matching the
gate's `# gate-version:` convention; the template under
`reference-implementations/project-hooks/` is the authority; lower is stale,
absent or malformed or *higher* is unrecognised; and a conformance tool
enumerates every binding project and reports each one's state.

Higher-than-template counting as unrecognised rather than "newer, fine" is the
non-obvious part: a project ahead of the tracked template is carrying something
core cannot account for, which is drift in the direction nobody looks.

### Decision 16: The fail-open report gets a repetition policy, chosen after checking what the host offers

Round-8 opencode found a contradiction between two of this design's own
arguments. Decision 14 rejects a fail-closed pre-commit wrapper because
persistent unavoidable failure "trains people into `--no-verify`". Decision 4
then adopts a posture that emits a non-blocking hook error on **every** `Bash`,
`Edit` and `Write`, on every unprovisioned machine, indefinitely — the same
conditioning pressure, applied to the transcript instead of the commit. No
rate-limiting was specified, and none was rejected. That second half is the real
finding: an unstated policy is not a considered one.

The asymmetry the objection anticipates is real but only partial. A blocking
pre-commit hook has a durable escape hatch that operators learn once and keep
(`--no-verify` disables the floor permanently); a non-blocking notice has none,
and ignoring it leaves the hook running. But "they will learn to ignore it" and
"they will learn to suppress it" differ mainly in who performs the suppression,
and the fleet-wide cost is the same: hook-error notices stop being read,
including the ones that matter.

**Chosen:** require the policy to be *stated*, name the three admissible values —
per invocation, once per session, once per interval — and pick one at
implementation after establishing what the host actually permits. Leaving it
unstated is what the previous revision did, and an unstated policy silently
defaults to the noisiest option.

The obstacle is specific and is why this is not simply decided here. A
per-session policy needs the session identifier, which the host delivers in the
hook's **stdin payload** — the payload the shim must forward to its
implementation intact. A shim that reads stdin to find the identifier has
consumed the input its implementation needs, and re-supplying it is behaviour of
exactly the kind the shim contract exists to forbid. So the choice is gated on a
verification: if no session identifier is reachable without consuming stdin, the
policy is per-interval (a dated marker) or per-invocation, and the reason is
recorded rather than the option quietly dropped.

Writing a marker at all is a carve-out from "behaviour-free". It is bounded — one
marker path, read and written, never the tool payload — and it is stated as a
carve-out so that it does not become a precedent for the payload inspection
Decision 4 rules out.

**Round 9 found this policy pointed at the wrong report, and that the contract
sentence was never amended for it.** Two corrections:

1. *The kill-switch report is carved out and always fires.* A rate limit adopted
   to quiet the **unprovisioned-machine** report — a benign, expected,
   self-correcting condition — would also have quieted the **invalid-override**
   report, which says a hook has been switched off on an otherwise healthy
   machine, and for the §18 gate that its one blocking condition is not running.
   The noisiest signal and the most important one were being governed by a single
   policy. The invalid-override report is now per-invocation, always.
2. *The contract line still read absolutely.* "No behaviour of its own beyond
   resolution, host self-identification, and `exec`" coexisted with a permitted
   marker (this decision) and mandated reporting (Decision 13) — three clauses in
   the contract, five behaviours in the capability. The delta now enumerates a
   closed list. A rule contradicted by its own document is precisely what this
   change exists to remove, and it had grown one in the act of removing others.

### Decision 17: Two shim profiles, because one contract cannot describe both bindings

Round-8 codex found the contract asserting two things that cannot both hold:
every shim resolves the shared install, and every shim is byte-identical to its
siblings — while core deliberately resolves its own working tree, and does so for
a reason this fleet documents in ADR-0028. One version marker was being asked to
represent both bindings honestly.

The change had half-answered this already, and that is the instructive part.
Task 4b.10 recorded the applicability split correctly — 4b.1 does not apply to
core, 4b.3 does not apply, 4b.6 does — and the delta's propagation requirement
mentioned the inversion in passing. So the *tasks* knew, and the *normative text*
did not. A split recorded only in the task list is a note; the rule it qualifies
still reads as universal to anyone checking conformance against the delta.

**Chosen:** two named profiles in the delta.

- **published-resolution** — every project that consumes a shared hook: override,
  then `~/.agenticapps/bin/<hook>.sh`.
- **self-hosting** — the repository whose working tree is the authoritative
  source: that file, directly.

Each binder declares its profile; each requirement is evaluated against the
declared profile; byte-identity is required within a profile and never across
one. The marker, the behaviour-free rule and fail-open-and-report bind both,
which is precisely what makes a single marker meaningful — it attests the clauses
the two profiles share, and nothing else.

At most one binder per hook is self-hosting. A second would be a second
authority, which the capability's first requirement forbids, so the profile
cannot be used to exempt a project from resolution by declaring itself special.

*Alternative — exempt core by name.* Rejected: an exemption for one repository is
the "rule with an unstated exemption for its own exemplar" that Decision 9
rejects. A profile is a rule; an exception list is not.

**Round 9 found this decision's own description of core's hook wrong in two
places, from a file I had read.** Both are corrected in the delta:

1. *"A self-hosting binder has neither candidate to carry."* False. Core's hook
   resolves `${OPENSPEC_GATE:-$ROOT/reference-implementations/...}` — it honours
   the override exactly as a project shim does. The profiles differ in the
   **second** candidate only. The error was compressing "no shared install and no
   `<repo>/bin/`" into "neither candidate", one paragraph after reading the file.
2. *Fail-open-and-report binds both profiles.* Core's hook **fails closed**
   (`exit 2`) when it cannot resolve its own root, with a comment defending the
   choice at length. Reading it properly shows the fleet already distinguishes two
   conditions this design had collapsed into one: an **absent implementation**
   (tooling missing — allow, the blast-radius argument holds) and an
   **unresolvable root** (the binder cannot tell an absent gate from one sitting
   beside it — block, because allowing means silently ungating a repository whose
   gate is present and working). The delta now carries both, and scopes the second
   out of the fail-open rule with its reason, as the exemplar requirement demands.

Point 2 is the more useful finding: it is not that core deviates from the rule,
it is that the rule had one clause where the fleet had two. The exemplar was
right and the capability derived from it was under-specified — which is the same
direction of error as Decision 9, arriving from the opposite side.

### Decision 18: What a missing gate loses is validation, not review

Round-8 codex found this change stale against `change-gate-enforcement`. The
delta and its prose repeatedly described a missing shim, or a typo'd override, as
bypassing "§18's review requirement". The gate has no such requirement to bypass:
it blocks on exactly one condition — `openspec validate --all` is not green —
while the reviewer count, verdict grammar, independence and trailer are computed
and **reported, never enforced**. Verified against
`openspec/specs/change-gate-enforcement/spec.md` before correcting.

So the loss on an unprovisioned machine is (1) validation enforcement, the only
block there is, and (2) the *reporting* of review state, which was advisory
before the gate went missing. Calling it lost review enforcement names a block
that does not exist and passes over the one that does — which understates the
change's own cost while sounding more alarming.

**Chosen:** correct every site, and state the rule going forward: claims about
what a missing, unresolvable or overridden gate costs are written against the
blocking condition.

Worth recording why this survived eight rounds. The phrasing was inherited from
the era when the gate did block on the reviewer floor, and each revision edited
the sentences *around* it. Nothing in a review of this change's internal
coherence would surface it, because it is coherent — it is just describing a
different gate than the one the fleet now ships. That is a distinct failure mode
from the ones this change has been catching, and the only defence is checking
prose against the current spec rather than against the previous revision.

### Refuted with evidence: the matchers are not escaped, our table is

Round-8 opencode read the matcher column of the table above as `Bash\|Edit\|Write`
and reasoned that if the host parses the matcher as an ERE, `\|` is a literal
pipe, so `database-sentinel` has matched nothing anywhere and the whole
fail-open cost analysis concerns a control that never ran. That would be a
serious finding if the premise held. It does not: the backslashes are **markdown
table-cell escaping in this document**, not bytes on disk. Parsed from the JSON:

    $ python3 -c "import json;print(repr(json.load(
        open('cparx/.claude/settings.json'))['hooks']['PreToolUse'][0]['matcher']))"
    'Bash|Edit|Write'

    $ grep -o '"matcher"[^,]*' cparx/.claude/settings.json | head -1
    "matcher": "Bash|Edit|Write"

Real pipes, no backslashes, in all seven.

**The residue of the objection is still owed an answer, and is not discharged by
the above.** A well-formed matcher is not a firing hook. This change has verified
the matcher's *syntax*; task 4.8 verifies `MultiEdit` *delivery*; nothing yet
verifies that the base matcher fires today. Until something does, "unprovisioned
machines lose `database-sentinel` protection" states a loss whose baseline is
assumed. Task 4.8 is extended to establish the baseline first.

The reviewer reached a false conclusion from a true reading of the artifact it
was given, which is a defect in the artifact: a table that renders its own data
ambiguously invites exactly this. The escaping stays — a raw pipe would break the
table — and this note is what disambiguates it.

### Note on a reviewer claim that has now been wrong twice

Both round-3 and round-4 codex reviews assert that the change's `REVIEWS.md`
counts codex "despite Codex being the implementing host". It is not: this change
is authored on `claude`, and codex is an eligible independent reviewer for it.
The claim was checked and refuted in round 3 and is recorded here so a round-6
reader does not re-litigate it.

The stale-reviews half of the same objection was correct both times, and is
addressed by re-reviewing after each revision — which is what produced the round
that found the two defects above.

## Risks / Trade-offs

- **A shim is only as good as the install**, and both shims now fail open. A
  project on an unprovisioned machine loses `.env` and destructive-SQL matching
  while appearing to have it. Mitigated by the report on each invocation (subject
  to Decision 16's repetition policy), by installer verification, and by
  publishing before any project copy is replaced — but not eliminated. This is
  the cost of Decision 4, and it is smaller than the alternative only because
  Decision 7 is true.
- **The protection stops travelling with the repository and starts travelling
  with the machine, and only the first was ever automatic.** Round-8 opencode
  named this as a regression rather than a trade-off, and it is right: today
  `database-sentinel` runs on any clone with zero provisioning, because the
  implementation is *in the clone*. After this change it runs only where the
  installer has run, and **every existing developer machine enters the
  unprovisioned state at the moment it pulls the shim** — via an ordinary
  `git pull`, with nothing in the flow that would prompt anyone to install.
  The mitigations listed above do not reach this: every check the change
  specifies is per-*repository* (markers, byte-identity, the settings scan), and
  publish-before-replace orders exactly one machine — the one doing the rollout.
  Answered by a per-machine provisioning check in the delta, and by rollout
  communication rather than by ordering, since no ordering on the rollout machine
  constrains anyone else's.
- **Deleting the telemetry pair loses session-start context warm-up.** Accepted
  — the data is ephemeral and gitignored, so nothing accumulates that anyone
  could later want.
- **Five deletions is a lot to do at once.** Mitigated by all five being
  independently justified above, none being a §02 gate, and rollout proceeding
  one repo at a time with verification between.
- **`agents-task-viewer`'s 314-line variant may contain a real fix.** Mitigated
  by diffing rather than overwriting.

## Migration Plan

No migration document — per the step 1 decision, a migration would install
machinery to delete machinery. Projects are edited directly.

Order matters, because a shim is inert until its implementation exists and — now
that shims fail open — a project whose install has not run silently loses the
protection rather than announcing it by blocking:

1. Land the two canonical implementations in core, `database-sentinel` **without
   the `migrations/` clause**.
2. Publish both to `~/.agenticapps/bin/`, including the multi-artifact install
   step and the installer's present-and-executable verification, and confirm each
   behaves identically to the copy it replaces apart from the dropped clause.
3. Only then replace project copies with shims, one repo at a time.
4. In the same per-repo step, update the `database-sentinel` matcher to include
   `MultiEdit` — required in six of the seven — and verify it fires.
5. Delete the five hooks and their `settings.json` entries.

Rollback is `git revert` per repo; published implementations are additive and
harmless if project copies remain. The one irreversible-by-revert effect is the
dropped `migrations/` clause, which is the point rather than a side effect:
reverting a repo restores its own copy, not the fleet-wide block.

## Open Questions

- Does `agents-task-viewer`'s 314-line `normalize-claude-md` variant contain a
  fix worth folding into canonical? Resolved by diff during task 1, not by
  assumption.
- Do the deleted hooks' bats tests cover anything still wanted? The telemetry
  pair has its own tests; confirm they test only the deleted feature before
  removing them.
