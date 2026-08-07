# Session Handoff — 2026-08-05 (sixth session)

Two briefs: collapse the workflow to one repo, and — first — audit the
instruction files. This session closed collapse Phase 1 and §5a, audit items
1–5, and is starting **Phase 2**. Subtraction so far: ~10,800 deletions against
~360 insertions in core, plus the fleet edits.

Donald's fifth-session verdict is on the unmerged branch
`docs/handoff-donalds-verdict` (`cc71fd3`). Read it.

## Donald's standing requirement (2026-08-05, verbatim intent)

> "much leaner workflow within repos, less token consumed, nothing agent
> specific, installer easy peasy"

That is the acceptance test for Phase 2 and 3. Measure against it, not against
the phase checklist.

## Open PRs (all pushed)

core [#87](https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/87) ·
agents-task-viewer [#19](https://github.com/agenticapps-eu/agents-task-viewer/pull/19) ·
callbot [#101](https://github.com/agenticapps-eu/callbot/pull/101) ·
cparx [#126](https://github.com/agenticapps-eu/cparx/pull/126) ·
fx-signal-agent [#121](https://github.com/agenticapps-eu/fx-signal-agent/pull/121) ·
fbc-platform [#119](https://github.com/agenticapps-eu/fbc-platform/pull/119)

Combined: **+612 / −219,137**.

## The measurement that defines Phase 2

Per-session workflow context, per repo — loaded every session, in every repo:

| repo | instr | wf-config | vendored wf | vendored SKILL | total |
|---|---:|---:|---:|---:|---:|
| dashboard | 231 | 99 | 0 | 331 | 661 |
| agents-task-viewer | 289 | 76 | 90 | 324 | 779 |
| callbot | 579 | 102 | 90 | 324 | 1095 |
| cparx | 432 | 101 | 90 | 324 | 947 |
| fbc-platform | 132 | 98 | 90 | 346 | 666 |
| fx-signal-agent | 303 | 98 | 90 | 324 | 815 |

**4,963 lines ≈ 10.7k tokens per session per repo.** 324–346 of each repo's
lines are a *copy* of the trigger skill. Target: a project carries `openspec/`,
a pre-commit hook, and a few lines pointing at the skill. Nothing else.

## The gap §5a opened — Phase 2 closes it

Archiving the host repos before Phase 2 was the wrong order (my error). Every
host's workflow skills are **symlinks into the four archived repos**: Claude 3,
Codex 8, opencode 11, pi 0 (no skills dir at all), omp 0. 22 dangling
dependencies. It works only because the local checkouts survive.

## Phase 2 design — settled by measurement, not by the brief's guess

The brief's tier-3 list (trigger, openspec-change-review, database-sentinel,
impeccable) is **wrong on two of four**:

- `database-sentinel` is upstream — `github.com/Farenhytee/database-sentinel`.
- `impeccable`, `cso`, `qa` come from gstack.

All four are **tier 2: bound, not owned.** They are already installed globally
and host-neutral. Core must not carry copies (ADR-0024).

The `codex-*` / `opencode-*` / `pi-*` prefixed gate skills are **thin wrappers**
— e.g. `codex-database-sentinel-audit` is 136 lines that only say *when* the
gate fires and then invoke the real skill. There are ~12 of them across three
hosts. They are the agent-specific layer Donald wants gone. Their only real
content — the gate-firing conditions — belongs in one gate table in the trigger
skill.

**So tier 3 is TWO skills, not four:**

```
core/skills/
  agentic-apps-workflow/SKILL.md    # the diagram in prose + gate table
  openspec-change-review/SKILL.md   # produces REVIEWS.md entries
```

The trigger skill must **absorb three things that today have no other home**,
or deleting their copies deletes the rules:

1. the §11 coding discipline (~80 lines, in every project's instruction file);
2. the task-size routing table (only in cparx, and its Medium row still named
   dead `/prompts:gsd-*` commands — translated in PR #126);
3. the gate-to-skill bindings currently spread across the 12 wrappers.

Also unblocks trimming the workflow section out of `~/.claude/CLAUDE.md`.

## Next session: start here

Write `core/skills/agentic-apps-workflow/SKILL.md` against `workflow.mmd` —
rewrite, do not pick a winner among the existing copies (331 / 402 / 654 / 621 /
465 lines, three of them claiming version 3.2.0 or 1.2.x). Then
`openspec-change-review`. Then Phase 3's `install.sh` + `hosts/*.json`, which
symlinks `skills/*` into each host's skill dir so `git pull` in core updates
every host with no install step.

## Open questions

1. **Two installed skills both claim `name: agentic-apps-workflow` v3.2.0** and
   differ: `~/.claude/skills/agenticapps-workflow/skill/SKILL.md` (402 lines,
   real dir) vs `~/.claude/skills/agentic-apps-workflow` (331, symlink into the
   archived `claude-workflow`). Which loads is loader ordering. Phase 2 resolves
   it by publishing one copy from core.
2. `agenticapps-dashboard` and `agenticapps-roadmap` are both to be **retired**
   (Donald, this session). Dashboard is the last split brain (231/110); do not
   spend commits tidying it. Two of my commits sit on its `retire-v1-surfaces`
   branch — the `.planning` deletion and the §18 fix — because it was not on
   `main` when I committed; history was not rewritten because he was working in
   it. cparx and fbc-platform had the same problem and **were** lifted onto clean
   branches with the originals restored byte-for-byte.
3. Budgets still far out: gate 775/120, run-plan-review 757/120, reviewer-cli
   206/80, `install.sh` does not exist (0/200). `tools/` still holds 7,765 lines
   of conformance harnesses, the prereq analyser and drift-report — none on the
   diagram, nothing depends on them now the host repos are archived. That is
   Phase 5b and it is the largest single deletion left.
4. Core has **no** `migrations/`; §5b's "73 migration documents" has no target
   here — those 645 files are in the archived host repos.
