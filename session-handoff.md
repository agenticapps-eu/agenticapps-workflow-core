# Session Handoff — 2026-08-01 (second session)

## ⚠️ Concurrent session — do not touch

Another session is live in the **`agenticapps-dashboard-add-agent-board`
worktree** on branch **`chore/setup-codex-workflow`** (dashboard PR #73) and will
commit soon. Do not rebase it, merge into it, or edit anything under that
worktree. A concurrent edit to
`agenticapps-dashboard/openspec/changes/add-dark-palette/proposal.md` was also
observed in the main dashboard checkout during this session — also not ours.

That branch is still blocked by `design-shotgun-gate.sh` (19 commits behind
main). **No action needed**: the hook removal is on `main`, so the block clears
by itself when #73 picks main up.

## Accomplished — 4 PRs, all merged

| PR | what |
|---|---|
| core [#54](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/54) | archive `track-and-conform-plan-review` at 157/157; create the two capability specs |
| core [#55](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/55) | `shim-project-hooks` round 7 — all 10 review objections + one nobody caught |
| dashboard [#88](https://github.com/agenticapps-eu/agenticapps-dashboard/pull/88) | remove dead `design-shotgun-gate.sh` |
| task-viewer [#15](https://github.com/agenticapps-eu/agents-task-viewer/pull/15) | same |
| roadmap [#10](https://github.com/agenticapps-eu/agenticapps-roadmap/pull/10) | same, different rationale |

**#54.** Both open tasks discharged, not performed, and say so in place. `9b.18`
SUPERSEDED — gate 2.0.0 is live, byte-identical to source (`4ad996cb…76780`),
71/71, and every round-9b behaviour survives as reporting. `10.2` verified.
Archiving created `openspec/specs/change-gate-enforcement/` and
`openspec/specs/plan-review-production/`, so gate work can now write a normal
MODIFIED delta.

**#55.** Six objections valid as stated; one (gemini's version-marker claim)
partly wrong — 2.9/4b.6 do stamp it, but codex was right it had no format,
authority, comparison or check. One **worse** than stated: the pre-commit
wrapper's last resort is `<repo>/bin/`, the exact candidate Decision 1 forbids,
then `exit 0` — so on an unprovisioned machine both layers fail open and CI is
the only floor. **One defect no reviewer found:** Decision 3 blamed
`skill-router-log.sh` for core's `.planning/` writes, but core has no
`.claude/hooks/` at all — 137 of its 141 observation files come from a *global*
`SessionEnd` hook running `meta-observer/hooks/session-end.mjs`.

**The three hook PRs.** They were **not** the same case, which checking revealed:
dashboard and task-viewer had gitignored sentinels → every fresh clone blocked
(reproduced `exit 2` on clean `origin/main`); roadmap's sentinel is **tracked**
(`45f8f5a`) → not blocked (`exit 0`). Deletion clauses — binding, production,
enforcement, other specs/§17/§18, transitive consumers — were run per repo
before deleting. task-viewer's own frozen history records the hook blocking real
work twice, once making an executor halt mid-plan.

## Decisions

- **Roadmap's orphaned sentinel left in place.** Deleting it means writing to
  `.planning/`, which the fleet rules forbid. 0 bytes, no reader.
- **`agents-task-viewer` ships no `normalize-claude-md` file** (#55, Decision 8).
- **meta-observer recorded, not fixed** — different repo, global wiring,
  operator-level change.
- **#54 and #55 both merged on false-green CodeRabbit checks.** Neither review
  ran (#54 rate-limited then blocked by incremental dedup; #55 rate-limited).
  Both merge commits record this. #88 by contrast got a real review — no
  actionable comments, 0 inline.
- **#52's CodeRabbit has no findings to read** — "Review failed: PR is closed."
  Closes a standing open question.

## Next session: start here

**Re-run the plan review on `shim-project-hooks`, then implement it.** It is the
only open change in core: 88 tasks, 0 done, `REVIEWS.md` stale by design after
round 7 — the gate reports it and does not block. The standing gemini/codex
REQUEST-CHANGES verdicts no longer describe the revised text, so a fresh review
is owed before any implementation. It needs vendor CLI egress, so it is the
operator's to trigger. After that, start at section 1 (the two canonical
implementations).

## Open questions

- **Core still does not gate itself.** No `.claude/hooks/`; `.github/workflows/`
  has only `pages-cheatsheet.yml`. Cheapest fix in this list, and conspicuous —
  core publishes the gate and runs neither the hook nor the CI job.
- **The four hosts still cite spec 1.4.0** — re-cite unowned.
- **The §07 Stage-2 code review of core #49's merged work is still NOT DONE** —
  carried from three sessions ago.
- **Migration 0032 installs the producer without version arbitration.**
- **`4b.7` may now be discharged** — it treats the gate shim's hardcoded identity
  as residual "until `track-and-conform-plan-review` lands". It landed today.
- **CodeRabbit rate limits are now a recurring false green.** Two of three core
  PRs merged this session had a green check with no review behind it. Worth
  deciding whether to enable usage-based reviews or stop treating that check as
  signal.
