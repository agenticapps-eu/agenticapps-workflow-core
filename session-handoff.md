# Session Handoff — 2026-08-02 (evening)

## Accomplished

**Two branches pushed, neither merged.**

- **PR #59 `fix/wrapper-forwards-arguments`** — green (gate pass, CodeRabbit
  pass). Ready to merge.
- **`chore/shim-project-hooks-reconcile`** — pushed, no PR. Artifact
  reconciliation + plan review round 8. Left open because the artifacts will
  keep moving; open a PR when the objections below are settled.

### The wrapper discarded its arguments (PR #59)

`.claude/hooks/openspec-change-gate.sh` ended in `exec "$GATE"` — no `"$@"`. So
`bash .claude/hooks/openspec-change-gate.sh --ci` exited **0, silently, having
checked nothing**. The flag never reached the gate; it ran as a PreToolUse hook
with no stdin payload and allowed.

Latent, not live: CI invokes the reference implementation directly, pre-commit
resolves the gate itself, and PreToolUse passes no arguments. Nothing was
mis-gated. What was broken is the one invocation a person reaches for to ask
core whether it is compliant — from the file whose entire purpose is making
core's non-compliance visible. Same class as #56's "harness scores an artifact
it never runs".

Fixed TDD: `test(RED)` `ad4c1eb` verified failing (10 passed, 1 failed), then
`fix(GREEN)` `5e06e4f`. The test asserts on **what the gate received**, not exit
status — both wrappers exit 0, so an exit-code assertion would have passed
against the bug, which is the trap this suite already documents for the
cwd-derived-root case.

Evidence: wrapper 11/11, installer 16/16, harness 71/71, validate 5/5.

### shim-project-hooks reconciliation

Re-measured the fleet. **`agenticapps-dashboard` carries seven hooks, not
eight** — it deleted `design-shotgun-gate.sh` itself on 2026-08-01 (its PR #88,
"it blocks every fresh clone"). This change's argument, made independently, by
the one repo that acted on it. `claude-workflow` still vendors the file twice.

Three premises corrected:

1. "Core has no `.claude/hooks/` at all" (3 sites) → carries no
   `.planning`-**writing** project hook. The 137-of-141 meta-observer
   attribution survives; only its supporting sentence moved.
2. **"No host carries a `.claude/hooks/` directory of its own" was never true**
   of `agenticapps-dashboard` — it is one of the four hosts *and* one of the
   seven hook-carrying projects. The handoff flagged line ~182 as a core-hooks
   site; the actual defect there was larger and about the dashboard.
3. "Six projects receive the `normalize-claude-md` fix" → **five**. Dashboard
   authored it; `agents-task-viewer` is shipped no file. This was codex's
   round-7 objection #6, still unaddressed.

**Verified intact, not assumed:** the drift claim (exactly four hooks in 2–3
versions; the shimmed gate has 1 across all seven) and the `MultiEdit` matcher
claim (callbot alone has it; six register `Bash|Edit|Write`).

### Plan review round 8 — gemini APPROVE, codex + opencode REQUEST-CHANGES

Two findings answered, **eleven open**.

- opencode caught an error **I introduced** in this session's first draft:
  138 × 7, two sentences after enumerating why the projects are not uniform.
  Line figures are now marked as estimates — the shims do not exist yet.
- opencode's matcher objection is **refuted with evidence**: it read
  `Bash\|Edit\|Write` from the design table and inferred an inert control. Those
  backslashes are our own markdown escaping; the JSON has real pipes in all
  seven. Residue stands though — a well-formed matcher is not a firing hook —
  so task **4.8a** now requires establishing the baseline before any claim that
  protection is "lost".

## Decisions

- **The wrapper fix was kept out of `shim-project-hooks`.** Touching its
  `tasks.md` would have invalidated the plan review running at the time. It
  belongs to `core-self-enforcement`, which is archived.
- **Plan review started before the wrapper work, not after** — artifacts had
  settled, and last session's rule is that the review runs last relative to
  *artifact* edits. Code edits outside the change dir do not disturb its digests.
- **My own arithmetic error was fixed rather than deferred.** It is a
  reproducible defect and it was mine.

## Files modified

- `.claude/hooks/openspec-change-gate.sh` — `exec "$GATE" "$@"` (PR #59)
- `tools/test-claude-hook-wrapper.sh` — argument-forwarding regression, 11th
  case (PR #59)
- `openspec/changes/shim-project-hooks/{proposal,design,tasks}.md`,
  `specs/project-hook-binding/spec.md` — reconciliation; `REVIEWS.md` — round 8

## Next session: start here

**Merge PR #59 first** — it is green and independent of everything else.

Then work the **eleven open review objections** on `shim-project-hooks`
(`REVIEWS.md`, round 8). Start with the two that are contradictions inside the
change's own text, because they are cheapest and both are self-inflicted:
opencode's **`MultiEdit` Impact bullet** (the Impact section claims a delivered
protection that the change's own delta forbids reporting, since the tool is
absent from the host's tool set) and its **`PostToolUse` warning-channel**
finding (the delta mandates verifying the channel for non-`PreToolUse` events
before writing the shim; `normalize-claude-md` is `PostToolUse` and only
`PreToolUse` is recorded). Both are the change violating a rule it writes.

Then codex's **shim-contract contradiction**: the universal contract mandates
shared-install resolution and byte-identical shims, while core deliberately
resolves its working tree. Task 4b.10 records the applicability split; the
*delta* still needs a normative exception or a separate profile.

Still **0/88 tasks**. No code has been written for this change.

## Open questions

- **The staleness regress is now demonstrated, not theorised.** Round 8 found an
  error introduced by the very edit that answered round 7. The stopping rule
  remains *no further reproducible defect*, not *a round returned APPROVE* —
  worth writing into `docs/WORKFLOW.md`, still not done.
- **CodeRabbit passed PR #59 in 0s.** Possibly a real green on a two-file diff,
  possibly rate-limited. Last session saw both.
- Carried forward, all still open: core's published CI template retains the
  supply-chain weaknesses fixed in core's own copy; manifests disagree
  (claude-workflow pins seven files, the other three pin five); hosts still cite
  core spec 1.4.0 against core's 1.5.0; five family repos have no workflow
  (agenticapps-observability, agentlinter, open-design, dotclaude,
  agenticapps-shared); gemini's argument that a missing `openspec` CLI should
  warn-and-allow locally while CI fails closed is sound and unfiled.
- **`agenticapps-dashboard` is on `main`, not the `feat/repo-readiness-vocabulary`
  branch the last handoff warned about.** That checkout looks free now; its #88
  is merged. Only read it, though, until someone confirms.
