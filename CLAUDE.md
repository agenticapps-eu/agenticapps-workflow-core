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
