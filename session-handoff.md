# Session Handoff — 2026-08-07 (eleventh session)

Two of the three active changes are plan-reviewed and **both are repaired**.
Nothing is blocked on a decision. Branch `feat/projects-bind-not-copy` carries
all of it; still **no PR** for it.

| Change | State |
|---|---|
| `one-enforcement-floor` | reviewed (3 vendors, all REQUEST-CHANGES), **repaired**, validates. Review now stale by digest — re-review before code |
| `projects-bind-not-copy` | reviewed (2 counted, gemini rejected), **repaired**, validates `--strict`. Review stale by digest |
| `fleet-carries-only-current` | still unreviewed |

## Accomplished

- Plan-reviewed `one-enforcement-floor` — gemini, codex, opencode; claude
  excluded and recorded as excluded. All REQUEST-CHANGES.
- Plan-reviewed `projects-bind-not-copy` — codex and opencode counted. gemini
  returned a verdict with no body and the producer **rejected** it, which is
  §07 rule 3 working rather than a failure.
- Repaired `one-enforcement-floor` against the findings and Donald's coverage
  decision, and wrote the `core-self-enforcement` delta it was missing.
- Repaired `projects-bind-not-copy`, including Donald's decision to **remove
  `database-sentinel`**. `openspec validate --all --strict` green, 12/12.

## The finding that mattered, and no reviewer made it

`design.md` nominated its own fatal objection — *"the set displaced by a global
binding is empty… that is the objection that would kill this decision if it
held"* — and the measurement behind it was false in every clause.

Re-measured with `git rev-parse --path-format=absolute --git-path hooks` rather
than by assuming `.git/hooks`: **11 repositories**, 10 distinct hooks
directories, **15 hook types**, and **husky ^9.1.7 + lint-staged** in
`fbc-platform` since 15 July. Sizes 1201/1376/2270/5844/39 — nothing is 883.
The original sweep almost certainly used a `find` that missed worktrees and
`core.hooksPath` redirection; mine did too on the first attempt, and gave three
different answers before it was right.

**Husky survives anyway, and that is the real finding.** It sets a *local*
`core.hooksPath`, and git prefers local over global. So the decision is correct
on grounds it never stated — and the true premise cuts both ways: **six
repositories already set a local binding**, so the new floor reaches none of
them, including three of the five carrying the gate. Five are redundant (they
name the directory git resolves anyway); Donald chose to sweep those and leave
`fbc-platform`'s husky binding as a genuine opt-out. That is now in the change.

## Corrections to the previous handoff

- **Six repositories bind `normalize-claude-md`, not seven** — dashboard,
  roadmap, callbot, cparx, fbc-platform, fx-signal-agent. `agents-task-viewer`
  does not, which the previous handoff itself said two paragraphs later. The
  seventh was the worktree. opencode caught this; verified.
- The `883`-byte hook does not exist. Core's own is 1376.

## Next session: start here

`one-enforcement-floor` is now artifact-complete and validates `--strict`. The
`core-self-enforcement` delta is written: the inversion is **kept**, core sets a
local `core.hooksPath` that git prefers over the global binding, the installer
refuses when `git rev-parse --git-path hooks` returns the machine-level
directory, and core's binding is **declared** so the sweep cannot remove it —
it names core's own default hooks directory, so it is redundant by value and
load-bearing in fact, which is the trap.

So the remaining step before code is one thing:

**Re-review.** The repair and the delta both changed the artifacts, so the
trailer's `tasks-digest` no longer matches and the gate already reports the
review as stale — correctly.

```
REVIEW_TIMEOUT=600 run-plan-review.sh <slug> --implementing-host claude
```

`REVIEWER_TIMEOUT` still does not reach that script. `REVIEW_TIMEOUT` does.

Both changes need it, so one pass covers both. Then review
`fleet-carries-only-current`, which has never been reviewed at all.

## Open questions

1. ~~`database-sentinel`~~ — **decided 2026-08-07: removed with the surface.**
   Not free, and the change says so: the `DROP`/`TRUNCATE`/`DELETE`-without-
   `WHERE` arms are the only interception of an irreversible action in the
   workflow, and "caught again at commit and in CI" is false for them because
   destructive SQL never enters git. Removed because it fires from
   `.claude/settings.json` and so reaches one host of five. Protection
   reassigned to the operator's own Bash deny rules, not claimed as surviving.
   Falls out for free: `SHIMMED-HOOKS` held two names, both go, so the
   declaration is empty and there are no sanctioned extras for `OPT-OUTS` to
   express.
2. **Precedence has still never been measured**, and it gates every deletion in
   `projects-bind-not-copy` (its task 1). pi's `~/.pi/agent/skills` is still
   neither bound nor swept, so "every host reads a directory the installer
   binds" is false as written and must be fixed or scoped. These are
   measurements, not edits — they are what actually blocks code.
3. **The plan-review producer records vendor names but not resolved models.**
   §07 rule 4 asks for models; two arms on one model would be one opinion
   wearing two names, and neither review record can rule that out.
4. `docs/HOW-IT-FITS-TOGETHER.md` is still provably wrong. Task 6.3.
5. `workflow.mmd` still says the gate requires "REVIEWS ≥ 2". Untrue since 2.0.0.
6. Reported paths still carry `/Users/donald` unescaped — deferred to
   `screen-review-egress` for the fourth time.
7. Does `AGENTS.md` still need a workflow section once the skill carries it?
8. The gitnexus skills still load in this repo until deleted. Not decided.
9. **PRs #78, #86, #87, #88 open.** Still no PR for `feat/projects-bind-not-copy`.
