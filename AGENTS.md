# agenticapps-workflow-core

The shared workflow logic behind the AgenticApps spec-first loop. Every host and
every fleet project resolves its behaviour from here.

`AGENTS.md` and this file are two regular files holding identical content. One
rule, two names — and the pre-commit gate fails a commit in which they diverge,
so no host can read a different version of it.

`AGENTS.md` was a symlink to this file until 2026-08-10. The link made them the
same bytes by construction, which was a real guarantee bought at a real price: a
mechanism delivering an eight-line pointer took ownership of the entire file, and
when the initializer got a guard wrong it cost two repositories 22,292 bytes.
Identity is enforced now instead of constructed. Edit both, or edit one and copy
it over the other — the gate will not let you forget.

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

**The gate blocks on two conditions, and neither of them is a review.**
`openspec validate --all` must be green, and — at commit time only — `AGENTS.md`
and `CLAUDE.md` must be readable, regular and byte-identical. Review evidence is
computed and reported, never enforced: reviewer count, verdicts and independence
all produce `NOTE` lines and none of them fails any surface. A blocked edit means
a spec delta that does not parse, so fix the delta. It never means "go get a
review". Neither blocker has an escape hatch, and §18 names both as taking none:
for a red `validate` there is nothing to release, and for the pair a hatch could
only ever permit committing the divergence the check exists to prevent.

The practical consequence: a green gate is the weakest possible evidence that
anyone read the delta. Running the plan reviewers before code is a discipline you
keep, not one the machine keeps for you.

## Conventions

- Feature branches and PRs. Never commit directly to `main`.
- ADRs are append-only. Correct one with a new ADR, not an edit.
- `.planning/` was removed on 2026-08-05; OpenSpec carries the planning now.

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->

## The AgenticApps workflow

Work moves through the OpenSpec lifecycle, and how to do that lives in the
`agentic-apps-workflow` skill on this machine — not in this file. Read the
skill for the loop, the gates and the coding discipline.

This repository carries two workflow artifacts: `openspec/`, which is its
durable truth, and this instruction file. Everything else — skills, hooks,
enforcement — is machine-level and comes from `install.sh`.

<!-- END: agentic-apps-workflow sections -->
