# Precedence measurement — task 1

Measured 2026-08-07 on this machine, after PRs #87 and #88 merged. Evidence
below, conclusions last. Every number here was observed, not inferred.

## What competes

| Location | Kind | Version | Lines |
|---|---|---|---|
| `~/.claude/skills/agentic-apps-workflow` | symlink → core `skills/` | **4.0.0** | 235 |
| `~/.codex/skills/agentic-apps-workflow` | symlink → core `skills/` | **4.0.0** | 235 |
| `~/.config/opencode/skills/agentic-apps-workflow` | symlink → core `skills/` | **4.0.0** | 235 |
| `~/.agents/skills/agentic-apps-workflow` | symlink → core `skills/` | **4.0.0** | 235 |
| `~/.pi/agent/skills/agentic-apps-workflow` | **absent** | — | — |
| `<repo>/.claude/skills/agentic-apps-workflow` × 7 | real directory | **3.2.0** | 324–346 |

Four host-level bindings, all resolving to the same file in core. The project
copies are the only source of v3.2.0.

## Correction: seven repositories, not eight

Task 1.1 says eight. `FLEET` names seven, and seven is what carries a copy:
dashboard, roadmap, agents-task-viewer, callbot, cparx, fbc-platform,
fx-signal-agent. Core itself carries none. The eighth does not exist — this is
the same worktree-shaped miscount that produced "seven bind `normalize-claude-md`"
when the answer was six.

## Correction: five byte-identical siblings and two outliers, not three and one

Task 1.3 nominates fbc-platform as the lone local edit against "three
byte-identical v3.2.0 siblings". Measured by MD5:

| Hash | Lines | Repositories |
|---|---|---|
| `d95f20c069b52b384f28132d70f1bf8f` | 324 | roadmap, agents-task-viewer, callbot, cparx, fx-signal-agent — **five** |
| `39ff7b14d9942ea88e3518f8c6c479a5` | 346 | fbc-platform |
| `07c0b36a7507cd964c3edd8519ca477a` | 331 | **agenticapps-dashboard** |

Dashboard is a second outlier the task does not mention, and its 331 lines match
the size global `CLAUDE.md` attributes to the archived `claude-workflow/skill`.
Four repositories also carry a stale `SKILL.md.pre-0034` beside the live file —
roadmap, agents-task-viewer, callbot, fx-signal-agent.

## Claude: the host binding wins, 4 of 4

Probe: `claude -p` in the repository, file tools disallowed so the answer comes
from the loaded skill list rather than from disk, asking for the first line of
the `agentic-apps-workflow` description. v4.0.0 opens "The AgenticApps
spec-first workflow."; v3.2.0 opens "Enforces the spec-first development
workflow using OpenSpec + Superpowers +". The two are unmistakable.

| Repository | Copy present | Resolved |
|---|---|---|
| cparx | v3.2.0 (majority hash) | **v4.0.0 — binding** |
| agenticapps-dashboard | v3.2.0 (331-line outlier) | **v4.0.0 — binding** |
| fbc-platform | v3.2.0 (346-line outlier) | **v4.0.0 — binding** |
| agents-task-viewer | v3.2.0 (majority hash) | **v4.0.0 — binding** |

Stable across both outlier variants. On Claude, the project copies are inert.

## Codex: bound, and nothing competes

No `.codex/skills/agentic-apps-workflow` exists in any fleet repository. Every
repo's `.codex/skills` holds exactly the six `openspec-*` skills and nothing
else. Probed in fbc-platform, codex resolved "The AgenticApps spec-first
workflow." — the binding, uncontested.

## opencode: the winner is a race, and this is the finding

opencode reads **four** directories that all carry the name — the three global
symlinks plus the project's `.claude/skills`. It logs each collision:

```
message="duplicate skill name" name=agentic-apps-workflow
  existing=~/.claude/skills/…  duplicate=~/Sourcecode/factiv/cparx/.claude/skills/…
```

Each line's `existing=` is the previous line's `duplicate=`, so a later
discovery replaces an earlier one and **the last directory scanned wins**. The
scan order was different in every repository measured:

| Repository | Discovery order | Last (winner) |
|---|---|---|
| cparx | `.claude` → project → `.agents` → `opencode` | global (v4.0.0) |
| fbc-platform | `.claude` → `.agents` → `opencode` → project | **project (v3.2.0)** |
| callbot | `.claude` → `opencode` → project → `.agents` | global (v4.0.0) |
| agents-task-viewer | `.claude` → `.agents` → project → `opencode` | global (v4.0.0) |
| agenticapps-dashboard | `.claude` → `.agents` → `opencode` → project | **project (v3.2.0)** |
| agenticapps-roadmap | `.claude` → `opencode` → `.agents` → project | **project (v3.2.0)** |

Independently corroborated by model probes, which disagreed **with themselves**:
three runs in cparx returned v3.2.0, v4.0.0, v3.2.0. The same repository, the
same command, a different skill loaded.

## pi: out of scope, and the sweep costs it nothing

`~/.pi/agent/skills` holds 25 entries symlinked to `~/.agents/skills/` and
`agentic-apps-workflow` is not among them. But no fleet repository has a copy in
`.pi/skills` either — those directories hold the same six `openspec-*` skills.

**This corrects task 1.5.** It says to record that a pi session in a swept
repository will resolve no workflow skill, framed as a regression the sweep
causes. A pi session resolves no workflow skill *today*, before any sweep. The
sweep takes nothing from pi, because pi never had it.

## Conclusions

1. **Task 1.2's trigger fires, but only partly.** On Claude and codex the
   binding wins and the copies are inert, so the urgency does not survive there.
   On opencode it is a coin toss, so on one of three bound hosts the copies are
   live and can shadow v4.0.0 with v3.2.0.
2. **The race is a better argument for the change than the one the proposal
   makes.** A copy that reliably loses is untidy. A copy that wins in half of
   sessions means the fleet is running two different workflow versions
   non-deterministically, and no one can tell which from inside the session.
3. **Deleting the copies removes the race** — with one global source, every
   ordering resolves to v4.0.0. That holds regardless of scan order, which is
   what makes it a fix rather than a reshuffle.

## Two things found on the way that are not task 1

- `~/.claude/skills/agenticapps-workflow` — the 402-line rival global
  `CLAUDE.md` warns about — **no longer exists**. That warning is stale, and
  `~/.claude/skills/ts-declare-first` is now a **dangling symlink** into the
  deleted directory.
- `~/.config/opencode/opencode.json` still registers a **gitnexus MCP server**,
  pointing at a binary in a stale fnm multishell path. GitNexus was removed on
  2026-07-28.
