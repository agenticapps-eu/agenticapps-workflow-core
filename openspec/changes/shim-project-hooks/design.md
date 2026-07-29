## Context

`docs/PLAN-lightweight-fleet.md` step 3 says projects should carry almost
nothing. Its evidence for how is already on disk: `openspec-change-gate.sh` is
the only hook bound by a shim rather than a copy, and it is the only hook with
no drift. This change generalises that one working pattern and removes what the
measurement exposed as dead.

Measured before designing, across the seven repos that carry `.claude/hooks/`:

| Hook | Lines | Distinct versions | §02 gate? | Disposition |
|---|---|---|---|---|
| `openspec-change-gate` | 46 | 1 | `plan-review` (retargeted, §18) | Template — unchanged |
| `normalize-claude-md` | 288 | 3 | no | Shim |
| `database-sentinel` | 71 | 3 | `database-security` | Shim |
| `skill-router-log` | 67 | 2 | no | Shim |
| `session-bootstrap` | 29 | 1 | no | Shim |
| `design-shotgun-gate` | 41 | 2 | **`design-shotgun`** | Shim + fail-open fix |
| `phase-sentinel` | 20 | 1 | no | Delete |
| `architecture-audit-check` | 72 | 1 | no | Delete |

Two facts from this table drove the design:

- **The copy pattern produces drift; the shim pattern prevents it.** The four
  multi-version hooks are all copied. The shimmed one is not. `dashboard`'s
  `normalize-claude-md` fix (2026-07-26) reached one of seven repos in a month.
- **`design-shotgun` is on §02's normative gate list.** §02 lines 33–35 state
  the list is normative and that removing a gate is non-conformant. That single
  clause is why the defective hook is repaired rather than deleted.

## Goals / Non-Goals

**Goals**

- One implementation per hook, on disk once, live everywhere immediately.
- Remove hooks that cannot fire, rather than shimming them.
- Stop `design-shotgun-gate` blocking 204 design files it cannot unblock.
- Propagate `dashboard`'s `normalize-claude-md` fix to the other six repos.

**Non-Goals**

- **Retargeting §02 from GSD vocabulary to OpenSpec.** Every gate in §02 still
  triggers on "a phase", `CONTEXT.md`, `*-PLAN.md`, `*-SUMMARY.md`. §18 already
  retargeted `plan-review` out of it. That staleness is the root cause of which
  the dead hooks are a symptom, and it is plan step 5 — substantial, and it
  needs its own reviewers.
- **Moving instruction content** (`SKILL.md`, `workflow.md`,
  `workflow-config.md`) to `~/.claude/CLAUDE.md`. That is step 3b, and it
  carries a real cost this change does not: rules stop being repo-portable.
- **Re-vendoring to the four hosts.** Plan step 2 says publish, do not
  re-vendor per change.
- **Building the two deferred advisory prompts.** Recorded in the proposal;
  not built here.

## Decisions

### Decision 1: Shim against the shared bin, not a package manager or symlink

**Chosen:** each project ships a shim resolving override → `~/.agenticapps/bin/`
→ `<repo>/bin/`, then `exec`s.

*Alternative A — symlink each hook into `~/.agenticapps/bin/`.* Fewer moving
parts and zero resolution logic. Rejected: a symlink into a home directory
breaks on clone, breaks in CI, and breaks for any teammate, with no fail-open
path — the hook simply errors. The shim degrades to "allow" instead.

*Alternative B — publish the hooks as an npm/brew package the projects depend
on.* Real versioning and a genuine install story. Rejected as the disease the
plan names: it adds a second binding mechanism alongside the shared bin, and
principle 3 says use the one that exists. It also reintroduces per-project
version pinning, which is what re-vendoring already costs us.

The shared bin is chosen because it is already load-bearing, already proven by
`openspec-change-gate.sh`, and already has an installer
(`install-shared-artifact.sh`) with an arbiter that prevents an older host
installer clobbering a newer copy.

### Decision 2: Repair `design-shotgun-gate`, do not delete it

**Chosen:** the gate allows when `.planning/current-phase/` is absent, blocks
when the directory exists but the sentinel does not.

*Alternative — delete the hook.* This was the original proposal and the user
approved it, before §02 was read. Rejected on reading §02 line 248: a host MUST
bind every gate whose trigger can occur in its project type, and gates may be
omitted only when the trigger *cannot* occur. `callbot` and `cparx` have real
UIs, so the `design-shotgun` trigger can occur; omitting the binding there
would be non-conformant.

The three-state behaviour is deliberate. Treating "directory absent" and
"sentinel absent" identically is what created the bug: it conflated *the
pre-flight has not run* with *there is no pre-flight mechanism at all*. Only
the first is a reason to block.

### Decision 3: Delete the two extension hooks outright

`phase-sentinel` and `architecture-audit-check` are not in §02's gate list, so
§02 line 259 makes them optional extensions. Both are permanently inert:
`.planning/current-phase/checklist.md` and `.planning/audits/` exist in no repo
in either family.

*Alternative — shim them like the rest, for uniformity.* Rejected under plan
principle 1: shimming installs shared machinery whose only job is to keep
permanently-inert hooks alive. Deleting beats constructing.

Their *intent* is preserved as the two deferred advisory prompts in the
proposal, which trade a sentinel-file check for a real trigger.

### Decision 4: `dashboard`'s `normalize-claude-md` becomes canonical

Its version is strictly newer: it removes a fallback that injected a
"Migration 0009 not yet applied" stub whenever `.claude/claude-md/workflow.md`
was absent — a message that is now both false and stale, since that file was
removed on 2026-07-26. `agents-task-viewer`'s 314-line third variant is
diffed against it during rollout and any genuine addition is folded in rather
than dropped.

## Risks / Trade-offs

- **A shim is only as good as the install.** Until
  `install-shared-artifact.sh` publishes the implementations, every shimmed
  hook fails open and projects lose enforcement. Mitigated by ordering: publish
  and verify before replacing any project copy. The pre-commit and CI floor
  are unaffected throughout.
- **Fail-open is a real posture choice.** A missing install silently disables
  gates rather than announcing itself. Accepted because §18 already made this
  trade for the change-gate for the same reason, and because the alternative —
  bricking every edit on a machine that has not installed — is worse.
- **`agents-task-viewer`'s variant may contain a genuine fix**, not just rot.
  Mitigated by diffing rather than overwriting.
- **Rules stop being fully repo-portable** for the hook layer specifically. A
  teammate cloning `callbot` gets fail-open hooks until they run the installer.
  This is the same bargain step 3b makes for instruction content, taken here
  only for hooks, where the cost is lowest because the CI floor still binds.

## Migration Plan

No migration document. Per the plan's decision on step 1, a migration would
install machinery to delete machinery; projects are edited directly.

Order matters, because the shims are inert until the implementations exist:

1. Land canonical implementations in core and publish to `~/.agenticapps/bin/`.
2. Verify each published implementation behaves identically to the copy it
   replaces, using the repo whose copy is canonical.
3. Only then replace project copies with shims, one repo at a time.
4. Delete the two extension hooks and remove their `settings.json` entries.

Rollback is `git revert` per repo; the published implementations are additive
and harmless if project copies remain.

## Open Questions

- Does `agents-task-viewer`'s 314-line `normalize-claude-md` variant contain a
  fix worth folding into canonical, or is it purely older? Resolved by diff
  during task 2, not by assumption.
- `settings.json` currently wires all eight hooks in every project. Removing
  two entries is a per-project edit this change must make — confirm no project
  references them elsewhere before deleting.
