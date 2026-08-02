# Session Handoff — 2026-08-02 (late)

## Accomplished

- **PR #59 merged** (`c334d05`, squash). The change-gate wrapper now forwards
  `"$@"`, so `--ci` is no longer a silent green.
- **PR #60 opened** — `chore/shim-project-hooks-reconcile`, rebased onto main.
  Review rounds **8 (11 objections) and 9 (12 objections)** answered across all
  four artifacts. `openspec validate --all` green, 5/5. **112 tasks, 0 done.**

### Three claims verified on disk rather than trusted

1. **`agents-task-viewer` ships an executable `bin/openspec-change-gate.sh`;
   the other six do not.** Task 4b.1 strips that resolution candidate, so in
   that one repo it takes an unprovisioned machine from *enforced validation*
   to fail-open. "Not a regression" was true of six repos and asserted of
   seven. Decision taken: keep the rule uniform, sequence 4b.1 behind the
   per-machine check for that binder (task 4b.1a).
2. **`.planning/skill-observations/` holds 29 files, all 29
   `<stamp>--<sessionId>`, zero `skill-router-*`.** The recorded 141/137/4 is
   not reproducible — gitignored per-machine state. Restated as dated
   single-machine observation in all four sites. The conclusion *strengthens*:
   the non-hook producer is now 29 of 29.
3. **Refuted:** opencode's claim that Decision 9's table mis-describes core's
   hook. It describes the seven *project* shims — `agents-task-viewer`,
   `cparx`, `callbot` each still carry four `<repo>/bin/` refs and an
   `OPENSPEC_GATE_SELF` export. Residue was real: the decision named no path
   and core has a same-named file since 2026-08-02. Path now stated.

### The corrections that changed the plan

- **§18 framing was stale.** Per `change-gate-enforcement` + ADR-0027 the gate
  blocks only on `openspec validate --all`; reviews are reported, never
  enforced. Four sites called a missing gate a lost "review requirement".
- **Two shim profiles** — `published-resolution` / `self-hosting`. The split
  existed only in task 4b.10 while the delta read as universal.
- **Provisioning is two axes** (completeness × integrity), because the flat
  four-state list was not mutually exclusive.
- **Deletion clause 3 broadened to enforcement by any means** — which reverses
  the argument for deleting `design-shotgun-gate`: a sentinel is a proxy, so
  the old argument convicts it. Re-argued on **unreachability** (task 5.0a-i).
- Shared dir ownership/permission/symlink rules; `flock` named; implementation
  version marker defined; invalid-override report carved out of rate limiting.

## Decisions

- **Round 10 deliberately not run** — your call. Four of round 9's twelve were
  introduced by round 8's fixes; two consecutive rounds show each fix pass
  seeds the next round's findings. Recorded as open risk in the PR body.
- **`agents-task-viewer`: provision first, then strip** — your call. Keeps one
  rule, closes the enforcement window by ordering rather than by exception.
- Review digest on `REVIEWS.md` is **stale by construction** — answering a
  review edits the artifacts it reviewed. The gate reports, does not block.

## Files modified

- `openspec/changes/shim-project-hooks/{proposal,design,tasks}.md` and
  `specs/project-hook-binding/spec.md` — rounds 8 + 9
- `openspec/changes/shim-project-hooks/REVIEWS.md` — round 9 (producer-written)

## Next session: start here

**Merge PR #60** — it is green and clean (`gate` SUCCESS, CodeRabbit SUCCESS,
`mergeStateStatus: CLEAN`), left unmerged only because the session's authority
extended to opening it, not merging it. Then the change is ready to
*implement* — 112 tasks, starting at task 1.1, and note the ordering
constraint: 4b.1a is sequenced behind 3.6, so the per-machine provisioning
check must exist before `agents-task-viewer`'s third candidate is removed.

## Open questions

- **The convergence rule is still unwritten**, now for the third session. The
  stopping rule "no further reproducible defect" is not met and rounds 8 and 9
  both demonstrated the regress. This is the thing to write into
  `docs/WORKFLOW.md` before the next change runs a plan review.
- **Your global `~/.claude/CLAUDE.md` is stale**: it says commits are blocked
  until `REVIEWS.md` carries ≥2 other-vendor reviewers. Per
  `change-gate-enforcement` the gate blocks only on validation. Same defect I
  just corrected inside the change; untouched because it is your instruction
  file.
- Carried forward, all still open: core's published CI template retains the
  supply-chain weaknesses fixed in core's own copy; manifests disagree
  (claude-workflow pins seven files, the other three pin five); hosts still
  cite core spec 1.4.0 against core's 1.5.0; five family repos have no
  workflow; gemini's argument that a missing `openspec` CLI should
  warn-and-allow locally while CI fails closed is sound and unfiled.
