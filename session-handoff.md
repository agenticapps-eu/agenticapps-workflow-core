# Session Handoff — 2026-08-08 (eighteenth session)

**Step 4's code review finally ran, and six of its seven findings are fixed.**
Two commits on `feat/projects-bind-not-copy` (PR #89). Tree clean,
`openspec validate --all` 14/14, 560 tests across 14 suites green.

The open question that had been sitting at the top of the last three handoffs —
"Step 4's code review has still never run" — is closed.

## Accomplished

- **Stage 2 ran** in this cleared session, per §07, with no implementation
  context. Artifact: `openspec/changes/one-enforcement-floor/CODE-REVIEW.md`.
  Verdict pass-with-followups: 1 Critical, 2 Important, 4 Minor, 1 spec drift.
- **All six Important and Minor findings fixed**, RED before GREEN. Recorded as
  §11 of `one-enforcement-floor/tasks.md` and §10 of `fresh-clone-needs-nothing`.
  Suites grew 29→42, 47→50, 53→56.
- **PR #89 retitled and rewritten.** The stale "no code yet" description is gone;
  the C1 warning is now the first section a reviewer sees.
- **Three things cleared as NOT defects** so they are not re-raised: `sort -V`
  works here and the `semver.sh` removal is clean; `install-core-git-hooks.sh`
  will not clobber the published floor hook (its whole-line marker check refuses
  it); the surviving mentions of deleted scripts are prose, not live paths.

## Decisions

- **C1 does not block merging, only running.** `install.sh:346` binds the floor
  unconditionally while §10 and 9.4a are open. Both halves were reproduced end
  to end: `core.hooksPath` displaces `.git/hooks/pre-commit` entirely, and the
  floor dispatcher exits 0 *in silence* when the repository is not enrolled. The
  composition silently ungates every locally-gated repository, core included.
  Merging changes nothing; the first run does. Recovery is
  `git config --global --unset core.hooksPath`.
- **`--host auto` now ADDS to the named set.** It replaced it, and naming a host
  is exactly what you do when detection will not find it — so the one request
  that needed making was the one discarded.
- **`install.sh` stays at exactly 217 executable lines.** Both fixes were
  written long, measured at 229, and compacted. The budget is spec-enforced and
  the suite checks it.
- **The fixes are NOT covered by CODE-REVIEW.md.** §07 forbids the implementer
  authoring Stage 2, and the reviewer wrote them. The artifact says so and names
  four things a second pass should look at.

## Files modified

- `openspec/changes/one-enforcement-floor/CODE-REVIEW.md` — new; the Stage 2 artifact
- `openspec/changes/one-enforcement-floor/tasks.md` — §11 added (install.sh M1, M3)
- `openspec/changes/fresh-clone-needs-nothing/tasks.md` — §10 added (I1, I2, M2, M4)
- `install.sh` — project-hook line keys on its own exit status; `--host auto` adds
- `reference-implementations/openspec-tools/bind-openspec-tools.sh` — `link()`
  returns 0 only for a link that exists; failed `ln` named; `$#` guarded on three
  flags; unreachable `[ -z "$skills" ]` branch removed
- `reference-implementations/init-project/init-project.sh` — CLAUDE.md replaced
  atomically via temp+`mv -f`; `COLLAPSE` flag retired with the `rm` it authorised
- `tools/{install,bind-openspec-tools,init-project}.test.sh` — 16 new cases

## Next session: start here

**Implement `one-enforcement-floor` §10, and 10.2 first** — unchanged from the
last handoff, and now the only thing standing between this branch and a
runnable installer. 10.2 is the ordering constraint: the binder sets core's
local `core.hooksPath` plus `agenticapps.hooksbinding=declared` **before** the
global binding, and does not set the global one if either write fails. Then
10.1 (pre-bind inventory), then 10.3, then 10.4.

After §10, do **9.4a** — nothing in the shipped code sets
`agenticapps.workflow.enrolled` at all, so the floor governs nothing once bound.
That is the other half of C1 and the two are only safe together.

Tests go in `tools/global-floor-bind.test.sh` (18 cases today), per-case `HOME`
**and** per-case git config — 6.8 exists because a test that sets a global
`core.hooksPath` against the real home rebinds the operator's machine.

Measured 2026-08-08 and still true: global `core.hooksPath` **unset**, core's
local **unset**, `agenticapps.workflow.enrolled` **unset**, core's own hook
present. The displacement is latent and fires on the first successful bind.

## Open questions

1. **The six fixes need their own Stage 2** — a small, self-contained delta
   (3 scripts, 2 suites, 16 cases). `CODE-REVIEW.md`'s last section names what
   to look at, including the two-statement `if/else` compacted to fit the budget
   and the `sed 's/ auto / /g'` word surgery.
2. **Local `main` is 32 commits behind `origin/main`.** It made the review
   report 84 commits when the PR is 53. Harmless this time — the stale base made
   the review a superset — but `git fetch` before the next scope measurement.
3. **Eight §9 findings still open** — 9.4a, 9.4b, 9.5, 9.7, 9.8, 9.9, 9.10, 9.12.
4. **Spec drift on `main`, not on this branch**:
   `openspec/specs/project-hook-binding/spec.md` names `normalize-claude-md` as a
   live shim instance in seven places; the implementation is already gone.
   Planned in `diagram-is-the-surface`, which is 0/46.
5. **Three credentials outlived their file.** `agenticapps-roadmap`'s `.env` held
   `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`. Deleting the
   checkout did not revoke them. Operator action, still outstanding.
6. **`claude-workflow` cannot be deleted safely yet.** 11 commits on no remote,
   `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
7. **The fleet trim** is still task 4.6 of `fleet-carries-only-current`, gated on
   `projects-bind-not-copy` archiving. Lifting it out standalone is still live.
8. **CodeRabbit still has not reviewed anything here.**
