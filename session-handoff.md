# Session Handoff — 2026-07-29 (second session of the day)

## The one thing to know

**All 12 §15-removal PRs are merged.** Plan step 1 is done fleet-wide. Step 4 is
answered: **keep all four hosts, do step 3 first.**

Work has moved to `feat/step3-hook-shims-and-dead-gate-removal` in core, which
carries **two open OpenSpec changes**, both planned and reviewed, **neither
implemented**. Read `openspec/changes/*/proposal.md` before anything else.

## Accomplished

### The twelve PRs landed

Core #46 first (spec 1.2.0), then claude-workflow #107, codex #32, opencode
#22, pi #18, dashboard #83, roadmap #9, agents-task-viewer #14, fbc-platform
#102, callbot #97, cparx #108, fx-signal-agent #117.

- **callbot needed a real fix**: `pnpm format:check` failed on the four
  OpenSpec markdown files its branch adds. Formatted (`914d24a`), CI green,
  merged. That PR also carried an unrelated payload — the whole
  `fix-sms-rate-limit-ordering` change, 386 new lines.
- **cparx and fx-signal-agent were merged red, on the operator's call.** Both
  fail on jobs `main` already fails (`frontend-contrast` Playwright timeouts;
  `gitleaks` + `pnpm-audit`). Neither PR touches anything those jobs test.

### Core has an OpenSpec slot again

`openspec init --tools claude`. This does **not** migrate `spec/`'s 19 sections
into `openspec/specs/` — that remains the open question. Core's durable spec is
still `spec/*.md`.

### Two changes planned (commits 27233b3 → bafc5a4)

**`shim-project-hooks`** — plan step 3a. Seven repos carry the same eight
hooks (634 lines each). Measurement found five should not exist:

| Hook | Fate |
|---|---|
| `phase-sentinel`, `architecture-audit-check` | delete — inert, gate on paths in no repo |
| `design-shotgun-gate` | delete — fails closed on a sentinel GSD stopped writing |
| `skill-router-log`, `session-bootstrap` | delete — write live data into frozen `.planning/` |
| `normalize-claude-md` | shim, fail open — dashboard's version canonical |
| `database-sentinel` | shim, **fail closed** — callbot's `.env` wildcard canonical |
| `openspec-change-gate` | unchanged — already the template |

8 hooks → 3 per project; 634 lines → ~138.

**`track-and-conform-plan-review`** — the review pipeline. Grew from a
one-file floor fix to **three shared-bin artifacts plus §18**, on the
operator's explicit "one change covering the whole pipeline".

## Decisions

- **Keep all four hosts; step 3 before step 5.** Evidence: ~2,277 Claude
  co-authored commits vs zero from codex/opencode/pi. codex (28) and opencode
  (37) are heavy *reviewer* users, but that runs through `reviewer-cli.sh`, not
  the host repos — gemini is the #1 reviewer with no host repo at all.
- **Security hooks fail closed, cosmetic fail open.** §18's CI floor covers the
  OpenSpec gate only; nothing else checks destructive SQL or `.env`.
- **Reconcile by superset, not recency.** callbot's `.env` wildcard beats the
  four-suffix enumeration in dashboard/cparx.
- **Delete the telemetry pair rather than relocate it.** Logs are gitignored
  everywhere, tracked nowhere; sole consumer is the other hook.
- **Egress: document the boundary now, defer secret/PII screening** as a named
  follow-up.

## Two things I got wrong — both caught by review, not by me

1. **§02 does not forbid deleting `design-shotgun-gate.sh`.** §02 binds
   `design-shotgun` to the gstack *skill* (`SKILL.md:106`); the hook merely
   shares the name. My "repair, don't delete" correction was a category error,
   and the three-state repair I designed would have introduced the same
   blocking bug in `claude-workflow`, which has a stale `current-phase/`.
2. **`gate/run-plan-review.sh` is not the canonical source.** It is a 66-line
   ancestor with no version marker. The real 227-line 1.0.0 lives **only** in
   `~/.agenticapps/bin/`, tracked in no repo.

I also relayed codex's injection claim uncritically — "a committed log line can
inject fleet-wide" is false, because the logs are gitignored.

## Defects found (all verified against code, none yet fixed)

- **`design-shotgun-gate` blocks 204 design files today** in callbot and
  fbc-platform — every `.tsx`/`.css` edit.
- **§18 is self-contradictory.** Truth table + line 80 say ≥1; lines 146 and
  174 say ≥2. It is not satisfiable as written.
- **The gate counts headings, not verdicts.** `reviewer_count()` matches
  `## Reviewer`; `pending_rejections()` parses verdicts. A verdict-less section
  counts. Demonstrated live — opencode counted three times this session while
  returning no verdict.
- **`MIN_REVIEWERS=0` is accepted**, publishing a `REVIEWS.md` whose floor was
  never evaluated.
- **`reviewer-cli.sh` passes the full prompt as argv** to all four vendor arms.
- **Reviews are not bound to what they reviewed.** Both changes on this branch
  were revised after review and still carry their old `REVIEWS.md`.
- **Self-exclusion is guessable.** `OPENSPEC_GATE_SELF` defaults to `claude`,
  wrong on every other host; at a floor of one, a self-review opens the gate.

## Files modified

- `openspec/` — new slot, two changes with proposal/design/specs/tasks/REVIEWS
- `.claude/commands/opsx/`, `.claude/skills/openspec-*` — from `openspec init`
- `factiv/callbot` — prettier formatting of four OpenSpec markdown files
- Nothing else. **No implementation code has been written for either change.**

## Next session: start here

A re-review of **both** changes was running when this session ended
(background task `bhuok8t90`). Read
`openspec/changes/*/REVIEWS.md` first and address the verdicts. Then implement
`track-and-conform-plan-review` **before** `shim-project-hooks` — it repairs
the machinery that reviews everything else, and its task 9b.13 explicitly
re-checks this branch's own two changes under gate 1.5.0, where both should
read as stale.

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered; the slot now exists, which changes nothing about the migration.
- **§02 is written entirely in GSD vocabulary** — every gate triggers on "a
  phase", `CONTEXT.md`, `*-PLAN.md`. §18 already retargeted `plan-review` out
  of it. This is the root cause of which the dead hooks were symptoms, and it
  is the substance of plan step 5.
- **`gate/` is untracked in core** and only `run-plan-review.sh` is resolved by
  the open change. Its other contents (`openspec-change-gate.sh`, `pre-commit`,
  `hooks/`, `README.md`) still need a keep/track/delete call, as do the other
  13 untracked items from the previous handoff.
- **Deferred, recorded in proposals**: two optional advisory prompts
  (architecture review on a big commit; database review when the DB is
  touched), and secret/PII screening before review egress.
- `fx-signal-agent` still has 2 gitleaks findings in history and a failing
  supply-chain job on `main`; cparx's `frontend-contrast` fails on `main`.
