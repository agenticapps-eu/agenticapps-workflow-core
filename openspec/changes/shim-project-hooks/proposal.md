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
fleet's own policy designates frozen archive, "never write to them". That
policy is being violated on every session: `skill-router-log.sh` wrote into
core's `.planning/` at 08:39 on 2026-07-29, during the session that found it.

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
entries. None is named in §02's normative gate list, so all are host-specific
extension hooks that §02 permits but does not require:

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

**Split the fail posture.** `database-sentinel` is a security control with no
CI floor beneath it — §18's pre-commit and CI floor enforce the OpenSpec gate
only, not destructive SQL or `.env` protection. Its shim therefore **fails
closed**: if no implementation resolves, it blocks rather than silently
dropping the protection. `normalize-claude-md` is cosmetic and **fails open**.

**Preserve `agents-task-viewer`'s opt-out.** Its `normalize-claude-md.sh` is
**deliberately unregistered** — an in-file note dated 2026-07-21 says it must
remain so. It is shimmed like the others but stays out of that project's
`settings.json`. It was not a drifted third version.

## Capabilities

### New Capabilities
- `project-hook-binding`: how a project binds a workflow hook — the shim
  contract, its resolution order, the fail posture a hook takes by class, and
  the rule that a hook implementation is authoritative in exactly one place.

### Modified Capabilities
<!-- None. §02's normative gate list is untouched: no gate is added, removed or
     renamed. All five deleted hooks are extension hooks §02 never names, and
     the §02 `design-shotgun` gate keeps its binding — that binding is the
     gstack skill named in the host instruction file, not the deleted shell
     hook. §02's wholesale GSD vocabulary is the step 5 root cause and is
     deliberately not addressed here. -->

## Impact

**Repos touched (8):** `agenticapps-workflow-core` (canonical implementations
+ new capability spec), and the seven projects carrying hooks —
`agenticapps-dashboard`, `agenticapps-roadmap`, `agents-task-viewer`,
`callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`. `claude-workflow` and
the other three hosts carry no `.claude/hooks/` and are untouched.

`agenticapps-dashboard-add-agent-board` is a git *worktree* of
`agenticapps-dashboard` on another branch, not an eighth repo.

**Result per project:** 8 hooks become 3 (`openspec-change-gate` plus two
shims); 634 lines become roughly 138. Across seven projects that is about
−3,470 lines, plus ~360 lines added once to core as canonical implementations.

**Behaviour changes**, all of them fixes or deliberate removals:

- `callbot` and `fbc-platform` can edit design files again.
- Six projects receive the `normalize-claude-md` fix they lacked.
- Two projects gain `.env` protection for novel suffixes they currently miss.
- Session-start no longer surfaces recent skill invocations, and skill
  invocations are no longer logged. This is the accepted cost of deleting the
  telemetry pair.
- A machine without the shared install now **blocks** on `database-sentinel`
  rather than silently losing `.env` and destructive-SQL protection.

**Rollout dependency:** shims are inert until `install-shared-artifact.sh` has
published the implementations. Because `database-sentinel` fails closed, a
project whose install has not run will block edits to `.env` and `migrations/`
until it does — deliberate, and the reason publish-and-verify precedes any
project edit.

**Install story:** `install-shared-artifact.sh` publishes one artifact per
invocation, so provisioning both implementations needs an explicit
multi-artifact step. Without it, "run the installer" does not actually provide
them.

**Not re-vendored to the four hosts.** Per plan step 2, host copies are updated
when preparing another machine or a release, not per change.

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
