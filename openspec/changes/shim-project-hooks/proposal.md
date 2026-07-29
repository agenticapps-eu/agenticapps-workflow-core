## Why

Seven repos each carry eight `.claude/hooks/*.sh` files — 634 lines of shell
per repo, roughly 4,440 lines total, copied byte-for-byte from a single origin.
The copies have already drifted: four of the eight now exist in two or three
distinct versions, and `agenticapps-dashboard` carries a
`normalize-claude-md.sh` fix (dated 2026-07-26, removing a stale GSD-era
fallback) that the other six projects never received. Meanwhile the one hook
that is *not* copied — `openspec-change-gate.sh`, whose ~13 lines of logic
`exec` `~/.agenticapps/bin/openspec-change-gate.sh` — has zero drift across all
seven.

The copy pattern demonstrably produces drift; the shim pattern demonstrably
prevents it. This change generalises the shim to the rest of the hook surface.

Two of the eight hooks are also permanently inert, and one is actively
misfiring. `design-shotgun-gate.sh` fails **closed** against
`.planning/current-phase/design-shotgun-passed`, a sentinel that only GSD-era
preflight ever wrote. GSD was removed 2026-07-28. In `callbot` and
`fbc-platform` — which have no `.planning/current-phase/` directory at all —
every `Edit`/`Write` to a `.tsx` or `.css` file is therefore blocked at the
tool boundary: 90 and 114 tracked files respectively. The remedy the hook
prints ("run `/design-shotgun` and let preflight write the sentinel") no longer
exists.

This is step 3a of `docs/PLAN-lightweight-fleet.md`, whose first principle is
that deletion beats construction and whose third is that the shared bin is
already the binding mechanism — use it, do not invent a second one.

## What Changes

- **Publish five hook implementations to the shared bin.**
  `normalize-claude-md`, `database-sentinel`, `skill-router-log`,
  `session-bootstrap` and `design-shotgun-gate` gain canonical implementations
  under `reference-implementations/project-hooks/`, installed to
  `~/.agenticapps/bin/` by the existing `install-shared-artifact.sh`.

- **Replace the seven copies of each with a shim** following the
  `openspec-change-gate.sh` pattern: explicit `$OVERRIDE` → shared bin → repo
  `bin/` resolution order, fail-open when unresolvable.

- **Fix `design-shotgun-gate` to fail open** when
  `.planning/current-phase/` is absent, matching the fail-open posture
  `openspec-change-gate.sh` already documents. This unblocks 204 design files
  across `callbot` and `fbc-platform`. The gate keeps blocking normally where
  the sentinel directory exists, so no repo loses enforcement it has today.

- **Adopt `agenticapps-dashboard`'s `normalize-claude-md.sh` as canonical**,
  propagating its 2026-07-26 fix to the six projects that never got it.
  `agents-task-viewer`'s third variant is reconciled against it.

- **Delete `phase-sentinel.sh` and `architecture-audit-check.sh`** from all
  seven projects. Neither is a §02 gate — both are host-specific extension
  hooks, which §02 permits but does not require. Both are permanently inert:
  `phase-sentinel` gates on `.planning/current-phase/checklist.md` and
  `architecture-audit-check` reads `.planning/audits/`; neither path exists in
  any repo in either family.

- **NOT removing the `design-shotgun` gate binding.** §02's gate list is
  normative and forbids removing a gate; the binding is fixed rather than
  deleted. Retiring the gate itself belongs to the §02 retarget (plan step 5).

## Capabilities

### New Capabilities
- `project-hook-binding`: how a project binds a workflow hook — the shim
  contract, its resolution order, its fail-open requirement, and the rule that
  a hook implementation lives in exactly one place.

### Modified Capabilities
<!-- None. §02's normative gate list is unchanged by this change: no gate is
     added, removed or renamed. `design-shotgun` keeps its binding (repaired,
     not deleted); `phase-sentinel` and `architecture-audit-check` are
     extension hooks that §02 never named. The §02 retarget from GSD
     vocabulary to OpenSpec is deliberately out of scope — see plan step 5. -->

## Impact

**Repos touched (8):** `agenticapps-workflow-core` (canonical implementations
+ new capability spec), and the seven projects carrying hooks —
`agenticapps-dashboard`, `agenticapps-roadmap`, `agents-task-viewer`,
`callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`. `claude-workflow` and
the other three hosts carry no `.claude/hooks/` of their own and are untouched.

`agenticapps-dashboard-add-agent-board` is a git *worktree* of
`agenticapps-dashboard` on a different branch, not an eighth repo; its
checkout is updated when that branch next merges, not separately.

**Net line change:** roughly −2,500 lines across the seven projects (~644
deleted outright; ~3,470 of implementation collapsed into ~1,610 of shim), plus
~500 lines added once to core as the canonical implementations. The headline
result is not the line count but the copy count: five implementations × seven
copies becomes five implementations × one.

**Behaviour changes:** exactly two, both fixes — `design-shotgun-gate` stops
blocking design edits in repos with no `current-phase` directory, and six
projects receive the `normalize-claude-md` fix they were missing. No other
hook changes what it does.

**Rollout dependency:** the shims are inert until
`install-shared-artifact.sh` has published the implementations to
`~/.agenticapps/bin/`. Because every shim fails open, a project whose install
has not yet run loses hook enforcement rather than breaking — the git
pre-commit and CI floor remain the real guarantee, per §18.

**Not re-vendored to the four hosts.** Per plan step 2, host copies are
updated when preparing another machine or a release, not per change. Host CI
drift checks may go red in the interim; that red is informational.

## Deferred follow-ups

Recorded here so the intent survives the deletions above. Both are **optional
and advisory** — they prompt, they do not block — and both replace a
sentinel-file check with a real trigger:

1. **Architecture review prompt.** Fires when a larger change has been
   completed and committed, asking whether an architecture review is
   warranted. Replaces `architecture-audit-check`'s time-based SessionStart nag
   against a `.planning/audits/` directory that exists nowhere.

2. **Database review prompt.** Fires when the database has been touched,
   asking whether a database audit is warranted. Supersedes retargeting
   `database-sentinel`'s `migrations-approved` clause: an ask on a real
   trigger rather than a blocking check for a sentinel file.

`database-sentinel`'s existing protections — blocking `DROP`/`TRUNCATE TABLE`,
`DELETE FROM` without a `WHERE`, and edits to `.env` files — are unaffected by
this change and by the follow-up.
