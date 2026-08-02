# Session Handoff — 2026-08-02 (evening)

## Accomplished

Implemented `shim-project-hooks` from **0 → 67 of 114 tasks** on branch
`feat/shim-project-hooks` (6 commits, unpushed). PR #60 was already merged, so
the handoff's "merge #60" step was done before this session started.

**All core-side work is complete and verified. 106 assertions green across four
suites.** What remains is the multi-repo rollout.

- **§1 canonical implementations** — `reference-implementations/project-hooks/`
  with both hooks, a README carrying the shim contract, and a per-difference
  reconciliation record. `tools/project-hooks.test.sh` 30/30.
- **§2 the shim** — `shim-template.sh`, fail-open-and-report, two candidates, no
  `<repo>/bin/`. RED→GREEN pair committed. `project-hook-shim.test.sh` 21/21.
- **§2 conformance scan** — `tools/project-hook-conformance.sh`, marker states
  plus five override vectors. `project-hook-conformance.test.sh` 21/21.
- **§3 publication** — `install-project-hooks.sh` + `tools/provisioning-check.sh`,
  manifest, two-axis provisioning state. `project-hook-provisioning.test.sh` 45/45.
  **Published for real on this machine**; check reports complete + attested.
- **§5.0 deletion record** — `DELETION-RECORD.md`, three clauses per hook against
  §02/§17/§18 and every capability spec. This gates the §4 deletions.

## Decisions

- **`flock` (task 3.2b-ii) is not implemented as named** — your call. `flock(1)`
  does not exist on macOS 26.6. The property it protects, "a lock that does not
  outlive its holder", is implemented with atomic `mkdir` + owning pid + dead-owner
  breaker, matching `install-shared-artifact.sh`. Deviation recorded in the script;
  the suite tests the behaviour, not the primitive.
- **Cross-family rollout approved** — your call. All seven repos including the
  four in `factiv/`.
- **The expected artifact set is declared, not discovered** — `ARTIFACTS`. Both
  tools derived it from what they found, which cannot detect a missing artifact.

## Four corrections to the change's own artifacts

1. **The `migrations/` clause is in all seven copies and live in six**, not
   `callbot` alone. Only `cparx` holds the sentinel. `proposal.md` corrected.
2. **`session-bootstrap` is NOT the only reader of `skill-router-*.jsonl`** —
   `agenticapps-dashboard`'s `readSkillObservations()` globs `*.jsonl`. The
   conclusion survives for a *different* reason: `HookFiringSchema` requires a
   `hook` field the producer never writes, so those records are discarded.
3. **Two `claude-workflow` files were in no task** — `bin/check-hooks.sh` and
   `templates/claude-settings.json`. Added as 4c.7, 4c.8.
4. `design-shotgun-gate` re-argued on unreachability (5.0a-i), as the plan required.

## Files modified

- `reference-implementations/project-hooks/` — new: 2 implementations, shim
  template, `ARTIFACTS`, README
- `reference-implementations/shared-install/install-project-hooks.sh` — new
- `tools/{provisioning-check,project-hook-conformance}.sh` + 4 `*.test.sh` — new
- `openspec/changes/shim-project-hooks/{tasks,proposal}.md`, `DELETION-RECORD.md`

## Next session: start here

**Section 4 — the per-repo rollout**, one repo at a time, verified before the
next. Per repo: replace two copies with shims, delete the five hooks, remove
their `settings.json` entries, add `MultiEdit` to the `database-sentinel`
matcher. Then §4b (the gate shim, with **4b.1a sequenced behind 3.6 — 3.6 is now
done, so `agents-task-viewer` can be verified provisioned before its third
candidate is removed**), then §4c (scaffolder, now 8 tasks not 6).

**Do task 4.8a first.** It is the baseline nothing has measured: does the
existing `Bash|Edit|Write` matcher actually fire today? Every claim that
unprovisioned machines "lose" protection presumes it.

## Open questions

- **2.3a and 4.8a need a FRESH session.** Both require observing a hook fire
  live, and hooks load at session start — a probe registered now does not fire
  now. Until then `normalize-claude-md` is described as failing open with its
  channel *established by documentation, not by observation*. Do not upgrade
  that wording without the observation.
- Branch is **unpushed**; no PR opened. Say the word.
- The convergence rule is still unwritten — third session running.
- Your global `~/.claude/CLAUDE.md` still says commits are blocked until
  `REVIEWS.md` carries ≥2 reviewers. Per `change-gate-enforcement` the gate
  blocks only on validation. Still untouched — it is your instruction file.
