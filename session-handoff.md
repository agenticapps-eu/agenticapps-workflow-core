# Session Handoff — 2026-07-29 (third session of the day)

## The one thing to know

Both open changes on `feat/step3-hook-shims-and-dead-gate-removal` went through
**three revision rounds this session (4, 5, 6)**. Neither is implemented and
**nothing is committed** — the entire session's output is uncommitted working
tree. `openspec validate --all` is green on both.

The `REVIEWS.md` on disk for both changes is **round 5**, written against the
pre-round-6 text. Under these changes' own proposed rule that evidence is stale.
Round 6 has not been reviewed.

## Accomplished

Round 4 → 5 → 6 revisions of `track-and-conform-plan-review` and
`shim-project-hooks`, each round driven by `run-plan-review.sh` against gemini,
codex and opencode at `REVIEW_TIMEOUT=600 MIN_REVIEWERS=1`.

### Defects found in my own drafts, by review

- **The digest set was stated three ways** (`specs/**/spec.md`,
  `specs/**/*.md`, `specs/*/spec.md`). All three reviewers caught it. Now
  `specs/**/*.md` everywhere — the glob `openspec status` already reports for
  the spec artifact, so it adopts the tool's definition instead of a fourth.
- **The trailer repeated the exact defect the change exists to fix** — specified
  as "a trailer the gate can parse" while the digest was specified to the byte.
  Now an HTML-comment block with named fields, duplicate-key and ordering rules.
- **"Fail open with a loud warning" had no warning.** On exit 0 a PreToolUse
  hook's stderr is discarded from the transcript. Verified against the host
  docs. Fixed by exiting **1** — non-blocking, and the transcript shows the
  first stderr line. This would have shipped silent protection loss.
- **An unsafe assumption withdrawn**: that a `tasks.md` edit meaningful enough
  to matter must also alter a bound artifact. gemini's counter-example ("add a
  debug endpoint") contradicts nothing in a proposal. Now stated as a real gap
  with an optional `tasks-digest` drift warning that does not block.
- Reviewer sections bounded at `##`, not "any heading" — a vendor writing
  `### Findings` would have had its verdict discarded and been recorded as
  producing none.
- Rollback was unexecutable: `install-shared-artifact.sh:148` refuses
  downgrades. Needs an explicit opt-in downgrade path, now a capability
  requirement rather than a task-list aside.

### Verified facts that changed decisions

- `AGENT_SELF:-claude` is in the **producer** (`run-plan-review.sh:68`); the
  gate's `OPENSPEC_GATE_SELF` defaults to **empty** — no self-exclusion at all.
  The previous handoff recorded only the first.
- The producer **never sends `tasks.md`** to reviewers (`:101-102`). This
  dissolved the digest-scope deadlock all three reviewers hit.
- **Six of seven repos** matcher `database-sentinel` as `Bash|Edit|Write`; only
  callbot has `MultiEdit`. That also sizes the fail-closed blast radius: every
  Bash command and every file edit.
- `callbot`'s `database-sentinel:59` blocks every `migrations/` edit on a dead
  GSD sentinel and prints a remedy naming a command removed 2026-07-28.
- `claude-workflow` vendors all eight hooks **twice** plus stale matchers — the
  next scaffold would recreate everything this change deletes.
- **CI already enforces ≥1.** `openspec-gate.ci.yml` runs the gate, which has
  defaulted `MIN_REVIEWERS=1` since 1.4.0. I earlier told the operator the CI
  floor would drop 2→1 and asked which they wanted; that premise was false. The
  `≥2` lines in the workflow are stale comments.

## Decisions

- **Rejections stay non-blocking**, per §18 and CLAUDE.md. codex asked three
  times. The answer: digest-binding means amending in response to an objection
  stales the review, so the only route past one is to not amend — which the gate
  reports by name on every invocation. That log is the audit trail.
- **The digest covers exactly what is transmitted.** Not `tasks.md` (never
  sent, and binding it deadlocks the gate on ticked checkboxes).
- **Identity moved out of the environment into the artifact.** The producer
  requires it explicitly, records it; the gate reads it from `REVIEWS.md`. This
  is what keeps "not touching the four hosts" true for the gate — and it is
  *not* true of the producer, whose calling convention breaks.
- **Substance required** to count a reviewer — closes the live bare-`APPROVE`.
- **Both shims fail open**, reversing the fail-closed posture. Forced, not
  preferred: matchers select tools, not paths.
- **One floor everywhere** (operator's call) — already the state.
- **`claude-workflow` is in scope** for both changes, for opposite reasons:
  removing a vendored producer copy, and fixing templates/snapshot.

## Files modified

- `openspec/changes/track-and-conform-plan-review/` — proposal, design, tasks,
  both spec deltas, `REVIEWS.md` (round 5)
- `openspec/changes/shim-project-hooks/` — proposal, design, tasks, spec delta,
  `REVIEWS.md` (round 5)
- `session-handoff.md` — this file
- **No implementation code. No commits.**

## Next session: start here

1. **Commit the two revisions first.** Three rounds of work sit uncommitted;
   the branch is `feat/step3-hook-shims-and-dead-gate-removal`.
2. **Run round 6** on both:
   `REVIEW_TIMEOUT=600 MIN_REVIEWERS=1 ~/.agenticapps/bin/run-plan-review.sh <slug> gemini codex opencode`
3. Then implement **`track-and-conform-plan-review` before `shim-project-hooks`**
   — it repairs the machinery everything else is reviewed by, and its task 9b.19
   re-checks this branch under gate 1.5.0.

Convergence signal: gemini has approved `shim-project-hooks` twice running, with
substance both times. opencode called `track` an approve once its material items
were fixed, which they now are. But every round so far has found at least one
real defect, including a design-breaking one in round 5 — so do not skip round 6
on the assumption it has settled.

## Reviewer reliability — check before acting

Roughly one claim in four has been wrong. This session:

- opencode: "`Edit` matchers also match `MultiEdit`" — **false**, the host docs
  say a letters-only matcher is an exact string comparison. Would have voided a
  requirement and six repo edits.
- codex: "codex is the implementing host, so its review is ineligible" —
  **false**, twice (rounds 3 and 4). The implementing host is claude. Now
  recorded in `shim-project-hooks/design.md` so round 7 does not re-litigate it.
- opencode: `gate/README.md:30` states ≥2 — **not found**; lines 5 and 13 do.
- opencode returned **no verdict at all** twice (rounds 2 and 4), and in round 4
  claimed four repos "aren't on this machine" when they are under
  `~/Sourcecode/factiv/`. Both are live evidence for `track`'s own
  verdict-and-substance rule.

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered, unchanged by this session.
- **§02 is written in GSD vocabulary** — the root cause the dead hooks were
  symptoms of, and the substance of plan step 5.
- **`gate/` remains unclassified** apart from `run-plan-review.sh`, which
  `track` deletes. Its README, gate copy, `pre-commit` and `hooks/` still need a
  keep/track/delete call, as do the other untracked items at repo root.
- **Does `MultiEdit` still exist as a host tool?** Absent from the current tool
  reference and from this session's toolset. If gone, the six-repo matcher edit
  is harmless but inert — verify before reporting it as protection gained.
- **`screen-review-egress`** — deferred secret/PII screening, named and owned in
  `track`'s proposal, not yet a change.
- Vendor CLIs can **write and execute**, not only read. Declared, not mitigated;
  a read-only sandbox is not attempted.
