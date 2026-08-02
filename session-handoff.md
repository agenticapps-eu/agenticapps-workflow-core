# Session Handoff — 2026-08-02

## Accomplished

**All four host PRs merged.** The pin architecture has reached every host's
`main` for the first time.

| host | PR | merged |
|---|---|---|
| claude-workflow | #111 | `6bf2e13` |
| codex-workflow | #34 | `79ef389` |
| opencode-workflow | #23 | `8b0aab6` |
| pi-agentic-apps-workflow | #19 | `3ac6ea8` |

All four pin core at `ef030d0`. Verified properly: all seven artifacts match
their manifest sha at the pin, and core `main` is byte-identical to the pin.
**Caution for future checks** — the manifest's `bin/…` paths are *logical host
layout*, mapped by `resolve-core-artifact.sh` to `reference-implementations/…`.
`git show <rev>:bin/openspec-change-gate.sh` silently yields nothing and hashes
the empty string (`e3b0c44…`). An earlier comparison this session did exactly
that and proved nothing.

**Core now gates itself — [PR #56](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/56), open, `gate` job green.**
Branch `feat/core-gates-itself`. Change `core-gates-itself`, 38/40 tasks.
New capability `core-self-enforcement` (not an amendment to
`change-gate-enforcement`, whose six requirements are all parsing semantics).

Added: `.claude/hooks/openspec-change-gate.sh`, `.claude/settings.json`,
`.github/workflows/openspec-gate.yml`, `tools/install-core-git-hooks.sh`,
`adrs/0028-core-gates-itself.md`. Modified `docs/WORKFLOW.md`.

All three points resolve core's **own** working-tree gate, not
`~/.agenticapps/bin/`. Proven by preference, not absence: a sentinel exiting 99
placed at the shared path was never touched; shared install restored, sha
matches `4ad996cb…76780`.

## Decisions

- **Core resolves its own reference implementation** (operator choice). Makes
  core's PR the earliest detector of gate drift. ADR-0028.
- **`main` stays unprotected** (operator choice). Core has no branch protection
  and no rulesets, so the CI job **reports, does not enforce**. Recorded as a
  §09 delta. No surface may call it a floor.
- **Ownership by marker, not byte equality.** Byte equality cannot coexist with
  an upgrade path — a revised hook reads as foreign forever. Pushed back on
  codex for this; four marker outcomes defined instead.
- **Factiv one-off unblock dropped** — superseded by doing `shim-project-hooks`
  properly.

## Files modified

- `openspec/changes/core-gates-itself/` — proposal, design, specs, tasks, REVIEWS
- `.claude/hooks/openspec-change-gate.sh`, `.claude/settings.json` — new
- `.github/workflows/openspec-gate.yml` — new; row floor `MIN_SCORED_ROWS=71`
- `tools/install-core-git-hooks.sh` — new
- `adrs/0028-core-gates-itself.md` — new
- `docs/WORKFLOW.md` — §18 list corrected; it still described the blocking
  ≥2-reviewer floor that spec 1.5.0 retired

## Next session: start here

**Do `shim-project-hooks`** (88 tasks, 0 done, the other open change in core).

**FIRST, re-check its premise — this session invalidated part of it.** Its
proposal and task 4.12 both assert core has *no `.claude/hooks/` at all*. That
is no longer true: PR #56 added `.claude/hooks/openspec-change-gate.sh` and
`.claude/settings.json`. Task 4b ("migrate the change-gate shim — it is not
exempt") now has a target in core that did not exist when it was written, and
core's shim deliberately does **not** resolve the shared install. Reconcile
before implementing, and decide whether #56 merges first.

**Then re-run its plan review.** Its two REQUEST-CHANGES verdicts date from
2026-07-30, before round 7 rewrote the text they object to; the gate reports it
stale. **The previous handoff said this needs the operator — it does not.** All
four vendor CLIs are on PATH (gemini 0.28.2, codex 0.145.0, opencode 1.18.7,
cursor-agent). Invocation:

    bash ~/.agenticapps/bin/run-plan-review.sh shim-project-hooks --implementing-host claude

Reviews were high quality this session — round 1 on `core-gates-itself` caught
a worktree bug that would have shipped, and round 2 caught a bug round 1's fix
introduced. Codex times out at the 180s default; raise `REVIEW_TIMEOUT`.

## Open questions

- **PR #56 still owes** the §07 Stage-2 independent code review (6.5) and a
  review re-run against the implementation (6.8). CodeRabbit was PENDING at
  hand-off — check it actually ran, given the recurring rate-limit false greens.
- **GitNexus is safe to remove** — verified nothing executes it: no hook,
  settings, MCP registration, crontab or shell rc; `.claude.json` lists it only
  under `disabledMcpServers`; no `.gitnexus` index anywhere under `~/Sourcecode`;
  `~/.gitnexus/registry.json` is `[]`. Removable: `npm uninstall -g gitnexus`
  (**1.0 GB**, run under node v24.16.0 — fnm shim), `rm -rf ~/.gitnexus`,
  `~/Sourcecode/gitnexus-index-all.sh`. **Keep** the prohibition in
  `~/.claude/CLAUDE.md`, the migration ledger/ADRs (`check-snapshot-parity.sh`
  compares bytes), and the legacy `<!-- gitnexus:start -->` anchor in
  `setup/SKILL.md`.
- **Factiv: `design-shotgun-gate.sh` is live in callbot, cparx, fbc-platform,
  fx-signal-agent**, registered in each `settings.json`, exit 2 on
  `.tsx`/`.css`/`src/components/*`. callbot + fbc-platform have no sentinel →
  **blocked today**. cparx + fx-signal-agent have it on disk but gitignored →
  every fresh clone blocks. In `shim-project-hooks` scope.
- **Core's published CI template** carries the supply-chain weaknesses fixed in
  core's copy (unpinned `npm i -g`, no permissions block, persisted checkout
  credentials). No host pins it, so it is safely fixable — follow-up.
- **Manifests disagree**: claude-workflow pins seven files, the other three pin
  five (no `run-plan-review.sh`, no `install-shared-artifact.sh`). Any "all
  seven" claim is wrong for three of four hosts.
- **Hosts still cite core spec 1.4.0** in manifest comments; core is at 1.5.0.
  Documentary only — re-pinning to a post-#56 commit would refresh it.
- **Five family repos have no workflow at all**: agenticapps-observability,
  agentlinter, open-design, dotclaude, agenticapps-shared. Dashboard and roadmap
  have the skill but no CI gate.
- **A concurrent session is live in `agenticapps-dashboard`** (branch
  `feat/repo-readiness-vocabulary`, 74 commits ahead, never pushed, uncommitted
  edits shifting between checks). Do not touch that checkout.
