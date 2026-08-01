# Session Handoff — 2026-08-01 (second session)

## Accomplished

**`track-and-conform-plan-review` is archived, and core finally has durable
capability specs.** One PR, open not merged.

| PR | what |
|---|---|
| [#54](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/54) | archive the change at 157/157; create `openspec/specs/change-gate-enforcement/` and `openspec/specs/plan-review-production/` |

**The two open tasks were discharged, not performed.** Both say so in place.

- **`9b.18` (publish gate 1.6.0) — SUPERSEDED.** Its precondition `8b.7`
  dissolved when gate 2.0.0 withdrew blocking; by then the tracked gate was
  past 1.6.0, so publishing it would push a superseded version over a live one
  — the downgrade `install-shared-artifact.sh` exists to refuse. What the task
  was *for* is satisfied: gate 2.0.0 is live in `~/.agenticapps/bin/`,
  **byte-identical** to the tracked source (sha256 `4ad996cb…76780`, both sides
  hashed this session), 71/71. Verified the round-9b hardening survives the
  withdrawal as reporting: the harness still has a row for the
  verdict-and-substance predicate, conflicting verdicts, trailer identity,
  digest validation, emphasis normalisation and the reviewer-name bypass.
- **`10.2` (`--ci` green) — VERIFIED**, exit 0.

**Why this archive was the unblocking move.** `change-gate-enforcement`
previously existed *only* inside this change's unarchived delta. That is why
last session's §18 work had to go inside the change rather than beside it. It
now exists at `openspec/specs/`, so the next gate change writes a normal
`MODIFIED` delta.

Verified after the move: `openspec validate --all` 4 passed / 0 failed; `--ci`
exit 0; conformance 71/71. Nothing executable changed.

## Decisions

- **`9b.18` and `10.2` were ticked, deviating from the previous handoff**,
  which said to "say so in the task rather than ticking it". Followed `8b.7`'s
  precedent in the same file instead — `[x]` plus bold **SUPERSEDED … not
  performed** prose. An unticked box is a permanent false "outstanding work"
  signal; the prose carries the honesty. Flag if you disagree — it is one edit
  to reverse.
- **Synced the deltas rather than archiving bare.** Both were pure
  `## ADDED Requirements` into capabilities that did not exist, so the sync
  creates rather than merges; nothing existing was overwritten. Bodies carried
  byte-for-byte, verified by diffing each delta against the created file below
  its preamble (sole difference: one leading blank line).
- **`.planning/skill-observations/` left untracked**, per the global rule that
  `.planning/` is frozen GSD history.

## Files modified

- `openspec/changes/track-and-conform-plan-review/` → `openspec/changes/archive/2026-08-01-track-and-conform-plan-review/` (git detected as renames)
- `openspec/changes/archive/2026-08-01-track-and-conform-plan-review/tasks.md` — `9b.18` and `10.2` closed with rationale
- `openspec/specs/change-gate-enforcement/spec.md` — **new**, 6 requirements / 40 scenarios
- `openspec/specs/plan-review-production/spec.md` — **new**, 11 requirements / 36 scenarios

## Next session: start here

**Merge #54**, then pick up **`shim-project-hooks`** — it is the only active
change left and sits at zero tasks done, an unimplemented proposal that has
been carried across three handoffs untouched. Decide whether it is real work or
should be withdrawn; it currently carries two REQUEST-CHANGES verdicts (gemini,
codex) that the gate reports on every `--ci` run, so leaving it open keeps a
permanent NOTE in core's CI output. If it is real, it can now write a normal
`MODIFIED` delta against `change-gate-enforcement` rather than the ADD-and-hope
shape — that capability exists as of #54.

## Open questions

- **Core still does not gate itself.** No `.claude/hooks/`; `.github/workflows/`
  has only `pages-cheatsheet.yml`. The repo that publishes the change gate runs
  neither the hook nor the CI job it now correctly documents. Unchanged, and the
  cheapest fix in the list.
- **The four hosts still cite spec 1.4.0.** 1.5.0 requires no host action, but
  until they re-cite, `implements_spec` names a version whose §18 contradicts
  the gate they pin. Whether that re-cite is a fleet task or a per-host one is
  still unowned.
- **The §07 Stage-2 code review of core #49's merged work is still NOT DONE** —
  now carried from three sessions ago.
- **Migration 0032 installs the producer without version arbitration** — open.
- **CodeRabbit's review of #52 was never read** — pending at merge, still unread.
