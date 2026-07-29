## Context

`docs/PLAN-lightweight-fleet.md` step 3 says projects should carry almost
nothing. The evidence for how was already on disk: `openspec-change-gate.sh` is
the only hook bound by a shim rather than a copy, and the only hook with no
drift.

Measured across the seven repos that carry `.claude/hooks/`, before designing:

| Hook | Lines | Versions | §02 gate? | Disposition |
|---|---|---|---|---|
| `openspec-change-gate` | 46 | 1 | `plan-review` (retargeted, §18) | Template — unchanged |
| `normalize-claude-md` | 288 | 3 | no | Shim |
| `database-sentinel` | 71 | 3 | `database-security` | Shim, fail closed |
| `skill-router-log` | 67 | 2 | no | **Delete** |
| `session-bootstrap` | 29 | 1 | no | **Delete** |
| `design-shotgun-gate` | 41 | 2 | name only | **Delete** |
| `phase-sentinel` | 20 | 1 | no | **Delete** |
| `architecture-audit-check` | 72 | 1 | no | **Delete** |

The table is the design. Five of eight hooks earn deletion; only two are worth
a shim. That ratio was not visible from the plan, which assumed the hooks were
live machinery needing cheaper maintenance.

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

**Chosen:** override → `~/.agenticapps/bin/` → `<repo>/bin/`, then `exec`.

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

### Decision 4: Split the fail posture by hook class

**Chosen:** `database-sentinel` fails closed; `normalize-claude-md` fails open.

A uniform fail-open posture was the original proposal, by analogy with
`openspec-change-gate.sh`. The analogy does not hold: the change gate fails
open *because* the git pre-commit and CI floor still catch the commit. That
floor covers the OpenSpec gate only. Nothing beneath `database-sentinel` checks
destructive SQL or `.env` access, so failing open removes the control silently.

The cost is real and accepted: on a machine where the installer has not run,
edits to `.env` and `migrations/` are blocked until it does. The block is loud
and names the fix; the alternative is quiet and does not.

### Decision 5: `callbot`'s `database-sentinel` semantics are canonical

Its `.env` matching is a wildcard (`.env|.env.*|*/.env|*/.env.*`) with an
explicit `.env.example`/`.env.template` allowance; `dashboard` and `cparx`
enumerate four specific suffixes and would miss `.env.secret` or any other
novel name. `callbot` also handles `MultiEdit`, which the others omit.

Reconciling by recency would have narrowed the protection. This is why the
spec delta requires reconciliation to take the superset rather than the newest.

### Decision 6: `agents-task-viewer` stays unregistered

Its `normalize-claude-md.sh` carries an in-file note dated 2026-07-21 stating
it is deliberately not wired into `settings.json`. It was initially miscounted
as a drifted third version; the rollout would have re-registered it and undone
a deliberate decision. It is shimmed like the others and stays unregistered.

## Risks / Trade-offs

- **A shim is only as good as the install**, and `database-sentinel` now fails
  closed. Mitigated by ordering: publish and verify before replacing any
  project copy.
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

Order matters, because shims are inert until the implementations exist and
`database-sentinel` now blocks when unresolved:

1. Land the two canonical implementations in core.
2. Publish both to `~/.agenticapps/bin/`, including the multi-artifact install
   step, and verify each behaves identically to the copy it replaces.
3. Only then replace project copies with shims, one repo at a time.
4. Delete the five hooks and their `settings.json` entries.

Rollback is `git revert` per repo; published implementations are additive and
harmless if project copies remain.

## Open Questions

- Does `agents-task-viewer`'s 314-line `normalize-claude-md` variant contain a
  fix worth folding into canonical? Resolved by diff during task 1, not by
  assumption.
- Do the deleted hooks' bats tests cover anything still wanted? The telemetry
  pair has its own tests; confirm they test only the deleted feature before
  removing them.
