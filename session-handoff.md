# Session Handoff — 2026-08-10 (twenty-eighth session)

`two-real-instruction-files` is **shipped**: implemented, tested, published,
merged (#107) and **archived** into the four spec slots. #106 is closed as
superseded. `agents-task-viewer` was retired and deleted in the same session,
which is what cleared the publish hold. Nothing is in flight.

## Accomplished

- **`init-project` 1.2.0 → 2.1.0.** No `ln -s`, no `mv -f`, no `rm`: its only
  write to an existing file is between the markers, in place, so the file keeps
  its path, inode and mode. The block is now *updated* rather than skipped when
  present. A symlink under either name is refused, naming which one and the
  migration step; so is a FIFO. 17 RED → **102/102 GREEN twice**.
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
  **2.1.0**. The published gate scores 81/81, and a real `git commit` in an
  enrolled scratch repo is refused through the whole machine path.
- **init-project 2.0.0 → 2.1.0: the section now carries `section-version`.** CI
  caught it on the first run — `agents-md-conformance.sh` has required a content
  version all along, the writer never emitted one, and nothing noticed because
  core's `AGENTS.md` was a symlink to a section-less `CLAUDE.md`. The writer's
  suite now scores its own output against the real scorer.
- **`tools/test-install-core-git-hooks.sh` fixed: 8/16 → 16/16.** It was red for
  the same reason a scratch-repo test misled me earlier — the fixtures inherited
  the machine's **global** `core.hooksPath`, so they resolved to the global
  floor's hooks directory and the installer refused, correctly, to overwrite a
  hook it did not write. CI has no global git config, so CI never saw it.

## Decisions

- **Merge #106 into this branch rather than wait for it.** Core's own hook
  resolves the working tree, so the new check failed every commit here until the
  migration landed. #106 was then closed unmerged, its commit being in #107's
  history — merging both would have landed the same change twice.
- **Refresh the deltas rather than force the archive.** `openspec archive`
  refused three times, each time naming scenarios the MODIFIED blocks would have
  deleted: three in `agent-lifecycle-management`, one in
  `host-neutral-instruction-files`, six in `project-onboarding` — five of which
  were only RENAMED, since a header that changes wording reads as a scenario
  removed. Every one was carried through, and the directory/dangling-link
  scenario gained the FIFO case the implementation already handles.
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

`reference-implementations/init-project/init-project.sh` (rewritten, 2.1.0) ·
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

**The fleet repair is done, and it was two repositories, not four.** The claim
that all four carried a version-less section was wrong: it read a
`section-version: (none)` sweep as meaning the section existed without a version,
when in two of them there is no section at all.

| repo | state | action |
|---|---|---|
| `cparx` | section, no version | fixed — PR #134, one line per file |
| `fx-signal-agent` | section, no version; migration PR still open | fixed **inside** that PR, so it lands correct rather than landing wrong |
| `callbot` | two identical regular files, **no section** | nothing to fix; scores 5/5 clean |
| `fbc-platform` | `CLAUDE.md` only, **no section** | nothing to fix; out of scope as the sole instruction file |

Both fixes were written by `init-project.sh` 2.1.0 rather than by hand, so the
block matches what the writer emits and a re-run is a no-op. Diff in each case is
`2 files changed, 2 insertions(+)`, both rewritten in place, nothing outside the
markers touched. cparx scored 9/1 before and 10/0 after.

**Whether `callbot` and `fbc-platform` should carry the section at all is a
decision, not a repair.** For `fbc-platform` it is the larger one: it has no
`AGENTS.md`, so provisioning it would create one and widen its rules' readership
from Claude to every host — which the initializer discloses precisely because it
is a semantic change.

Two open changes remain, neither touched this session:
`initializer-cannot-destroy-instruction-file` (complete, unarchived — check
whether 2.0.0 subsumed it before archiving) and `one-enforcement-floor`
(55/100).

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
