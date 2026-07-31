# Session Handoff — 2026-07-30

## The one thing to know

**Gate 1.5.0 was published early, blocked six repos, and has been rolled back.**
Task 8b.1 (fleet inventory) was run *after* publication instead of before, and
found **37 active changes across six repos carrying no trailer** — all blocked
at `PreToolUse` until the rollback. The shared gate is back at **1.4.0**,
byte-identical, with an audit record in `~/.agenticapps/install.log`. The
tracked 1.5.0 is unaffected.

**Do not re-publish gate 1.5.0 until task 8b.4 completes** (re-review, or
explicitly accept-and-record, every one of those 37 changes). That is task 8b.6,
added so the precondition cannot be skipped twice.

## Everything else

`track-and-conform-plan-review` is **implemented and committed** — 14 commits on
`feat/step3-hook-shims-and-dead-gate-removal`. Three artifacts published to
`~/.agenticapps/bin/`; spec at **1.3.0**. All four conformance harnesses green.

**The gate is live at 1.5.0 and currently blocks this repo**, because the last
round of corrections staled `track`'s evidence. A final re-review was running at
session end. That is the mechanism working on its own change, not a breakage —
but it is where the next session starts.

## Accomplished

| Artifact | Was | Now | Harness |
|---|---|---|---|
| `spec_version` | 1.2.0, §18 self-contradictory | **1.3.0** | — |
| `run-plan-review.sh` | 1.0.0, untracked | **1.1.0**, tracked + published | 55/55 |
| `openspec-change-gate.sh` | 1.4.0 | **1.5.0**, published | 66/66 |
| `reviewer-cli.sh` | 1.1.0 | **1.2.0**, published | 19/19 |
| `install-shared-artifact.sh` | no rollback path | `--allow-downgrade` | 20/20 |

Also: `gate/run-plan-review.sh` (66-line ancestor) deleted, preserved first under
the change's `evidence/`; ADR-0025 written; a new producer harness created
(`tools/run-plan-review-conformance.sh`).

## Five defects found by BUILDING, not reviewing

Each verified against running code before being fixed.

1. **`MIN_REVIEWERS=0` destroyed evidence.** The guard rejected non-integers and
   negatives but passed `0`; with every reviewer failing, `0 -lt 0` is false, so
   the producer overwrote `REVIEWS.md` with a **zero-byte file** and exited 0.
2. **Line-based digest enumeration dropped newline-bearing paths.** I specified
   length-framing precisely so a path could not forge a record boundary, then
   lost the boundary during enumeration. Now NUL-delimited end to end.
3. **My own spec text would have locked `pi` out of the fleet.** Hosts and
   reviewer vendors are different sets — `pi` is a host with no reviewer arm.
   Validating the implementing host against the *reviewer* set makes every
   pi-authored change permanently unreviewable. **Six review rounds across three
   vendors missed this**; the harness caught it on the first run seeding `pi`.
4. **Fence-blind guards rejected the most engaged reviews.** Quoting the trailer
   grammar in a fenced block — the natural way — got the whole review rejected.
   Exactly the failure round 6 established the principle for; I fixed the inline
   case and stopped.
5. **Stub harnesses cannot verify vendor integration.** The stdin conversion
   scored green on all four stubbed arms while two were broken against real
   CLIs: `opencode`'s `--file` is an array option that ate the message
   positional; `gemini` refused because the *hint wording* told an agentic CLI
   to go open something called "stdin". Every arm is now smoke-tested live.

## Decisions

- **Scope: fix the 8 round-6 defects + accept reviewer feature requests**
  (operator's call). Requests accepted **with limits stated** rather than
  wholesale — provenance is bounded as *drift detection, not tamper-proofing*;
  consumer sandboxing was **declined** as unenforceable and untestable.
- **Migration order is load-bearing and was followed**: spec → producer →
  re-review → gate → wrapper. Publishing the gate first blocks every change in
  every project at once.
- **The log write gates the downgrade**, not the reverse: a failed audit record
  must not leave a silently downgraded shared binary.
- **Supporting evidence in the change dir never reaches reviewers** — the digest
  set is exactly what is transmitted. Accepted, not fixed; findings are now
  stated inline where relied on.

## Files modified

- `spec/00,02,17,18`, `CHANGELOG.md` — floor repair, counting terms, 1.3.0
- `reference-implementations/run-plan-review/` — new, tracked
- `reference-implementations/{openspec-change-gate,reviewer-cli,shared-install}/`
- `tools/{run-plan-review,change-gate,reviewer-cli,shared-install}-conformance.sh`
- `adrs/0025-review-evidence-is-bound-to-what-was-reviewed.md`
- `openspec/changes/track-and-conform-plan-review/` — all artifacts + evidence
- `claude-workflow`: `templates/` and `setup/snapshot/workflow-config.md`
- Deleted: `gate/run-plan-review.sh`

## Next session: start here

1. **Re-review `track`** — the round-9 corrections staled its evidence again.
   `REVIEW_TIMEOUT=900 MIN_REVIEWERS=1 ~/.agenticapps/bin/run-plan-review.sh
   track-and-conform-plan-review --implementing-host claude gemini codex`.
   Under the restored 1.4.0 the repo currently reads green, because 1.4.0 does
   not check digests — that is not the same as the evidence being current.
1b. **Decide the fleet re-review wave (8b.4).** 37 changes across six repos.
   Either re-review them, or record which are accepted as blocked and why. Only
   then re-publish gate 1.5.0 (8b.6).
2. **Task 10.5 — Stage-2 independent code review — is NOT done.** §07 requires
   it in a separate context, and `openspec validate` does not discharge it. I
   did not spawn an agent for it because this session was instructed not to use
   the Agent tool unasked. **This is the one required gate still open.**
3. Then archive (`/opsx:archive`) and ship — two separate acts.
4. `shim-project-hooks` remains planned, not implemented. It is unblocked now
   that the machinery it depends on is real.

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered; codex has now raised it twice as a §16 conflict.
- **`gate/` remains unclassified** apart from the deleted producer — its
  `README.md`, gate copy, `pre-commit` and `hooks/` still need a
  keep/track/delete call, as do the untracked root items (`.planning/`, the
  PDFs, `prompts/`, the `.mmd` diagrams).
- **`screen-review-egress`** — deferred secret/PII screening, still not a change.
  codex argues the standing notice does not satisfy §14's mandatory controls;
  that is a declared gap, not a closed one.
- **The `tasks-digest` drift report is unspecified** (gemini, round 8): it is
  written but nothing defines how the gate surfaces a mismatch.
- **`MultiEdit` does not exist on this host** — the six-repo matcher edit in
  `shim-project-hooks` is forward-compatibility, not protection gained.

## Reviewer reliability — still roughly one claim in four

- **Round 8, codex:** "the substance rule is bypassable by `### Findings` plus a
  verdict" — **false**, tested directly (`SECTION gemini APPROVE 0`). Also cited
  a scenario saying "four known vendors" that does not exist.
- **Round 7, opencode:** every item checked out, including two genuine
  self-contradictions I had shipped.
- **opencode returned no verdict or no output four times** (rounds 2, 4, 6, and
  the 8b re-review) and timed out at 600s in round 8 — continued live evidence
  for the verdict-and-substance rule it was reviewing.
