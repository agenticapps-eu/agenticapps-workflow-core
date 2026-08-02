# Session Handoff — 2026-08-02 (night)

## Accomplished

`shim-project-hooks` implemented **0 → 113 of 114 tasks**. Only **5.8, the
Stage-2 independent code review, is open** — it requires an independent context
by §07, so it is not mine to close.

Nine repos changed, all on unpushed branches. Core: `feat/shim-project-hooks`
(13 commits). The other eight: `chore/shim-project-hooks`.

- **Core** — `reference-implementations/project-hooks/` (2 implementations, shim
  template, gate shim, `ARTIFACTS`, README), `install-project-hooks.sh`,
  `tools/{provisioning-check,project-hook-conformance}.sh`, four test suites
  (**119 assertions, all green**), `DELETION-RECORD.md`, ADR-0029.
- **The seven projects** — 8 hooks → 3 (2 in `agents-task-viewer`), all
  byte-identical. 5 deleted, 2 shimmed, gate shim migrated.
- **`claude-workflow`** — both vendored hook dirs, both settings templates,
  `bin/check-hooks.sh`, `migrations/check-snapshot-parity.sh`, 3 bats files.

**Green:** parity PASS · `check-hooks` 15/0 · gate conformance 71/71 ·
`openspec validate --all` 5/5 · gate `--ci` OK.

## Decisions (yours)

- **`flock` not implemented as named** — absent on macOS 26.6. The property
  (a lock that does not outlive its holder) is implemented with atomic `mkdir` +
  dead-pid breaker; the deviation is recorded in the script.
- **Cross-family rollout approved** — all seven repos including `factiv/`.

## Six corrections to the change's own artifacts

1. The `migrations/` block was in **all seven** copies, live in **six** — not
   `callbot` alone.
2. **`session-bootstrap` is not the only reader** of `skill-router-*.jsonl`;
   the dashboard globs `*.jsonl`. Conclusion survives for a different reason —
   its schema requires a `hook` field the producer never writes.
3. Three un-tasked `claude-workflow` sites: `bin/check-hooks.sh`,
   `templates/claude-settings.json`, `migrations/check-snapshot-parity.sh`
   (which *required* `phase-sentinel` — the guard demanded the drift).
4. **The shims dropped argv**, which would have made `normalize-claude-md` a
   silent no-op fleet-wide. PR #59's defect, one file over.
5. **4b.7's residual is discharged, not carried** — `OPENSPEC_GATE_SELF` has
   been ignored since gate 1.5.0 and the companion change archived 2026-08-01,
   so 4b.4's "leave it alone" premise had expired. Three of three violations
   fixed, not two.
6. **5.5 measured: −1,877 net, not −3,090.** Estimate assumed a 13-line shim.
   Executable logic per project still falls 351 → 102 (−71%).

## Next session: start here

**Task 5.8 — Stage-2 independent code review**, then push and open nine PRs.
Nothing is pushed. Run `/code-review` or CodeRabbit against
`feat/shim-project-hooks` in core first; the other eight are mechanical
propagation of files core owns.

## Open questions

- **The fail-open reporting channel is UNVERIFIED and the evidence is
  negative.** A live headless probe confirmed the shims run and allow, but the
  exit-1 report reached neither the agent nor `stream-json`, while an exit-2
  block did. The one check that settles it: on a machine with
  `~/.agenticapps/bin/database-sentinel.sh` absent, edit any file in one of the
  seven repos interactively and look for a `hook error` notice. **If nothing
  appears, reopen the fail-open trade — it is a design problem, not a doc nit.**
- **Every other machine is now unprovisioned** until it runs
  `install-project-hooks.sh`. Protection travels with the machine, not the repo.
- The convergence rule is still unwritten — fourth session.
- Your global `~/.claude/CLAUDE.md` still says commits block on ≥2 reviewers;
  the gate blocks only on validation. Untouched — it is your file.
