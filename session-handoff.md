# Session Handoff — 2026-08-10 (twenty-eighth session)

`two-real-instruction-files` is **implemented, tested, published and complete**
on `feat/two-real-instruction-files` (PR #107). Every task in the change is
ticked. `agents-task-viewer` was retired and deleted in the same session, which
is what cleared the publish hold. Nothing is half-finished.

## Accomplished

- **`init-project` 1.2.0 → 2.0.0.** No `ln -s`, no `mv -f`, no `rm`: its only
  write to an existing file is between the markers, in place, so the file keeps
  its path, inode and mode. The block is now *updated* rather than skipped when
  present. A symlink under either name is refused, naming which one and the
  migration step; so is a FIFO. 17 RED → **101/101 GREEN twice**.
- **`gate` 2.0.0 → 2.1.0.** A second blocking condition: `AGENTS.md` and
  `CLAUDE.md` must be readable, regular and byte-identical. 12 new harness rows
  (section G), 6 RED → **81/81 GREEN**, plus five real commits in a scratch repo.
- **spec 2.0.0 → 2.1.0**, minor. §18's escape-hatch MUST narrowed.
- **Core migrated**, by merging #106 in. Both names are regular files, one blob.
- **`tools/agents-md-conformance.sh`** no longer refuses `CLAUDE.md` outright —
  only where it is the sole instruction file. 77 → 79 rows, green.
- **A sixth enrolled repository found and retired**: `agents-task-viewer`. It
  was an experiment, it appeared in no inventory, and it was the last repository
  on the machine holding the old symlink arrangement. Notice merged (PR #20),
  GitHub repo archived, 84M checkout deleted, family `CLAUDE.md` records it.
- **Published.** `~/.agenticapps/bin/` carries gate **2.1.0** and init-project
  **2.0.0**. The published copy scores 81/81, and a real `git commit` in an
  enrolled scratch repo is refused through the whole machine path.
- **`tools/test-install-core-git-hooks.sh` fixed: 8/16 → 16/16.** It was red for
  the same reason a scratch-repo test misled me earlier — the fixtures inherited
  the machine's **global** `core.hooksPath`, so they resolved to the global
  floor's hooks directory and the installer refused, correctly, to overwrite a
  hook it did not write. CI has no global git config, so CI never saw it.

## Decisions

- **Merge #106 into this branch rather than wait for it.** Core's own hook
  resolves the working tree, so the new check failed every commit here until the
  migration landed. **#106 is now redundant and can be closed** — its commit is
  in #107's history.
- **Publishing was held, then released.** `./install.sh` is the moment the check
  reaches every enrolled repository, and `agents-task-viewer` would have been
  blocked on the spot. The hold was lifted only after that repository was gone
  and all four remaining enrolled repositories were dry-run against the new gate
  at `rc=0`. Evidence before the machine-wide write, not after.
- **Retire `agents-task-viewer` rather than migrate it.** It was an experiment
  that was built, worked, and is not being carried forward — migrating it would
  have been maintenance spent on something about to stop existing. Its 45
  no-remote commits are pre-squash history of a merged PR, so nothing was lost;
  the tip SHA is recorded in two places anyway.
- **Amend §18 rather than add an escape hatch.** The hatch MUST had been vacuous
  since gate 2.0.0; a second blocker made it live and would have demanded a hatch
  for the one check whose value is that it has none. §18 now names both
  conditions as taking none. Minor: it removes an obligation and adds none, and
  it does **not** oblige hosts to implement the pair check.
- **Preservation is scoped to bytes outside the markers**, and asserted two ways
  — a digest of the file minus the marker range for the update case, and an
  exact-prefix comparison for the append case, since appending necessarily adds
  the blank separator line.
- **Inode assertions**, because every content assertion in the suite is satisfied
  by a `mv` of a fresh file over the destination — which is what task 1.4 forbids.

## Files modified

`reference-implementations/init-project/init-project.sh` (rewritten, 2.0.0) ·
`reference-implementations/openspec-change-gate/openspec-change-gate.sh`
(`instruction_pair_check`, wired first in pre-commit; 2.1.0) ·
`tools/init-project.test.sh` (rewritten; symlink assertions inverted) ·
`tools/change-gate-conformance.sh` (+section G, 12 rows) ·
`tools/agents-md-conformance.sh` + `.test.sh` (carve-out narrowed) ·
`.github/workflows/openspec-gate.yml` (floors 69→81, 57→69) ·
`spec/18-retargeted-change-gate.md`, `spec/00-overview.md`, `CHANGELOG.md` ·
`docs/HOW-IT-FITS-TOGETHER.md` · `AGENTS.md` + `CLAUDE.md` (both, identically) ·
`openspec/changes/two-real-instruction-files/tasks.md`.

## Next session: start here

**Merge PR #107, then archive the change.** The work is done and the artifacts
are already published, so the merge is the last step that changes anything:
`gh pr merge 107`, then `openspec archive two-real-instruction-files`, which
folds the four spec deltas into their slots. **Close PR #106 unmerged** — its
commit is in #107's history, so merging both would be merging the same change
twice. Check CI first: the floors moved (`MIN_SCORED_ROWS` 69 → 81,
`MIN_ROW_CALLSITES` 57 → 69) and this is the first run against them.

## Open questions

1. **The proposal's migration inventory is still wrong in the file.** It says
   five repositories; it was six. `tasks.md` §5.1 records the correction and the
   reason — the inventory enumerated repositories carrying the workflow
   *section*, and the floor dispatches on the *enrolment key*. The proposal is a
   record of what was believed when it was written, so it stays as it is.
2. **`cmux` is excluded as being removed** and was never re-checked. If that
   repository outlives the plan, it carries the old arrangement. It is not
   enrolled, so the gate does not reach it either way.
3. **Only `tools/test-install-core-git-hooks.sh` was hardened against the global
   git config.** The other suites pass on this machine, which may be because
   they isolate or because they never resolve `core.hooksPath`. Not
   distinguished.
4. Carried over: AGE-510, AGE-509, no interception of destructive SQL,
   `normalize-claude-md` has no implementation, `claude-workflow` has 11 commits
   on no remote, the installer has no retired-artifact sweep.
