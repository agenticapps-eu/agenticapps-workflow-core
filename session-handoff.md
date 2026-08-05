# Session Handoff — 2026-08-05 (sixth session)

Two briefs: collapse the workflow to one repo, and — to run first — audit the
instruction files for conflicting rules. This session closed collapse Phase 1
and §5a, and audit items 1–5. **Subtraction: ~10,800 deletions against ~360
insertions in core, plus the fleet edits.**

The fifth-session handoff carrying Donald's verdict is on the unmerged branch
`docs/handoff-donalds-verdict` (`cc71fd3`), not on `main`. Read it.

## Open PRs

| Repo | PR | What |
|---|---|---|
| `agenticapps-workflow-core` | [#87](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/87) | retire `normalize-claude-md`; delete the uncalled provisioning checker; core's first `CLAUDE.md`; the audit record |
| `agents-task-viewer` | [#19](https://github.com/agenticapps-eu/agents-task-viewer/pull/19) | 429 lines across two files → 289 in one |
| `callbot` | [#101](https://github.com/agenticapps-eu/callbot/pull/101) | false §18 rule ×2; one instruction file |
| `cparx` | [#126](https://github.com/agenticapps-eu/cparx/pull/126) | `.planning` (698 files); six broken blocks; one instruction file |
| `fx-signal-agent` | [#121](https://github.com/agenticapps-eu/fx-signal-agent/pull/121) | false §18 rule; `AGENTS.md` symlink |
| `fbc-platform` | [#119](https://github.com/agenticapps-eu/fbc-platform/pull/119) | `.planning`; `AGENTS.md` symlink |

## Accomplished

- **Collapse Phase 1 — already done; skipped, not deferred.** All four hosts pin
  `ef030d0` and every sha256 still matches core's tree byte-for-byte. 43 commits
  since the pin touched none of those five files.
- **Collapse §5a done by settings toggle**, no commits spent tidying: archived
  `claude-workflow`, `codex-workflow`, `opencode-workflow`,
  `pi-agentic-apps-workflow`, `agenticapps-roadmap`.
- **`normalize-claude-md` retired.** It re-emitted the dead `/gsd-profile-user`
  and would have overwritten cparx's hand-written correction saying that command
  no longer exists. No-op in 5 of 7 repos, opted out in a 6th, live in one. The
  three-clause removal test was run, not asserted.
- **`provisioning-check.sh` + suite deleted** — 1,202 lines, no caller but each
  other.
- **The false §18 rule corrected** in `callbot` (twice, in two wordings, one
  claiming false programmatic enforcement) and `fx-signal-agent`.
- **One instruction file per repo** in core, `agents-task-viewer`, `callbot`,
  `cparx`, `fbc-platform`, `fx-signal-agent` — the other file a symlink.
- **`.planning/` removed everywhere**; `~/.codex/AGENTS.md` deleted (its one line
  pointed at GitNexus); `~/.claude/CLAUDE.md` trimmed of its dead `.planning`
  paragraph.
- **`docs/instruction-file-audit-2026-08.md`** — the one-time record. No tool.

## Decisions

- Deleted the provisioning checker rather than repair its 14 failing tests.
- `agents-task-viewer` symlinks `CLAUDE.md` → `AGENTS.md` (the other direction to
  everywhere else) because that repo already declared `AGENTS.md` canonical.
- **Kept every rule that had no other home** — §11 discipline in each project,
  cparx's task-size table, the workflow section of `~/.claude/CLAUDE.md`. Each is
  annotated with why it is still there.
- Left `agenticapps-dashboard` alone. Donald is working in it.

## Next session: start here

**Fold the coding discipline and the task-size routing into the trigger skill.**
That is the Phase 2 rewrite, and three separate deferrals now depend on it: the
§11 blocks in every project, cparx's task-size table, and the workflow section of
`~/.claude/CLAUDE.md`. None can be deleted until the skill carries them.

Do that against `workflow.mmd`, and publish one copy from core's `skills/` — that
also resolves the duplicate-skill finding below.

## Open questions

1. **Two installed skills both claim to be the trigger skill.** Both declare
   `name: agentic-apps-workflow`, `version: 3.2.0`, and differ:
   `~/.claude/skills/agenticapps-workflow/skill/SKILL.md` is 402 lines;
   `~/.claude/skills/agentic-apps-workflow` is a **symlink into
   `claude-workflow/skill`** (331 lines) — archived today. Which loads depends on
   loader ordering. Phase 2 says rewrite rather than pick a winner.
2. **`agenticapps-dashboard` is the last split brain** (231/110, both regular
   files). Two of my commits also sit on its `retire-v1-surfaces` branch — the
   `.planning` deletion and the §18 fix — because it was not on `main` when I
   committed. History was not rewritten; he committed 13 seconds after me. Drop
   them if that PR should stay clean. Same applied to `cparx` and `fbc-platform`,
   where the commits **were** lifted onto clean branches and the original
   branches restored byte-for-byte.
3. The collapse brief's tier-3 list names four skills, but the diagram's
   conditional-gate node names **security · db-sentinel · design · qa**, so `cso`
   and `qa` look like survivors. Shapes the Phase 2 payload.
4. Data corrections to the collapse brief: core has **no** `migrations/` (the 645
   files are in the four archived host repos, so §5b's "73 migration documents"
   has no target in core); `run-plan-review.sh` is 757 lines not ~900; the four
   installers total 1,866 not 1,544.
