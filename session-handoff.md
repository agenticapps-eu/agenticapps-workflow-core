# Session Handoff — 2026-08-07 (eleventh session)

Two of the three active changes are plan-reviewed and **both are repaired**.
Nothing is blocked on a decision. Branch `feat/projects-bind-not-copy` carries
all of it; still **no PR** for it.

| Change | State |
|---|---|
| `one-enforcement-floor` | **two review rounds**, repaired after each, validates `--strict`. Round 2 stale by digest |
| `projects-bind-not-copy` | **two review rounds**, repaired after each, validates `--strict`. Round 2 stale by digest |
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

## Round 2, and three things I had wrong

Both changes re-reviewed 2026-08-07, three vendors each, all REQUEST-CHANGES.
Round 1 found the evidence wrong; round 2 found the mechanisms under-specified.
Three findings were mine, and each was verified before being accepted:

1. **The dangling-binding scenario was inverted.** I wrote that a
   `core.hooksPath` naming an absent directory fails every commit on the
   machine. Tested on git 2.50.1: the commit **succeeds, exit 0, silently
   ungated** — the failure mode `core-self-enforcement` calls the one that must
   never happen. opencode reasoned from the same behaviour in the opposite
   direction and was also wrong. It makes publish-before-bind more important,
   not less.
2. **The "empty `SHIMMED-HOOKS`" dividend was circular.** On `main` that file
   holds **three** names. I read this branch's working tree — stacked on #87,
   which already removes `normalize-claude-md` — and presented a post-#87 state
   as the pre-change state.
3. **The branch violates its own sequencing rule.** #87's commits are ancestors
   of HEAD, verified with `git merge-base --is-ancestor`, while the document
   said twice that #87 must not merge first. Now a **coordinated landing**: no
   ordering is green throughout, which is an argument for keeping `OPT-OUTS`
   rather than dissolving it.

Also: **pi holds 26 skills, not none** — "measured empty" was repeated from this
handoff without checking. pi is now explicitly out of scope until its directory
is bound, and the resulting regression is stated.

## Corrections to the previous handoff

- **Six repositories bind `normalize-claude-md`, not seven** — dashboard,
  roadmap, callbot, cparx, fbc-platform, fx-signal-agent. `agents-task-viewer`
  does not, which the previous handoff itself said two paragraphs later. The
  seventh was the worktree. opencode caught this; verified.
- The `883`-byte hook does not exist. Core's own is 1376.
- **`~/.pi/agent/skills` is not empty** — 26 skills, symlinked to
  `~/.agents/skills/`. Only `agentic-apps-workflow` is missing. The previous
  handoff's "measured empty" was wrong and reached the spec before it was caught.

## Next session: start here

`one-enforcement-floor` is now artifact-complete and validates `--strict`. The
`core-self-enforcement` delta is written: the inversion is **kept**, core sets a
local `core.hooksPath` that git prefers over the global binding, the installer
refuses when `git rev-parse --git-path hooks` returns the machine-level
directory, and core's binding is **declared** so the sweep cannot remove it —
it names core's own default hooks directory, so it is redundant by value and
load-bearing in fact, which is the trap.

So the remaining step before code is one thing:

**Round 2 is done and folded in.** What blocks code now is *measurement*, not
editing — see open question 2. A third review round is worth running only after
the deferred items in each `REVIEWS.md` ("Accepted as true, not yet folded in")
are written up; everything else raised is specified.

**Round 1 is preserved inside each `REVIEWS.md`** under a collapsed "Round 1 —
superseded" section. The producer publishes with `mv -f`, so it discards the
previous file including any resolution — back it up before re-running.

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
2. **Precedence has still never been measured, and it is the only thing
   blocking code.** `projects-bind-not-copy` task 1, and round 2 sharpened it:
   measure **per host**, not once, since one loader validates one host and pi
   already proves they differ. Nothing may be deleted until it is done.
3. **Each `REVIEWS.md` has an "Accepted as true, not yet folded in" list.**
   Real findings, deliberately deferred rather than dropped — blast radius
   beyond the fleet, sweep discovery, non-`pre-commit` hook types, the
   `codex-workflow` hook's per-host reviewer wiring, the nine-checkouts
   arithmetic, worktree discoverability. Write these up before a third round.
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
