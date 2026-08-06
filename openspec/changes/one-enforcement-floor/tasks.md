# Tasks — one enforcement floor

**Blocked until `core-installer-one-entry-point` is archived.** The requirements
this change modifies do not exist in `openspec/specs/` until then.

## 0. Prerequisites

- [ ] 0.1 `core-installer-one-entry-point` is archived and `workflow-installation`
      exists in `openspec/specs/`
- [ ] 0.2 Record the installer's executable line count before any edit. The
      predecessor left it at 210 against a 217 budget, so this change has 7
      lines of headroom and will almost certainly need a raise — the requirement
      demands the growth be itemised, not pre-approved
- [ ] 0.3 Record which repositories carry a `.git/hooks/pre-commit` and the byte
      size of each, as the before-state evidence for the divergence claim

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

## 3. Retire the per-repository copies

- [ ] 3.1 Remove the gate `pre-commit` from each of the repositories carrying
      one, having confirmed the global binding is live first
- [ ] 3.2 `tools/install-core-git-hooks.sh` — decide by reading it whether it is
      superseded or retargeted, and record which. It is a delegation target of
      the current installer, so this is not a delete-on-sight
- [ ] 3.3 Core's own binding: ADR-0028 has core resolve its *working-tree* gate,
      which a machine-level published hook does not preserve. Resolve
      explicitly — an ADR if the inversion is being changed, a documented
      local `core.hooksPath` override if it is being kept

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

## 7. Evidence

- [ ] 7.1 Installer line count, before and after, with the delta explained
- [ ] 7.2 Host-named code in the repository, before and after — expected to be
      `HOSTS` and `--check` strings only
- [ ] 7.3 `--check` output before and after, as the restore reference
- [ ] 7.4 A real commit gated through the global binding, with the gate's output

## 8. Close

- [ ] 8.1 `openspec validate --all` green
- [ ] 8.2 `run-plan-review.sh one-enforcement-floor --implementing-host claude`
      — other-vendor reviewers, **before code**
- [ ] 8.3 Stage-2 code review on the diff, in an independent context
- [ ] 8.4 ADR for the enforcement-surface decision; it changes what the workflow
      guarantees locally and that belongs in a decision record, not only in a
      change that gets archived
- [ ] 8.5 Update `docs/HOW-IT-FITS-TOGETHER.md` — its hooks section and its open
      questions both become wrong the moment this lands
