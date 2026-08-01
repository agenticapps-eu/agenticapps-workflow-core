# Session Handoff — 2026-08-01 (second session)

## Accomplished

| PR | what | state |
|---|---|---|
| [#54](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/54) | archive `track-and-conform-plan-review` at 157/157; create `openspec/specs/change-gate-enforcement/` and `openspec/specs/plan-review-production/` | **merged** |
| [#55](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/55) | `shim-project-hooks` round 7 — all 10 review objections, plus one nobody caught | **open** |

**#54 — the archive.** Both open tasks were discharged, not performed, and say so
in place. `9b.18` (publish gate 1.6.0) is SUPERSEDED: its precondition dissolved
and the tracked gate had moved past 1.6.0, so publishing would push a superseded
version over a live one. What it was *for* is satisfied — gate 2.0.0 is live,
byte-identical to the tracked source (sha256 `4ad996cb…76780`), 71/71, and every
round-9b behaviour survives as reporting. `10.2` verified: `--ci` exit 0.

**#55 — the revision.** Every objection was checked against code before being
acted on. Six were valid as stated (atomicity, override provenance, contradictory
states, §02-only deletion rule, `agents-task-viewer`, telemetry cleanup). One was
partly wrong — gemini said the version marker is unimplemented; tasks 2.9/4b.6 do
stamp it, but codex was right that it had no format, authority, comparison or
check. One was **worse** than stated: the pre-commit wrapper's last resort is
`<repo>/bin/`, the exact candidate Decision 1 forbids, then `exit 0` — so on an
unprovisioned machine both layers fail open and CI is the only floor.

**One defect no reviewer found.** Decision 3's evidence read "`skill-router-log.sh`
wrote into core's `.planning/`", but **core has no `.claude/hooks/` at all**. Of
core's 141 `.planning/skill-observations/` files, 137 come from a *global*
`SessionEnd` hook running `agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`;
4 match `skill-router-log.sh`. The dominant writer is not a project hook and
writes into every repo opened. Recorded as follow-up 3, scoped out.

## Decisions

- **`agents-task-viewer` ships no `normalize-claude-md` file** (was: unregistered
  shim, with tasks leaving it open). A shim nothing invokes is a copy that can
  drift unnoticed. That repo ends at two hooks; counts are now per-project.
- **meta-observer recorded, not fixed.** Different repo, global wiring,
  operator-level change. This change reduces the `.planning/` violation and no
  longer claims to end it.
- **#54 merged on local verification, not on its green check.** CodeRabbit never
  reviewed it: first attempt rate-limited, re-request returned "Review finished"
  with zero reviews because its incremental system counted the aborted attempt as
  already-reviewed. The merge commit records this so the green is not misread.
- **#52's CodeRabbit review has no findings to read** — "Review failed: the pull
  request is closed." Closes a standing open question; nothing was missed.
- **`9b.18`/`10.2` were ticked**, deviating from the prior handoff's "say so
  rather than tick". Followed `8b.7`'s precedent in the same file: `[x]` plus
  bold SUPERSEDED prose. One edit to reverse if you disagree.

## Files modified

- `openspec/changes/track-and-conform-plan-review/` → `openspec/changes/archive/2026-08-01-.../` (merged)
- `openspec/specs/change-gate-enforcement/spec.md` — new, 6 reqs / 40 scenarios
- `openspec/specs/plan-review-production/spec.md` — new, 11 reqs / 36 scenarios
- `openspec/changes/shim-project-hooks/{proposal,design,tasks}.md` and
  `specs/project-hook-binding/spec.md` — `+571/−57`; delta 35 → 44 scenarios,
  tasks 71 → 88

## Next session: start here

**Re-run the plan review on `shim-project-hooks`, then merge #55.** Its
`REVIEWS.md` is now stale by design — the gate reports it and does not block —
and round 7 changed enough that the standing gemini/codex verdicts no longer
describe the text. The re-review needs vendor CLI egress, so it was deliberately
left to you rather than run unattended. After that, the change is ready to
implement: 88 tasks, starting at section 1 (the two canonical implementations).
Its most urgent single fix is independent of everything else —
`agenticapps-dashboard-add-agent-board` is **live-blocked today**: I ran
`design-shotgun-gate.sh` there and got exit 2 on `src/components/Board.tsx`, with
both printed remedies dead (`/design-shotgun` went with GSD; the `touch` fallback
fails because that repo has `.planning/` but no `current-phase/`).

## Open questions

- **Core still does not gate itself.** No `.claude/hooks/`; `.github/workflows/`
  has only `pages-cheatsheet.yml`. Cheapest fix in this list, and now
  conspicuous — core is the repo that publishes the gate.
- **The four hosts still cite spec 1.4.0.** Whether the re-cite is a fleet task
  or per-host is still unowned.
- **The §07 Stage-2 code review of core #49's merged work is still NOT DONE** —
  carried from three sessions ago.
- **Migration 0032 installs the producer without version arbitration** — open.
- **`4b.7` may now be discharged.** It records the gate shim's hardcoded identity
  as residual "until `track-and-conform-plan-review` lands". It landed today —
  check before repeating the claim.
