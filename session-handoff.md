# Session Handoff — 2026-08-10 (twenty-eighth session)

`two-real-instruction-files` is **implemented, tested and pushed** on
`feat/two-real-instruction-files` (PR #107, one commit `572a067` plus a merge of
#106). Nothing is half-finished. **Publishing is deliberately held** — that is
the first decision the next session inherits.

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
- **A sixth enrolled repository found**: `agents-task-viewer`.

## Decisions

- **Merge #106 into this branch rather than wait for it.** Core's own hook
  resolves the working tree, so the new check failed every commit here until the
  migration landed. **#106 is now redundant and can be closed** — its commit is
  in #107's history.
- **Hold publishing.** `./install.sh` is what makes the check reach every
  enrolled repository, and `agents-task-viewer` would be blocked on the spot.
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

**Migrate `agents-task-viewer`, then publish.** It is enrolled, its index stages
`CLAUDE.md` at mode `120000`, and it is the only thing between here and
`./install.sh`. Give it one reviewable commit in its own repository — replace the
link with a copy of `AGENTS.md`'s content — then verify with
`git ls-files --stage AGENTS.md CLAUDE.md` (the index, not the worktree, is what
the check reads), then run `./install.sh` here and re-measure the published
version markers. Only then are tasks 2.6, 5.1 and 5.3 closable and the change
archivable.

## Open questions

1. **`tools/test-install-core-git-hooks.sh` is RED on `main`**, not from this
   work — verified by stashing. Every row exits 1 or 127. Unrelated to this
   change and not investigated.
2. **The proposal's migration inventory is still wrong in the file.** It says
   five repositories; it is six. `tasks.md` §5.1 records the correction and the
   reason — the inventory enumerated repositories carrying the workflow
   *section*, and the floor dispatches on the *enrolment key*.
3. **`cmux` is excluded as being removed** and was never re-checked. If that
   repository outlives the plan, it carries the old arrangement.
4. Carried over: AGE-510, AGE-509, no interception of destructive SQL,
   `normalize-claude-md` has no implementation, `claude-workflow` has 11 commits
   on no remote, the installer has no retired-artifact sweep.
