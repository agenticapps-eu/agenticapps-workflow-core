# Session Handoff — 2026-08-02 (night)

## Next session: run the §07 Stage-2 independent code review

That is task **5.8**, the only open task of 114. This handoff exists to point you
at the work, not to tell you what to think of it.

> **Read the diff, not this file.** Everything below the scope section is the
> *author's* account of their own change. It names what was done and why the
> author believed it was right, which is exactly the reasoning an independent
> review is supposed to form on its own. If you find yourself agreeing with a
> decision because this document explained it, you have not reviewed it.

### Scope

Nine open PRs, none merged. **Review `agenticapps-workflow-core` PR #61.** The
other eight are propagation of files core owns — check they match core and that
each repo's `settings.json` agrees with its `.claude/hooks/` contents, then move
on.

```
core          https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/61
scaffolder    https://github.com/agenticapps-eu/claude-workflow/pull/112
dashboard 91 · roadmap 11 · agents-task-viewer 16 · callbot 98
cparx 119 · fbc-platform 103 · fx-signal-agent 118
```

Local branch: `feat/shim-project-hooks` (15 commits, pushed).

### What to review it against

- `openspec/changes/shim-project-hooks/specs/project-hook-binding/spec.md` — the
  delta this change is supposed to satisfy. **This is the contract; the code
  either meets it or does not.**
- `reference-implementations/project-hooks/README.md` — the shim contract as
  built. Where it and the delta disagree, the delta wins.
- `proposal.md`, `design.md`, `tasks.md`, `DELETION-RECORD.md` — same change dir.
- spec §02, §07, §17, §18 under `spec/`.

### Worth pointing a reviewer at, without saying what to conclude

- The shims are `exec` wrappers on a broad matcher (`Bash|Edit|Write|MultiEdit`).
  Blast radius and failure posture are the load-bearing questions.
- `install-project-hooks.sh` writes a manifest and takes a lock. Crash and
  concurrency behaviour are asserted in
  `tools/project-hook-provisioning.test.sh` — check the assertions actually
  pin what they claim.
- Five hooks were deleted. `DELETION-RECORD.md` argues each one; the argument is
  the thing to audit, not the outcome.
- Two test suites were *moved* rather than deleted
  (`tools/normalize-claude-md.test.sh`). Check nothing was lost in the move.

### Known-open, so you do not spend time rediscovering it

- **The fail-open report's channel is unverified and the evidence is negative.**
  A live probe confirmed the shims run and allow, but the exit-1 report reached
  neither the agent nor `stream-json`, while an exit-2 block did. See the README
  section "The empirical leg (task 2.3a)".
- `fx-signal-agent` PR #118 has two red checks, `pnpm-audit` and `gitleaks`,
  both already red on `main` since 2026-07-28.
- Merging was attempted and **blocked by the permission classifier**. Nothing is
  merged. `gh pr merge --squash --delete-branch` per repo when authorised.

---

## Author's account — read AFTER forming your own view

### What was built

113/114 tasks. Nine repos. The seven projects went from eight vendored
`.claude/hooks/` scripts each to three (two in `agents-task-viewer`, documented
opt-out), byte-identical everywhere. Executable hook logic per project fell
351 → 102 lines; fleet total 4,396 → 1,944, net −1,877 after +575 to core.

Core gained the two implementations, the shim template, the migrated gate shim,
`install-project-hooks.sh`, `provisioning-check.sh`,
`project-hook-conformance.sh`, five test suites (**128 assertions green**),
`DELETION-RECORD.md` and ADR-0029.

Green: `openspec validate --all` 5/5 · gate `--ci` OK · gate conformance 71/71 ·
`check-snapshot-parity.sh` PASS · `migrations/run-tests.sh` 206 pass.

### Decisions taken by the human, not by the author

- `flock` (task 3.2b-ii) not implemented as named — absent on macOS 26.6. The
  property it protects is implemented with atomic `mkdir` + dead-pid breaker.
- Cross-family rollout approved, all seven repos including `factiv/`.

### Places execution contradicted the plan

1. The `migrations/` block was in **all seven** copies and live in **six**, not
   `callbot` alone.
2. `session-bootstrap` is **not** the only reader of `skill-router-*.jsonl`; the
   dashboard globs `*.jsonl`. The conclusion survived for a different reason —
   its schema requires a `hook` field the producer never writes.
3. Three un-tasked `claude-workflow` sites, one of which
   (`check-snapshot-parity.sh`) *required* `phase-sentinel` — the drift guard
   demanding the drift.
4. **The shims dropped `argv`**, which would have made `normalize-claude-md` a
   silent no-op fleet-wide. PR #59's defect one file over.
5. **4b.7's residual is discharged, not carried** — `OPENSPEC_GATE_SELF` ignored
   since gate 1.5.0, companion change archived 2026-08-01.
6. 5.5 measured **−1,877**, not the estimated −3,090.

### Two regressions the author caused and CI caught

- **`agents-task-viewer`'s build broke.** Its `bin/openspec-gate-ci.sh` requires
  a vendored gate and fails closed. That file had two consumers — the shim's
  third candidate and CI — and the task list conflated them. File restored,
  shim candidate still removed.
- **`claude-workflow`'s CI was green on main and the author broke it.** Its
  migration suite drove `normalize-claude-md` goldens against the new shim.
  Corpus moved to core; `phase-sentinel` tests removed with the hook.

## Also done this session

`~/.claude/CLAUDE.md` corrected: the §18 gate blocks on validation only, and
review evidence is reported, never enforced.

## Open questions

- **`agenticapps-dashboard` needs untangling.** Another session was working there
  concurrently; creating `chore/shim-project-hooks` moved its HEAD, and that
  session's two commits (18:36, 18:37, the `close-readiness-spec-gaps` Stage-2
  triage) landed on that branch. `feat/close-readiness-spec-gaps` still points at
  `c6bce4f`. PR #91 was cherry-picked clean via a worktree, so it is unaffected —
  but that branch needs sorting before that change ships.
- The convergence rule is still unwritten — fourth session.
- Every machine is unprovisioned until it runs `install-project-hooks.sh`.
