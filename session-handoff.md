# Session Handoff — 2026-08-05 (sixth session)

**Next action: Phase 3, the installer.** Everything it needs is in this file.

Donald's standing requirement, his words — the acceptance test for Phase 3, not
the phase checklist:

> "much leaner workflow within repos, less token consumed, nothing agent
> specific, installer easy peasy"

His fifth-session verdict is on the unmerged branch
`docs/handoff-donalds-verdict` (`cc71fd3`). Read it before proposing anything.

## Open PRs — all pushed, none merged

| Repo | PR | Net |
|---|---|---|
| core | [#87](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/87) retire `normalize-claude-md` + the uncalled checker + core's first `CLAUDE.md` + the audit | +379 / −10,801 |
| core | [#88](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/88) **Phase 2**, branched from #87 | +424 / −27 |
| agents-task-viewer | [#19](https://github.com/agenticapps-eu/agents-task-viewer/pull/19) | +139 / −25,847 |
| callbot | [#101](https://github.com/agenticapps-eu/callbot/pull/101) | +45 / −473 |
| cparx | [#126](https://github.com/agenticapps-eu/cparx/pull/126) | +38 / −181,650 |
| fx-signal-agent | [#121](https://github.com/agenticapps-eu/fx-signal-agent/pull/121) | +10 / −187 |
| fbc-platform | [#119](https://github.com/agenticapps-eu/fbc-platform/pull/119) | +1 / −179 |

Current branch: `feat/one-skills-payload`. Core is green — `openspec validate
--all` passes, all test suites pass, the gate exits 0 unaided.

## Done

- **Phase 1** — verified already done (all four hosts pin `ef030d0`, every
  sha256 still matches core's tree). Skipped, not deferred.
- **§5a** — archived `claude-workflow`, `codex-workflow`, `opencode-workflow`,
  `pi-agentic-apps-workflow`, `agenticapps-roadmap` by settings toggle.
- **Audit items 1–5** — `normalize-claude-md` retired; `provisioning-check.sh` +
  suite deleted (1,202 lines, no caller); the false "gate blocks on reviews"
  rule corrected in callbot ×2 and fx-signal-agent; one instruction file per
  repo in six repos; `.planning/` gone everywhere; `~/.codex/AGENTS.md` deleted;
  record in `docs/instruction-file-audit-2026-08.md`.
- **Phase 2** — `skills/agentic-apps-workflow` (235) + `skills/openspec-change-review`
  (150) replace ~5,000 lines across 5 + 3 + ~12 copies. `spec/11` amended: the
  discipline block now lives in the skill once, and **a project carrying none is
  conformant** — that is what unlocks the token reduction.

## Phase 3 — the installer. Host facts already measured, do not rediscover

```
./install.sh                          # payload + git pre-commit. No host needed.
./install.sh --host claude --host pi  # ...plus shim wiring
./install.sh --host auto              # detect and wire what is found
./install.sh --project <path>         # pre-commit hook + a few lines in AGENTS.md
./install.sh --check                  # the doctor table
```

| host | skill dir | hook wiring | status |
|---|---|---|---|
| claude | `~/.claude/skills` | `~/.claude/settings.json` | **confirmed** |
| codex | `~/.codex/skills` | `~/.codex/hooks.json` — `{"hooks":{"<Event>":[{"hooks":[{"command":"…"}]}]}}` | **confirmed** |
| opencode | `~/.config/opencode/`**`skills`** (plural — `skill/` also exists and is NOT the one) | `~/.config/opencode/plugin/openspec-change-gate.ts` | **confirmed** |
| pi | unknown — no `~/.pi/skills`, no `~/.pi/pi.json` | unknown | **write skill dir only, wiring `null`** |
| omp | unknown — `~/.omp` holds only `agent/`, `logs/`, `run/` | unknown | **write skill dir only, wiring `null`** |

`null` wiring is a conformant state: that host runs on the git/CI floor.

Binding rules for this phase: **symlink `skills/*`, never copy** — a copy is the
drift this whole change removes. Publish `bin/*` to `~/.agenticapps/bin/`
(mode 0755) — **do not change that path**, six fleet projects shim to it and
must keep working untouched. Tier 1 is only `git` and `bash`; nothing else may
hard-fail. Tier 2 (OpenSpec, Superpowers, Linear MCP, upstream skills) is
checked, reported, and the install command **printed, never run**. Cap: 200
executable lines. If it cannot be met, stop and report which and why.

## Then

Phase 4 — rewrite the three scripts to budget: gate 775→120, run-plan-review
757→120, reviewer-cli 206→80. Rewrite against the diagram; do not port down.
Phase 5b — delete the remaining 7,765 lines in `tools/` (conformance harnesses,
the prereq analyser, drift-report; none on the diagram, nothing depends on them
now the host repos are archived). Phase 5c — strip each project to `openspec/`,
a pre-commit hook, and a pointer; §11 is now safe to remove because the skill
carries it. Phase 6 — trim the spec, ~21 sections to ~7.

## Open questions

1. **22 workflow-skill symlinks still point into the archived host repos** —
   Claude 3, Codex 8, opencode 11, pi 0 (no skills dir at all). Phase 3 is what
   replaces them. Until it lands, deleting those checkouts breaks four agents.
2. **Two installed skills both claim `name: agentic-apps-workflow` v3.2.0** and
   differ: `~/.claude/skills/agenticapps-workflow/skill/SKILL.md` (402, real dir)
   vs `~/.claude/skills/agentic-apps-workflow` (331, symlink into the archived
   `claude-workflow`). Phase 3 should replace both with a symlink into
   `core/skills/`.
3. **A `gitnexus` binary survives** at
   `~/.local/state/fnm_multishells/…/bin/gitnexus` — a leftover global npm
   package. Its opencode plugin (`gitnexus-freshness.ts`, fired on every tool
   call) was removed this session; a copy is in the session scratchpad. The
   binary was left alone deliberately: do not uninstall software the workflow
   does not own without asking. `npm rm -g gitnexus` is the fix if Donald wants it.
4. `agenticapps-dashboard` and `agenticapps-roadmap` are both **to be retired**.
   Dashboard is the last split brain (231/110) — do not spend commits tidying
   it. Two of my commits sit on its `retire-v1-surfaces` branch because it was
   not on `main` when I committed; history was not rewritten because Donald was
   working in it. cparx and fbc-platform had the same problem and **were** lifted
   onto clean branches with the originals restored byte-for-byte.
5. Core has **no** `migrations/` — §5b's "73 migration documents" has no target
   here; those 645 files are in the archived host repos.
