# Session Handoff — 2026-07-29 (fourth session) / 2026-07-30

## The one thing to know

Round 6 ran on both changes and **everything is committed** — three commits on
`feat/step3-hook-shims-and-dead-gate-removal`, working tree clean of change
artifacts. `openspec validate --all` is green.

The `REVIEWS.md` on disk is **round 6**, written against pre-round-6 text.
Round 6's findings have now been folded in, so under these changes' own
proposed rule that evidence is again stale. Neither change is implemented.

## Accomplished

- Committed rounds 4–6 revisions (`df10f75`) — three sessions of work that had
  been sitting uncommitted.
- Ran round 6 against gemini, codex, opencode at `REVIEW_TIMEOUT=600
  MIN_REVIEWERS=1`; committed the evidence (`d6f884a`).
- Verified every load-bearing reviewer claim against disk, then folded in
  8 confirmed defects plus the accepted reviewer feature requests (`6184d9c`).

### Round 6 verdicts

| Change | gemini | codex | opencode |
|---|---|---|---|
| `track-and-conform-plan-review` | REQUEST-CHANGES | REQUEST-CHANGES | REQUEST-CHANGES |
| `shim-project-hooks` | REQUEST-CHANGES | REQUEST-CHANGES | **no verdict** |

gemini **flipped `shim` from APPROVE** (rounds 4, 5) to REQUEST-CHANGES against
requirements the round-6 revision had newly added. opencode returned no verdict
for the **third time** (rounds 2, 4, 6) — live evidence for `track`'s own
verdict-and-substance rule.

### The 8 confirmed self-contradictions, all now fixed

1. **Section-boundary rule shipped in two mutually exclusive versions** —
   `design.md:325`/`proposal.md:161` said "any level"; the delta said "level 1
   or 2" *and denounced "any level" as the rejected wording*. Round 5 fixed the
   delta and never propagated it. Worst of the eight: an implementer following
   `design.md` builds the truncating parser the delta forbids.
2. Version-namespace collision — "since 1.1.0" (spec) vs "since 1.4.0" (gate),
   neither labelled. Found independently by codex and opencode.
3. Migration Plan named the wrong coupled pair — "steps 3 and 4" (both producer
   steps) instead of 4-before-8 (producer before gate).
4. Two step 9s.
5. **"52-case harness" was fabricated** — `tools/change-gate-conformance.sh`
   states no case count; it computes its own total.
6. `spec_version` bump target unnamed → now 1.2.0 → 1.3.0, minor, with reasons.
7. `claude-workflow` called touched and untouched in adjacent sentences.
8. `shim` tasks 4.3 and 5.3 contradicted on `agents-task-viewer`'s hook count.

### Facts established by verification, not review

- **`MultiEdit` does not exist on this host.** Absent from the tool list;
  `ToolSearch select:MultiEdit` finds nothing. The six-repo matcher edit is
  forward-compatibility, **not protection gained** — now stated in `tasks.md`
  so no completion report can claim otherwise. Task 4.8 still settles it.
- **The trailer guard must be line-anchored.** opencode's own round-6 review
  quotes `openspec-review-trailer` inline; codex's quotes `## Reviewer: codex-2`
  inline. The shipped forge guard is anchored (`^[[:space:]]*##…`) so the second
  survived correctly — but a substring trailer guard would have destroyed the
  first. Regression-tested as task 7b.7a.
- **No project sets `env` in `.claude/settings.json`** (checked all seven), so
  restricting the override to the process environment closes the door before
  anyone walks through it.
- `agenticapps-dashboard-add-agent-board` is a **worktree**, already recorded.

## Decisions

- **Scope: fix the 8 + accept reviewer feature requests** (operator's call over
  "fix and freeze"). Requests accepted with limits stated rather than adopted
  wholesale — provenance is bounded as *drift detection, not tamper-proofing*;
  consumer sandboxing is **declined** as unenforceable and untestable.
- **"Superset of protection" demoted** from unconditional rule to reviewed
  default. codex was right that unioning seven variants propagates one
  project's false positive to all of them.
- **The override is a kill switch and says so** — one variable pointed at a
  missing path disables a hook on a healthy machine. Follows from fail-open;
  now in the coverage boundary, not buried.
- **Normalisation manufacturing verdicts is accepted explicitly**
  (`REQUEST-_CHANGES` → valid). The alternative reintroduces the placement
  enumeration the rule removed, to defend against a typo read correctly.
- **Rejections stay non-blocking** — unchanged, per §18 and CLAUDE.md.

## Files modified

- `openspec/changes/track-and-conform-plan-review/` — proposal, design, tasks,
  both spec deltas, `REVIEWS.md` (round 6)
- `openspec/changes/shim-project-hooks/` — proposal, tasks, spec delta,
  `REVIEWS.md` (round 6, opencode verdictless)
- `session-handoff.md` — this file
- **No implementation code.** Commits: `df10f75`, `d6f884a`, `6184d9c`.

## Next session: start here

**Decide whether to review again or start implementing.** Six rounds have each
found at least one real defect, and round 6's were still severe (item 1 above).
But the trend is now clear: rounds 5 and 6 found defects *in the previous
round's fixes*, not in the original design — the changes are accreting surface
faster than they are settling. A seventh round will most likely repeat that.

Recommendation: **implement `track-and-conform-plan-review` first** — it repairs
the machinery everything else is reviewed by, and task 9b.19 re-checks this
branch under gate 1.5.0. Run a final review only after implementation, where
findings are testable against running code rather than against prose.

If you do run round 7, the command is unchanged:
`REVIEW_TIMEOUT=600 MIN_REVIEWERS=1 ~/.agenticapps/bin/run-plan-review.sh <slug> gemini codex opencode`

## Reviewer reliability — check before acting

Roughly one claim in four is still wrong. Round 6 specifically:

- opencode: "`openspec status` does not report the `specs/**/*.md` glob" —
  **correct**, and the justification citing it has been dropped.
- codex: "the change contradicts §16" — **downgraded**. §16 scope is already
  declared out of scope at `proposal.md:216-218`; it is the standing open
  question, not a new defect.
- opencode's `·`-under-`LC_ALL=C` portability claim — **real but minor**; byte
  matching works, so it was specified rather than treated as a blocker.
- Prior rounds: opencode's "`Edit` matchers also match `MultiEdit`" was false;
  codex twice claimed codex was the implementing host (it is claude).

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered. codex raised it again in round 6 as a §16 contradiction.
- **§02 is written in GSD vocabulary** — root cause behind the dead hooks, and
  the substance of plan step 5.
- **`gate/` remains unclassified** apart from `run-plan-review.sh`, which
  `track` deletes. Its README, gate copy, `pre-commit` and `hooks/` still need a
  keep/track/delete call, as do the other untracked root items (`.planning/`,
  the PDFs, `prompts/`, the `.mmd` diagrams).
- **`screen-review-egress`** — deferred secret/PII screening, named and owned in
  `track`'s proposal, still not a change.
- Vendor CLIs can **write and execute**, not only read. Declared, not mitigated.
