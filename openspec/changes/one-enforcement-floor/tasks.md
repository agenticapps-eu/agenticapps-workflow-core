# Tasks — one enforcement floor

**No longer blocked.** `core-installer-one-entry-point` was archived on
2026-08-06 and `workflow-installation` is durable truth. This change is first in
the chain and must land before `projects-bind-not-copy`.

## 0. Prerequisites

- [x] 0.1 `core-installer-one-entry-point` is archived and `workflow-installation`
      exists in `openspec/specs/` — confirmed 2026-08-07
- [ ] 0.2 Record the installer's executable line count before any edit. The
      budget is 217 and the canonical counter in `tools/install.test.sh` reports
      **212**, not the 210 an earlier revision claimed — so headroom is 5 lines,
      not 7, and a raise is near certain. The requirement demands the growth be
      itemised, not pre-approved
- [x] 0.3 Record which repositories carry a `pre-commit` and the byte size of
      each. **Done 2026-08-07**, resolving hooks directories with
      `git rev-parse --path-format=absolute --git-path hooks` rather than
      assuming `.git/hooks`: 11 repositories over 10 distinct hooks directories
      (`agenticapps-dashboard-add-agent-board` is a linked worktree sharing the
      dashboard's); nine are the gate at 1201, 1376, 2270 and 5844 bytes; the
      tenth directory is `fbc-platform`'s husky. `cparx` carries none.
      The earlier figures — nine repositories, sizes 883/1201/2270/5844, "no
      husky, no `pre-push`, no `commit-msg`" — were wrong in every clause
- [ ] 0.4 Record the six repositories that set a local `core.hooksPath` and what
      each names, as the before-state for the sweep in section 3

## 1. Inherited, not done here

The host wiring was stripped from `core-installer-one-entry-point` before it
ran, so this change starts from an installer that writes no host configuration.

- [x] 1.1 Wiring removed, `hosts/` deleted, `--accept-host-config` retired —
      landed in the predecessor, with the negative tests that assert the files
      rather than the absence of the functions
- [ ] 1.2 Confirm on the archived predecessor that the claim still holds before
      building on it: no host-named code outside `HOSTS` and `--check` strings

## 2. Publish and bind the global floor

- [ ] 2.1 Publish the gate's `pre-commit` to the machine-level hooks directory
      through the arbitrating installer, with a version marker, exactly as the
      other three executables are published
- [ ] 2.2 Bind it with `git config --global core.hooksPath <dir>`
- [ ] 2.3 Refuse and report a foreign existing `core.hooksPath`; the step counts
      as skipped so the run exits non-zero
- [ ] 2.4 Report an existing binding that is already ours as satisfied, not as
      a no-op and not as a fresh install
- [ ] 2.5 The published hook dispatches to the gate and propagates its exit
      status
- [ ] 2.6 The dispatcher composes with an operator-owned, machine-level
      `hooks.d` alongside the published directory, running each entry and
      failing the commit on the first non-zero exit
- [ ] 2.7 The dispatcher SHALL NOT exec anything resolved from inside a
      repository — not `.git/hooks/`, not a tracked path. A global hook that
      falls back to repository-controlled code makes every clone executable at
      commit time, which is the property `core.hooksPath` exists to remove.
      Assert it as a negative test, not a convention

## 3. Retire the per-repository copies

- [ ] 3.1 Remove the gate `pre-commit` from each of the repositories carrying
      one, having confirmed the global binding is live first
- [ ] 3.2 `tools/install-core-git-hooks.sh` — superseded or retargeted, and
      record which. **This is not open-ended: it resolves its destination with
      `git rev-parse --git-path hooks` (line 54), which honors `core.hooksPath`
      by its own header's admission (line 13).** Once the binding is global,
      running it writes into the machine-level directory — either refusing
      permanently because the published hook carries a foreign marker, or
      colliding markers and publishing core's working-tree-resolving hook to
      every repository on the machine. Both are defects; pick the retarget
- [ ] 3.3 Core's own binding: ADR-0028 has core resolve its *working-tree* gate,
      and `core-self-enforcement` says the shared install "SHALL NOT be
      consulted" — which a machine-level published hook cannot satisfy. Resolve
      explicitly — an ADR if the inversion is being changed, a documented
      local `core.hooksPath` override if it is being kept. **Decided in the
      `core-self-enforcement` delta: the inversion is kept, and core sets a
      local `core.hooksPath` that git prefers over the global binding.** The
      installer gains a refusal when the resolver returns the machine-level
      directory, and core's binding is declared so the sweep cannot remove it
- [ ] 3.4 Declare core's local binding wherever the sweep reads its exclusions,
      and confirm `--check` reports an undeclared core binding as at risk

## 3b. Sweep the redundant local bindings

Six repositories set a local `core.hooksPath`, which git prefers over the global
one, so the new floor reaches none of them. Five name the directory git would
resolve anyway, so unsetting them changes nothing today and restores reach.

- [ ] 3b.1 Unset the local `core.hooksPath` in `claude-workflow`, `callbot`,
      `fx-signal-agent` and `agenticapps-dashboard` — four configs, five
      bindings, since the dashboard's linked worktree shares its config
- [ ] 3b.2 Confirm each named its own default hooks directory before unsetting,
      so the sweep is provably a no-op rather than assumed to be one
- [ ] 3b.3 Leave `fbc-platform`'s `.husky/_` binding untouched. It is a genuine
      opt-out protecting a real husky installation, and the change records it as
      such rather than treating it as drift
- [ ] 3b.4 Confirm after the sweep that the global binding governs each swept
      repository, by resolving its hooks directory rather than by inference

## 4. Drop `--project`

- [ ] 4.1 Remove `--project` from the deferred-scope notes it appears in
- [ ] 4.2 Record in `core-installer-one-entry-point`'s archived design that its
      Phase 5b sequencing constraint is released, and why
- [ ] 4.3 Confirm Phase 5b has no remaining blockers: `--project` is dropped
      here, and the codex adapter and opencode plugin went with the
      predecessor's narrowing

## 5. Check mode

- [ ] 5.1 `--check` reports whether `core.hooksPath` is set and whether it
      resolves to the published directory
- [ ] 5.2 `--check` reports the published `pre-commit`'s currency by content
- [ ] 5.3 `--check` names the active enforcement surfaces
- [ ] 5.4 `--check` reports a repository whose own hooks are displaced by the
      global binding
- [ ] 5.5 `--check` reports the **effective** binding for the repository it runs
      in, not the global one. A local `core.hooksPath` wins, so reporting the
      global binding as active is wrong in six repositories today
- [ ] 5.6 `--check` names any repository the floor cannot reach, so an accidental
      opt-out is visible rather than inferred
- [ ] 5.7 `--check` reports a **dangling** binding — `core.hooksPath` set to a
      directory that no longer exists, which fails `git commit` machine-wide.
      The currency checks cover drift in a hook that is present; none covers the
      target being absent

## 6. Tests (TDD — RED before GREEN on every one)

- [ ] 6.1 A bare run binds `core.hooksPath` and publishes the hook
- [ ] 6.2 A foreign `core.hooksPath` is reported, left unchanged, and the run
      exits non-zero
- [ ] 6.3 An already-correct binding is reported satisfied and rewrites nothing
- [ ] 6.4 `--host claude` creates and modifies no file under `~/.claude` other
      than a skill symlink — the negative test for the whole change
- [ ] 6.5 A commit in a repository with no local hook is gated by the global one
- [ ] 6.6 A repository with its own local `core.hooksPath` is not governed by the
      global binding
- [ ] 6.7 `--accept-host-config` still exits 64 — inherited, and re-asserted
      here because a floor change that quietly reintroduced a config write is
      exactly what this suite should catch
- [ ] 6.8 Every case runs against a per-case `HOME` **and a per-case git config**;
      a test that sets a global `core.hooksPath` against the real home would
      rebind the operator's machine
- [ ] 6.9 The dispatcher runs `hooks.d` entries and fails on the first non-zero
- [ ] 6.10 The dispatcher does not exec a repository's `.git/hooks/pre-commit`
      even when one is present — the negative test for task 2.7
- [ ] 6.11 A repository whose local `core.hooksPath` names its own default
      directory is swept, and is governed by the global binding afterwards
- [ ] 6.12 A repository with a genuine foreign local binding, husky-shaped, is
      left alone by the sweep
- [ ] 6.13 A dangling `core.hooksPath` is reported by `--check` rather than
      discovered at the next commit

## 7. Evidence

- [ ] 7.1 Installer line count, before and after, with the delta explained
- [ ] 7.2 Host-named code in the repository, before and after — expected to be
      `HOSTS` and `--check` strings only
- [ ] 7.3 `--check` output before and after, as the restore reference
- [ ] 7.4 A real commit gated through the global binding, with the gate's output

## 8. Close

- [ ] 8.1 `openspec validate --all` green
- [x] 8.2 `run-plan-review.sh one-enforcement-floor --implementing-host claude`
      — ran 2026-08-07. gemini, codex and opencode counted, all REQUEST-CHANGES,
      claude excluded as implementing host. `REVIEWS.md` carries the findings
      and the resolution
- [ ] 8.2b **Re-review after this repair.** These edits changed `tasks.md`, so
      the trailer's `tasks-digest` no longer matches and the gate will report
      the review as stale — correctly, because the plan the reviewers read is
      not the plan any more. Re-run before code
- [x] 8.2c `core-self-enforcement` spec delta written 2026-08-07 —
      `specs/core-self-enforcement/spec.md`. Two MODIFIED requirements (core
      resolves its own reference implementation; the pre-commit installer
      resolves the real hooks directory) and one ADDED (core's binding is
      declared and the sweep does not remove it). `openspec validate
      one-enforcement-floor --strict` green
- [ ] 8.3 Stage-2 code review on the diff, in an independent context
- [ ] 8.4 ADR for the enforcement-surface decision; it changes what the workflow
      guarantees locally and that belongs in a decision record, not only in a
      change that gets archived
- [ ] 8.5 Update `docs/HOW-IT-FITS-TOGETHER.md` — its hooks section and its open
      questions both become wrong the moment this lands
