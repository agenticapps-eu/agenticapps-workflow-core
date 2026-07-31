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
- Propagate `dashboard`'s `normalize-claude-md` fix to the other six.

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

*Alternative — relocate storage outside `.planning/` and keep the feature.*
Preserves session-start context warm-up and keeps the existing bats tests
meaningful. Rejected: the logs are gitignored in every repo and tracked in
none, so nothing durable is being preserved; the only consumer of the log is
the other hook; and relocating is more work than deleting for a feature whose
whole output is ephemeral and local.

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

### Decision 8: `agents-task-viewer` stays unregistered

Its `normalize-claude-md.sh` carries an in-file note dated 2026-07-21 stating
it is deliberately not wired into `settings.json`. It was initially miscounted
as a drifted third version; the rollout would have re-registered it and undone
a deliberate decision. It is shimmed like the others and stays unregistered.

### Decision 9: The change-gate shim is migrated, not exempted

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
  while appearing to have it. Mitigated by the stderr report on every
  invocation, by installer verification, and by publishing before any project
  copy is replaced — but not eliminated. This is the cost of Decision 4, and it
  is smaller than the alternative only because Decision 7 is true.
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
