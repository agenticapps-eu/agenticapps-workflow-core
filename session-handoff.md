# Session Handoff — 2026-08-07 (fourteenth session)

**The first code in this whole effort got written.** Five sessions of planning,
and `fresh-clone-needs-nothing` now has three working artifacts, all installed on
this machine. PR #89, 28 commits.

| Change | State |
|---|---|
| `fresh-clone-needs-nothing` | **§3, §4, §9 built and installed.** §1, §2, §5, §6 open |
| `one-enforcement-floor` | reviewed ×2, **no code — this is next** |
| `projects-bind-not-copy` | reviewed ×2, no code |
| `diagram-is-the-surface` | reviewed ×2, no code |
| `fleet-carries-only-current` | **never reviewed**, five sessions old |

## Accomplished

- **`init-project.sh`** — the project installer. `reference-implementations/init-project/`,
  published into `~/.agenticapps/bin` by `install.sh`. 47 assertions.
- **`bind-openspec-tools.sh`** — binds the openspec CLI's skills and commands
  machine-level so no repo carries them. 29 assertions.
- `install.test.sh` 52/0, all suites green, shellcheck clean.
- **Ran `./install.sh --host auto` and `--host omp`.** Machine is on the new
  workflow: 4 artifacts current, 5 hosts bound, opsx bound.
- **Cleaned the machine** — see 9.8. Removed 19 codex `gsd-*.md`, 88 opencode
  gsd files, `~/.gitnexus`, orphaned `normalize-claude-md.sh`, the **live**
  gitnexus MCP registrations in codex and opencode, and two dead pi packages.

## Decisions

- **The initializer is a published bin script**, not an `install.sh` subcommand
  and not a skill step. It *cannot* live in a repo: the capability holds a repo
  to two artifacts and no executables, so it would be the first thing swept.
- **No CI workflow file.** "A fresh clone needs nothing" now states its scope —
  the two surfaces `install.sh` establishes.
- **`openspec init --tools none`.** Every other value writes per-host files into
  the repo; `--tools claude` alone writes six commands and six skills.
- **opsx binds machine-level**, reversing tasks 6.4/8.3 which had said to keep
  the six per-repo skills.
- **omp is establishable — "unverified" repealed.** Its own `dist/cli.js` names
  `~/.omp/agent/skills` and `.agents/skills`. So `omp:.agents/skills` was
  correct all along and **only pi was the defect**. The old verdict came from
  looking for a directory and finding none; the evidence was in the binary.
  The spec now names a host's own implementation as an evidence source.

## Files modified

- `reference-implementations/init-project/init-project.sh` — new
- `reference-implementations/openspec-tools/bind-openspec-tools.sh` — new
- `tools/init-project.test.sh`, `tools/bind-openspec-tools.test.sh` — new
- `install.sh` — one `ARTIFACTS` line; one delegated binder call
- `tools/install.test.sh` — 3 new cases; 2 enumerations that silently missed
  new artifacts
- `openspec/changes/fresh-clone-needs-nothing/` — `MEASUREMENT-opsx.md` new,
  plus a `host-neutral-instruction-files` delta from the review round

## Next session: start here

**`one-enforcement-floor`, and read its task 0.2 first — it is now wrong.**
It records the installer at 212 executable lines with 5 lines of headroom under
the 217 budget. §9 spent all five: `install.sh` is at **exactly 217**, and
`tools/install.test.sh` asserts it. So the budget raise that task called "near
certain" is now unavoidable, and the requirement demands the growth be itemised
rather than pre-approved. Re-measure, then decide whether the floor's wiring goes
inline (needs a raise) or into a helper (does not) — the file's own header says
it is a front end that delegates, which argues for the helper.

After that, 0.4: record the six repositories setting a local `core.hooksPath`.
`git config --global core.hooksPath` is **unset**, so there is no floor today.

**Why this is the blocker for everything else:** projects cannot be swept until a
floor exists that survives deleting a repo's hooks. `factiv/cparx` still carries
`.claude/hooks` and `.claude/skills`; sweeping now leaves it with no gate. The
sweeper itself is also unbuilt — `reference-implementations/` has no sweep
artifact, and §6 is entirely open.

## Open questions

1. **`fleet-carries-only-current` has never been reviewed** — six sessions old.
2. **§18's version number** — still blocking a task in `diagram-is-the-surface`.
3. **9.6 unconfirmed:** `/opsx:propose` has not been observed resolving. A host
   loads commands at session start, so the session that bound them cannot see
   them. **Try `/opsx:propose` in a repo with no `.claude/` early next session** —
   confirming a binding because the symlink exists is what was true of pi for
   months.
4. **9.7:** `scan_archived` walks skill directories only and structurally cannot
   see command directories. Two links into the archived `opencode-workflow`
   survived every install that way — and were *not* dangling, so
   `setup-agenticapps-workflow` still ran the retired scaffolder. Removed by
   hand; the gap is still there, and §9 just added more command directories.
5. **pi's opsx commands are unreachable by symlink.** pi installs extensions as
   packages. Reaching it means publishing a pi package — a separate decision.
6. **gitnexus's binary is still installed and on `PATH`** even though its configs
   are gone. Uninstalling it was beyond what I could establish safely.
7. **`agenticapps-dashboard-add-agent-board`** — stray worktree, still undecided.
   The sweep now refuses globs, which contains it without deciding it.
8. **CodeRabbit still has not reviewed anything here.** Its check state is not
   evidence.
9. `database-sentinel.sh` stays installed until `diagram-is-the-surface` lands.
   Its source is still live in core, so it is not residue yet.
