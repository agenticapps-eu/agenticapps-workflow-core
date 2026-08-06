# agenticapps-workflow-core

The shared workflow logic behind the AgenticApps spec-first loop. Every host and
every fleet project resolves its behaviour from here.

`AGENTS.md` is a symlink to this file. One rule, one home — so no host can read a
different version of it.

## How to work in this repo

The loop itself lives in the **`agentic-apps-workflow` trigger skill**, not here.
Read the skill for how to work; read this file only for what this repository is.
Behaviour is deliberately not restated below — a copy competes with the original
and you never see it lose.

`docs/WORKFLOW.md` and `workflow.mmd` are the specification of that loop. If a
thing is not on that diagram and is not required to make a step on it work, it
does not belong in this repo.

## What is here

| Path | What |
|---|---|
| `skills/` | the host-neutral skills we own. **No host name may appear inside.** Symlinked into each host, never copied |
| `spec/` | the numbered spec sections — agent behaviour and the rules hosts bind |
| `adrs/` | decision records; immutable once merged |
| `reference-implementations/` | the authoritative gate, reviewer-cli, run-plan-review and project hooks |
| `openspec/` | this repo's own specs and changes — core gates itself (ADR-0028) |
| `gate/` | the published gate wiring |
| `tools/` | test suites for the above |

## Two things that surprise people

**Core gates itself.** `.claude/hooks/openspec-change-gate.sh` resolves this
repo's *working-tree* reference implementation rather than the published copy, so
core scores the bytes it ships (ADR-0028). It is the one self-hosting binder;
every other project resolves the published copy through a shim.

**The gate blocks on exactly one condition** — `openspec validate --all` is not
green. Review evidence is computed and reported, never enforced: reviewer count,
verdicts and independence all produce `NOTE` lines and none of them fails any
surface. A blocked edit means a spec delta that does not parse, so fix the delta.
It never means "go get a review". The escape hatch is `GSD_SKIP_REVIEWS=1` (name
retained for compatibility) and it is logged.

The practical consequence: a green gate is the weakest possible evidence that
anyone read the delta. Running the plan reviewers before code is a discipline you
keep, not one the machine keeps for you.

## Conventions

- Feature branches and PRs. Never commit directly to `main`.
- ADRs are append-only. Correct one with a new ADR, not an edit.
- `.planning/` was removed on 2026-08-05; OpenSpec carries the planning now.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **agenticapps-workflow-core** (2523 symbols, 2501 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/agenticapps-workflow-core/context` | Codebase overview, check index freshness |
| `gitnexus://repo/agenticapps-workflow-core/clusters` | All functional areas |
| `gitnexus://repo/agenticapps-workflow-core/processes` | All execution flows |
| `gitnexus://repo/agenticapps-workflow-core/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
