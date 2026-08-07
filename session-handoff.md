# Session Handoff — 2026-08-07 (eleventh session)

Two of the three active changes are now plan-reviewed, and one is repaired.
Nothing is blocked on a decision. Branch `feat/projects-bind-not-copy` carries
all of it; still **no PR** for it.

| Change | State |
|---|---|
| `one-enforcement-floor` | reviewed (3 vendors, all REQUEST-CHANGES), **repaired**, validates. Review now stale by digest — re-review before code |
| `projects-bind-not-copy` | reviewed (2 counted, gemini rejected), resolution written, **not repaired** |
| `fleet-carries-only-current` | still unreviewed |

## Accomplished

- Plan-reviewed `one-enforcement-floor` — gemini, codex, opencode; claude
  excluded and recorded as excluded. All REQUEST-CHANGES.
- Plan-reviewed `projects-bind-not-copy` — codex and opencode counted. gemini
  returned a verdict with no body and the producer **rejected** it, which is
  §07 rule 3 working rather than a failure.
- Repaired `one-enforcement-floor` against the findings and Donald's coverage
  decision. `openspec validate --all` green, 12/12.

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

Then repair `projects-bind-not-copy` against its resolution, and review
`fleet-carries-only-current`, which has never been reviewed.

## Open questions

1. **`database-sentinel` — still open, but no longer shapeless.** Donald asked
   whether it adds anything given the `cso` skill. It does, and not where the
   change assumes: `cso` is *detection* (on-demand audit), the hook is
   *interception* (exit 2 at the tool-call boundary). Read the three arms
   separately — the `.env` arm is genuinely redundant and is also the most
   easily bypassed, since `cat > .env` via Bash presents no `file_path` for it
   to see; the `DROP`/`TRUNCATE` and `DELETE`-without-`WHERE` arms are the only
   thing in the whole workflow that stops an **irreversible** action, and the
   "caught again at commit and in CI" argument that justified deleting the host
   hook is simply false for them — destructive SQL never touches git.
   The hook's own header refuses the credit anyway: not a security boundary,
   `psql -f` bypasses the regex entirely, "a speed bump, not a control."
   The real comparison is therefore the harness's own Bash permission prompts,
   not `cso`. Proposed third option: **drop the `.env` arm, keep the SQL arms,
   stop calling it fleet-shared** — one narrow declared exception is
   expressible in `check-shims.sh`, where a whole undecided hook is not.
   Cutting the other way: it protects claude sessions only, so codex, opencode
   and pi get nothing, and multi-agent is permanent. Not decided.
2. **`projects-bind-not-copy` omits its dependency on `one-enforcement-floor`.**
   cparx has no floor at all, so removing its `PreToolUse` entry first leaves it
   with nothing. The chain order is right; the change does not record it.
3. **The precedence claim in `projects-bind-not-copy` is asserted in the spec
   delta and admitted unmeasured in the design.** Nothing may be deleted before
   task 1 measures it. pi's `~/.pi/agent/skills` is still neither bound nor
   swept, so "every host reads a directory the installer binds" is false as
   written.
4. **The plan-review producer records vendor names but not resolved models.**
   §07 rule 4 asks for models; two arms on one model would be one opinion
   wearing two names, and neither review record can rule that out.
5. `docs/HOW-IT-FITS-TOGETHER.md` is still provably wrong. Task 6.3.
6. `workflow.mmd` still says the gate requires "REVIEWS ≥ 2". Untrue since 2.0.0.
7. Reported paths still carry `/Users/donald` unescaped — deferred to
   `screen-review-egress` for the fourth time.
8. Does `AGENTS.md` still need a workflow section once the skill carries it?
9. The gitnexus skills still load in this repo until deleted. Not decided.
10. **PRs #78, #86, #87, #88 open.** Still no PR for `feat/projects-bind-not-copy`.
