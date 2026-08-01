## Why

Seven repos each carry eight `.claude/hooks/*.sh` files — 634 lines per repo,
roughly 4,440 lines total, copied byte-for-byte from a single origin. The
copies have already drifted: four of the eight exist in two or three distinct
versions, and `agenticapps-dashboard` carries a `normalize-claude-md.sh` fix
(2026-07-26) that the other six never received. The one hook that is *not*
copied — `openspec-change-gate.sh`, whose ~13 lines of logic `exec`
`~/.agenticapps/bin/openspec-change-gate.sh` — has zero drift across all seven.

The copy pattern demonstrably produces drift; the shim pattern demonstrably
prevents it.

But measuring the eight hooks found something larger than duplication: **five
of them should not exist at all.** Three are inert or actively harmful GSD
remnants, and two write live telemetry into `.planning/` — a directory this
fleet's own policy designates frozen archive, "never write to them".

**That policy is being violated on every session, but not mainly by these two
hooks — the earlier version of this paragraph blamed the wrong writer.** It read:
"`skill-router-log.sh` wrote into core's `.planning/` at 08:39 on 2026-07-29,
during the session that found it." Core has **no `.claude/hooks/` directory at
all**, so no project hook ran there. Remeasured: core carries 141 files under
`.planning/skill-observations/` — 137 in the `<stamp>--<sessionId>.{md,jsonl}`
naming of the **global** `SessionEnd` hook registered in
`~/.claude/settings.json` (`agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`),
and 4 in `skill-router-log.sh`'s `skill-router-{date}.jsonl`.

Both hooks are still deleted — they are hooks and they do write there — but this
change **reduces** the violation rather than ending it, and says so rather than
claiming a compliance it does not deliver. `meta-observer` is recorded as a
follow-up below.

One of the three is not merely dead but blocking. `design-shotgun-gate.sh`
fails **closed** against `.planning/current-phase/design-shotgun-passed`, a
sentinel only GSD-era preflight ever wrote; GSD was removed on 2026-07-28. In
`callbot` and `fbc-platform`, which have no `.planning/current-phase/`
directory, every `Edit`/`Write` to a `.tsx` or `.css` file is blocked at the
tool boundary — 90 and 114 tracked files. The remedy it prints no longer
exists.

This is step 3a of `docs/PLAN-lightweight-fleet.md`, whose first principle is
that deletion beats construction and whose third is that the shared bin is
already the binding mechanism.

## What Changes

**Delete five hooks from all seven projects**, removing their `settings.json`
entries.

The argument for each deletion is that **no §02 gate's documented binding names
it, and none produces a §02 evidence artifact** — not that its filename is
absent from §02's gate list. A reviewer was right that the earlier reasoning was
unsound: §02 says a gate's binding is host-specific data living in the host
instruction file, which makes filenames non-authoritative **in both
directions**. A hook named after nothing in §02 could still be a gate's binding,
and a hook named after a gate need not be. Each of the five is checked against
what §02 actually binds:

| §02 gate | Documented binding | Required evidence |
|---|---|---|
| `brainstorm-ui` | a brainstorming skill | ≥2 UI alternatives in CONTEXT.md |
| `brainstorm-architecture` | a brainstorming/research skill | ≥2 architectural alternatives |
| `design-shotgun` | a multi-variant design generation skill | ≥3 rendered variants referenced from CONTEXT.md / UI-SPEC.md |
| `design-critique` | a designer-eye review skill | a critique document |
| `plan-review` | a multi-AI plan-review skill + programmatic gate | `REVIEWS.md` |

Every binding is a **skill named in the host instruction file**; the host's
gate-to-skill map names `superpowers:brainstorming`, gstack `/design-shotgun`,
`impeccable:critique` and `run-plan-review.sh`. None of the five hooks appears in
it, and none writes any of the evidence artifacts above. `design-shotgun-gate.sh`
is the closest call and still fails the test: it checks a sentinel file
(`.planning/current-phase/design-shotgun-passed`), which is not §02's required
evidence for that gate, so it was never that gate's enforcement either.

On that basis all five are host-specific extension hooks, which §02 permits but
does not require:

- `phase-sentinel.sh` — gates on `.planning/current-phase/checklist.md`, which
  exists in no repo in either family. Permanently inert.
- `architecture-audit-check.sh` — reads `.planning/audits/`, which exists in no
  repo in either family. Permanently inert.
- `design-shotgun-gate.sh` — the blocking defect above. §02's `design-shotgun`
  gate binds a *skill* (gstack `/design-shotgun`, per the host instruction
  file), not this PreToolUse hook, which merely shares its name. Deleting the
  hook removes no §02 binding.
- `skill-router-log.sh` — writes session telemetry into `.planning/`, contrary
  to the frozen-archive policy.
- `session-bootstrap.sh` — reads that telemetry back into session context. The
  sole consumer of the above; the pair is deleted together.

The telemetry logs are **gitignored in every repo and tracked in none**, so
deleting the producers discards nothing durable.

**Shim the two remaining hooks** against `~/.agenticapps/bin/`, following the
`openspec-change-gate.sh` pattern:

- `normalize-claude-md.sh` — `agenticapps-dashboard`'s version becomes
  canonical; its 2026-07-26 fix reaches the other six.
- `database-sentinel.sh` — reconciled to `callbot`'s semantics, which are the
  strict superset: a `.env` wildcard (`.env|.env.*|*/.env|*/.env.*`) with an
  explicit `.env.example`/`.env.template` allowance, plus `MultiEdit` handling.
  The enumerated four-suffix list in `dashboard` and `cparx` misses any novel
  suffix, which is precisely the case a secrets guard exists for.

  **Two corrections to that adoption**, both from review:

  1. **The `migrations/` clause is dropped, not carried.** `callbot`'s copy
     blocks every `migrations/` edit unless `.planning/current-phase/migrations-approved`
     exists (line 59), and tells the operator to fix it with `/gsd-discuss-phase`
     — a command removed on 2026-07-28. `callbot` has no `current-phase/`
     directory, so **every migration edit in that repo is blocked today**. This
     is the same dead-sentinel mechanism as `design-shotgun-gate`, in the hook
     the earlier draft classified as healthy; naming this copy canonical without
     the correction would have propagated a live blocking defect to all seven
     repos. Its replacement is the deferred advisory database-review prompt,
     already recorded below.
  2. **`MultiEdit` needs a `settings.json` change, not just an implementation.**
     Six of the seven repos register `database-sentinel` on `Bash|Edit|Write`;
     only `callbot` includes `MultiEdit`. Adopting an implementation that
     handles `MultiEdit` does nothing in a repo whose matcher never delivers it.
     The rollout updates the matcher in the other six.

**The fail posture is fail-open with a loud warning, for both hooks.** An
earlier revision had `database-sentinel` fail **closed** on the reasoning that
nothing backstops it. Review showed that does not work, and the numbers are
unambiguous: the hook is registered on `Bash|Edit|Write` (`|MultiEdit` in
`callbot`), so a shim that blocks when it cannot resolve an implementation
blocks **every Bash command and every file edit in the repo** — not `.env` and
`migrations/` as claimed. Narrowing that would require the shim to inspect the
payload, which is precisely the behaviour the shim contract forbids and which
would re-create the duplicated logic this change exists to remove.

The guarantee moves to where it can be enforced without duplicating anything:
the installer verifies both implementations are present and executable, and the
rollout publishes and verifies **before** any project copy is replaced. An
unresolvable shim warns on stderr and allows. Absence becomes a provisioning
failure, caught once and visibly, rather than a per-tool-call outage.

**Preserve `agents-task-viewer`'s opt-out — by shipping it no file at all.** Its
`normalize-claude-md.sh` is **deliberately unregistered**; an in-file note dated
2026-07-21 says it must remain so. It was not a drifted third version.

A previous revision said it "is shimmed like the others but stays out of that
project's `settings.json`", while task 4.3 left the choice open and the impact
counts below assumed the shim existed — three artifacts, three positions, which
review flagged. **Resolved: no file.** The opt-out forbids wiring the hook; it
does not require an unwired file to exist. A shim nothing invokes is a copy that
can drift unnoticed, and it would be the fleet's only file simultaneously
required to be byte-identical everywhere and guaranteed never to run.

## Capabilities

### New Capabilities
- `project-hook-binding`: how a project binds a **fleet-shared** workflow hook —
  the shim contract, its resolution order, what an unresolvable shim does, and
  the rule that a hook implementation is authoritative in exactly one place.

  The capability governs hooks shared across projects. It does **not** require
  every hook in a project to be a shim: §02 explicitly permits host-specific
  extension hooks, and a project-local hook that exists in one repo has nothing
  to drift against. An earlier revision required all of them, which would have
  prohibited what §02 allows.

### Modified Capabilities
<!-- None. §02's normative gate list is untouched: no gate is added, removed or
     renamed. All five deleted hooks are extension hooks §02 never names, and
     the §02 `design-shotgun` gate keeps its binding — that binding is the
     gstack skill named in the host instruction file, not the deleted shell
     hook. §02's wholesale GSD vocabulary is the step 5 root cause and is
     deliberately not addressed here. -->

## Impact

**Repos touched (9):** `agenticapps-workflow-core` (canonical implementations
+ new capability spec), **`claude-workflow`** (see below), and the seven
projects carrying hooks —
`agenticapps-dashboard`, `agenticapps-roadmap`, `agents-task-viewer`,
`callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`.

**`claude-workflow` is touched; the other three hosts are not.** No host carries
a `.claude/hooks/` directory of its own, so none is touched *as a hook-carrying
project*. `claude-workflow` is nonetheless in scope because it **scaffolds** the
projects that do: it vendors all eight hooks twice, plus stale matchers, so
leaving it alone means the next `/setup-agenticapps-workflow` recreates
everything this change deletes. See the `claude-workflow` subsection below for
the specific edits. A previous revision said in one sentence that it was among
the nine touched repos and in the next that it was untouched; both readings were
in the text at once.

`agenticapps-dashboard-add-agent-board` is a git *worktree* of
`agenticapps-dashboard` on another branch, not an eighth repo.

**Result per project:** 8 hooks become 3 (`openspec-change-gate` plus two shims)
in **six** of the seven; 634 lines become roughly 138. **`agents-task-viewer` is
8 → 2**, since it receives no `normalize-claude-md` file (see the opt-out above).
Across seven projects that is about −3,470 lines, plus ~360 lines added once to
core as canonical implementations.

The earlier text said "8 hooks become 3" without qualification, which review
showed could not be true alongside an unresolved `agents-task-viewer`. The count
is now stated per project rather than as a fleet uniformity that does not hold.

**Behaviour changes**, all of them fixes or deliberate removals:

- `callbot` and `fbc-platform` can edit design files again.
- Six projects receive the `normalize-claude-md` fix they lacked.
- Two projects gain `.env` protection for novel suffixes they currently miss.
- Session-start no longer surfaces recent skill invocations, and skill
  invocations are no longer logged. This is the accepted cost of deleting the
  telemetry pair.
- `callbot` can edit `migrations/` again — blocked today by a sentinel no
  surviving command writes.
- Six projects gain `MultiEdit` coverage on `database-sentinel`, which their
  matchers have never delivered.
- A machine without the shared install loses `.env` and destructive-SQL
  protection, and says so on stderr each time. It does not block.

**What `database-sentinel` is, stated accurately.** It is **best-effort
defence in depth**, not a security boundary, and the delta says so rather than
calling it a security control. Its limits are specific and were named in review:

- The `Bash` arm matches `DROP TABLE`, `TRUNCATE TABLE` and `DELETE FROM`
  without a `WHERE`. It does not stop `Bash` writing `.env` directly, and
  indirection such as `psql -f script.sql` never presents the SQL to the regex.
- The implementation is a **user-writable file in a shared directory** executed
  by seven projects. Anyone who can write it can change what all seven enforce.
  That is a consequence of consolidation and the reason the change tracks the
  implementation in core rather than leaving the shared copy authoritative.

A control described accurately can be relied on correctly. Described as a
security control with no floor beneath it, it invited the fail-closed posture
that review then showed to be unworkable.

**Rollout dependency:** shims are inert until `install-shared-artifact.sh` has
published the implementations. A project whose install has not run silently
loses the protection, with a warning on each invocation — which is why
publish-and-verify precedes any project edit, and why the installer gains an
explicit verification step rather than relying on the hook to notice.

**Install story:** `install-shared-artifact.sh` publishes one artifact per
invocation, so provisioning both implementations needs an explicit
multi-artifact step. Without it, "run the installer" does not actually provide
them.

**`claude-workflow` must change, or the next scaffold undoes this.** It vendors
all eight hooks **twice** — `templates/.claude/hooks/` and
`setup/snapshot/hooks/` — plus the pre-change matchers in
`setup/snapshot/claude-settings.json`. `/setup-agenticapps-workflow` on a new
project would therefore recreate every deleted hook, both un-shimmed copies, and
the `Bash|Edit|Write` matcher, blocking design files and migrations in the new
project on day one. A reviewer found this; the earlier revision excluded the
repo entirely.

The scaffolder's templates and snapshot are updated to the post-change shape,
and `migrations/check-snapshot-parity.sh` must stay green across the edit.

**The change-gate shim is migrated too — it is not exempt.** Every project's
`openspec-change-gate.sh` is a fleet-shared shim, so this change's own new rules
apply to it, and it currently breaks three of them: it carries the
`<repo>/bin/` fallback the resolution order now forbids, it fails open
**silently** where the rule requires a report, and it hardcodes
`OPENSPEC_GATE_SELF=claude`. Its header also states the `>= 2` floor, in all
seven projects — a set of sites the companion change's enumeration missed
because this change had classified the file as untouched.

Listing it as "template — unchanged" while writing rules it violates is the
kind of exemption that makes a rule advisory. It is brought into conformance
here; the identity line is removed by the companion change, which retires
`OPENSPEC_GATE_SELF` as an identity source, so the two changes must not both
edit that line.

**No workflow content is re-vendored to the four hosts.** Per plan step 2, host
*workflow content* is updated when preparing another machine or a release, not
per change. `claude-workflow` is nonetheless one of the nine repos touched, for
the template and snapshot edits above: that work removes stale vendored hook
copies rather than pushing new content out. An earlier revision listed the repo
as touched and as untouched in the same section, which is the contradiction a
reviewer flagged; the distinction is between re-vendoring content and deleting
vendored content, and only the second happens here.

**Local telemetry logs are not removed by deleting their producers.** The
gitignored logs `skill-router-log` wrote already exist on developer machines and
may contain repository paths and session activity. "Gitignored and untracked"
means nothing durable is *added* to the repos; it does not mean the existing
data is disposed of.

Review found "offers an optional cleanup step" too vague to act on, so it is
concrete:

- **Location** — `<projectRoot>/.planning/skill-observations/`, one file per
  day per project, named `skill-router-<YYYY-MM-DD>.jsonl`. Each line is a JSON
  object `{ts, skill, phase, tool}`.
- **Inventory before deleting** —
  `find . -path '*/.planning/skill-observations/skill-router-*.jsonl'`
- **Cleanup** — the same expression with `-delete`, run per repo, by the
  operator. It is **not** performed by this change: the files are local,
  untracked, and may be wanted as history, so the decision is the machine
  owner's.
- **Scope limit, stated plainly** — this removes only what `skill-router-log`
  wrote. The `<stamp>--<sessionId>.{md,jsonl}` files in the same directory come
  from `meta-observer` and will keep appearing after this change, because its
  producer is still registered. Deleting them without unregistering it is
  housekeeping that undoes itself at the next session end.

## Deferred follow-ups

Recorded so the intent survives the deletions. Both are **optional and
advisory** — they prompt, they do not block — and both replace a sentinel-file
check with a real trigger:

1. **Architecture review prompt**, fired when a larger change has been
   completed and committed. Replaces `architecture-audit-check`'s time-based
   nag against a directory that exists nowhere.

2. **Database review prompt**, fired when the database has been touched.
   Supersedes retargeting `database-sentinel`'s `migrations-approved` clause:
   an ask on a real trigger rather than a blocking check for a sentinel file.

`database-sentinel`'s existing protections — `DROP`/`TRUNCATE TABLE`,
`DELETE FROM` without a `WHERE`, and `.env` edits — are unaffected by this
change and by the follow-up.

3. **Retire or retarget `meta-observer`'s `.planning/` writes.** The global
   `SessionEnd` hook in `~/.claude/settings.json` runs
   `agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`, which
   writes `<projectRoot>/.planning/skill-observations/<stamp>--<sessionId>.{md,jsonl}`
   in **every** repository the operator opens — 137 of core's 141 such files,
   in a repo with no `.claude/hooks/` at all. It is the fleet's dominant
   frozen-archive violation and the reason this change cannot claim to end one.

   Out of scope here for three reasons, each of which also shapes the follow-up:
   it lives in `agenticapps-dashboard`, not in any of the seven hook-carrying
   projects; it is wired through **global host settings** rather than a project's
   `settings.json`, so no per-project edit reaches it; and unregistering a global
   hook is an operator-level change to the machine, not a repository change this
   change has standing to make.

4. **Decide what backstops an unprovisioned machine.** This change establishes
   that the git `pre-commit` wrapper fails open exactly when the PreToolUse shim
   does — same missing shared install, same `exit 0` — leaving CI as the only
   floor. That is recorded here as true rather than fixed: making the wrapper
   fail closed re-creates the `--no-verify` training problem its comment
   documents, and the alternative (provisioning detection at clone time) is a new
   mechanism. The follow-up owns the choice; this change owns no longer
   mis-stating it.
