# Session Handoff — 2026-08-02 (afternoon)

## Accomplished

**PR #56 finished the two review tasks it owed (6.5, 6.8) — and they found
eleven real defects between them. Merged (`919f4e9`), then archived via #57
(`84b286e`).** Core now runs the §18 gate against itself on `main`, and
`core-self-enforcement` is durable spec under `openspec/specs/`.

Verified on `main` after both merges: wrapper 10/10, installer 16/16, harness
71/71, `openspec validate --all` 5/5. `shim-project-hooks` is the only open
change.

**Task 6.5 — §07 Stage-2 code review.** Run in fresh vendor-CLI processes via
`reviewer-cli.sh`, `claude` excluded as implementing host. Recorded in
`openspec/changes/core-gates-itself/CODE-REVIEW.md` (new artifact; there was no
prior convention — `REVIEWS.md` is producer-owned and must not be hand-edited).
gemini `pass-with-followups`; codex **`block`, 7 findings**. All reproduced and
fixed. Four had the installer write where it must not or destroy what it did not
own, each exiting 0 and printing success. Two silently ungated edits. One
re-exported `OPENSPEC_GATE_SELF`, which the gate has ignored since 1.5.0 — and
whose header names documenting it as live as the hazard. Core published that
warning and this branch reintroduced it.

**Task 6.8 — plan review, round 2.** gemini / codex / opencode, **all three
REQUEST-CHANGES**. Two more reproducible bugs, both fixed.

**CodeRabbit** also ran a real review (not a rate-limited green) and found three
genuine issues, two of which were cases where this change's own delta was
already stricter than its implementation.

### The through-line

The containment guard in `tools/install-core-git-hooks.sh` was wrong **three
times**, each time answering a question adjacent to the one being asked:

1. tracking status instead of path containment (CodeRabbit, earlier session)
2. couldn't resolve a path that doesn't exist yet (gemini + codex)
3. compared an unnormalised path, so `..` re-entering the tree read as outside
   (codex) — the first pointing outward-and-back rather than inward

And CI was green at 71/71 through all of it, because the harness scores the
artifact core *publishes* and never executed the code core *runs*.

## Decisions

- **Two test suites added and wired into CI** —
  `tools/test-install-core-git-hooks.sh` (16) and
  `tools/test-claude-hook-wrapper.sh` (10). Every case is a regression test for
  a defect actually reproduced. **Both verified to fail against the pre-fix
  code**; a suite that passes against the bug it names is decoration. This
  caught two of my own decorative tests.
- **`MIN_ROW_CALLSITES=57`** — a second floor counted from the harness *source*.
  The existing `MIN_SCORED_ROWS` is scraped from the harness's own stdout, so a
  stub printing a passing TOTAL satisfied it. Neither floor bounds row
  *correctness*; the delta now says so instead of claiming otherwise.
- **`CLAUDE_PROJECT_DIR` is no longer consulted** by the wrapper. Its own
  location is authoritative by construction, so the variable could only agree or
  be wrong — and when wrong it silently ungated.
- **Unresolvable root fails CLOSED**; genuinely absent tooling still fails open.
- **§18 attribution corrected** — §18 names only `PreToolUse`. The `pre-commit`
  hook and CI job are core's own additions, not §18 obligations.
- **Declined, with reasons recorded in task 6.14**: deriving the row floor from
  the harness (destroys its purpose), `--force` on stale-hook upgrade (makes the
  gate unadvanceable), local fail-open on a missing `openspec` CLI (sound
  ergonomics, but it lives in the gate every host consumes — worth raising
  against the gate itself as a follow-up).

## Files modified

- `.claude/hooks/openspec-change-gate.sh` — root from own location; fail-closed
  on unresolvable root; dead export removed
- `.claude/settings.json` — command quoted (a path with a space exited 127,
  which is not 2, so the edit proceeded)
- `tools/install-core-git-hooks.sh` — normalising `canon()`, symlink refusal,
  whole-line marker, atomic write
- `tools/test-install-core-git-hooks.sh`, `tools/test-claude-hook-wrapper.sh` — new
- `.github/workflows/openspec-gate.yml` — both suites + the source floor
- `openspec/changes/core-gates-itself/` — CODE-REVIEW.md (new), spec delta,
  tasks 6.5/6.8–6.14, proposal Impact
- `docs/WORKFLOW.md` — resolution, fail-closed rule, suites

## Next session: start here

**Do `shim-project-hooks`** (88 tasks, 0 done) — the only open change. #56 and
#57 are both merged, so core's `.claude/hooks/` now exists on `main` and the
reconciliation below is against settled ground rather than a moving branch.

**Reconcile `shim-project-hooks`'s premise first — #56 invalidates part of it.**
Its proposal asserts in three places (lines ~22, ~182, ~329) that core has **no
`.claude/hooks/` at all**. That is now false. Checked this session: the
*conclusion* those lines support still holds — they are used to attribute core's
`.planning/` writes to the global `meta-observer` SessionEnd hook rather than to
`skill-router-log.sh`, and core's new hook is a `PreToolUse` gate that writes
nothing there. So the fix is narrow: reword to "core carries no
`.planning`-writing project hook". The 137-of-141 measurement survives intact.

For section 4b, core's own shim is **not** a migration target for 4b.1 or 4b.3 —
it has no `<repo>/bin/` candidate and makes no `>= 2 reviewers` claim, by
construction (ADR-0028 inverts its resolution deliberately). **4b.6 does apply**:
core's shim carries no contract version marker.

**Then re-run its plan review.** Its two REQUEST-CHANGES verdicts date from
2026-07-30, before round 7 rewrote the text they object to.

    REVIEW_TIMEOUT=900 bash ~/.agenticapps/bin/run-plan-review.sh shim-project-hooks --implementing-host claude

## Open questions

- **Run the plan review LAST, after every artifact edit has settled.** Three runs
  were wasted this session: one refused to publish because artifacts changed
  mid-run (correctly — it will not bind stale evidence), one I stopped
  deliberately rather than let it publish something CodeRabbit's fixes would
  immediately invalidate, one was killed. Detached `nohup` survived; the tool
  background task did not.
- **The staleness regress is inherent.** Fixes made in response to a review leave
  that review stale, and reviewing again produces more revisions. The stopping
  rule applied here was *no further reproducible defect*, not *a round returned
  APPROVE*. Worth stating in the workflow docs — it is not obvious and the gate's
  NOTE invites the opposite reading.
- **Follow-up against the gate itself**: gemini's argument that a missing
  `openspec` CLI should warn-and-allow locally while CI fails closed is sound.
  Out of scope here because that file is consumed by every host.
- **Core's published CI template** still carries the supply-chain weaknesses
  fixed in core's own copy (unpinned `npm i -g`, no permissions block, persisted
  credentials). No host pins it, so it is safely fixable.
- **Manifests disagree**: claude-workflow pins seven files, the other three pin
  five. Any "all seven" claim is wrong for three of four hosts.
- **Hosts still cite core spec 1.4.0**; core is at 1.5.0. Documentary only.
- **Five family repos have no workflow at all**: agenticapps-observability,
  agentlinter, open-design, dotclaude, agenticapps-shared.
- **A concurrent session may still be live in `agenticapps-dashboard`** (branch
  `feat/repo-readiness-vocabulary`, never pushed). Do not touch that checkout.
