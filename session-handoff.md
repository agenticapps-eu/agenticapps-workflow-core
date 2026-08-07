# Session Handoff — 2026-08-07 (sixteenth session)

**Publish and bind landed. §2's code is done except the two guards that gate
running it for real.** One commit on `feat/projects-bind-not-copy` (PR #89).
Working tree clean, `openspec validate --all` 14/14.

| Change | State |
|---|---|
| `fresh-clone-needs-nothing` | §3, §4, §9 built and installed. §1, §2, §5, §6 open |
| `one-enforcement-floor` | **§0, §1, §2's publish/bind and 3.2 done. 2.8b, 2.8c, 2.9 are what remain in §2** |
| `projects-bind-not-copy` | reviewed ×2, no code |
| `diagram-is-the-surface` | reviewed ×2, no code |
| `fleet-carries-only-current` | **never reviewed**, seven sessions old |

## Accomplished

- `9b322fc` — **GREEN: `reference-implementations/global-floor/bind-global-floor.sh`**
  plus `tools/global-floor-bind.test.sh`, 18/18. Closes 2.1, 2.2, 2.3, 2.4, 3.2.
  shellcheck clean, `install.test.sh` 53/0, `global-floor.test.sh` 13/13.
- **Decision 4's swap landed line-for-line.** `install.sh` 217 → 217 against a
  `-le 217` assertion, as predicted.
- **Two findings, neither from review** — 2.1a and 2.1b below.
- The `cso` gate ran on the diff, scoped to it rather than as the full 14-phase
  gstack workflow, whose preamble would have written telemetry and CLAUDE.md
  routing config without being asked.

## Decisions

- **The old call site's `>/dev/null 2>&1` is gone.** The binder's
  foreign-binding report names the existing value and the value it would have
  set; discarding its output would throw away the only surface that says either.
  Still one call for one call, so the budget held.
- **Two `install.test.sh` cases changed shape, not wording.** The machine
  installer no longer writes a per-repository hook, so "a foreign pre-commit is
  refused" would have passed because nothing happened rather than because
  something was refused. It now asserts a foreign *global* `core.hooksPath`.
- **`GIT_CONFIG_GLOBAL` is pinned per case** in `install.test.sh`. `install.sh`
  writes global git config now, and `HOME` alone does not contain that —
  `git config --global` prefers `$XDG_CONFIG_HOME/git/config` when it exists.
- **2.1b's requirement was written after the code.** That is the wrong order and
  it is the red flag the workflow names. The alternative was dropping a
  demonstrated hazard because it arrived at the wrong step. Recorded as such.

## Files modified

- `reference-implementations/global-floor/bind-global-floor.sh` — new, the binder
- `tools/global-floor-bind.test.sh` — new, 18 cases
- `install.sh` — line 4 comment, `COREHOOKS` → `FLOORBIND`, the call site
- `tools/install.test.sh` — `GIT_CONFIG_GLOBAL` isolation, 16 stubs retargeted,
  three cases rewritten around the new level
- `.../tasks.md` — 2.1, 2.2, 2.3, 2.4, 3.2 closed; 2.1a and 2.1b added
- `.../specs/workflow-installation/spec.md` — new requirement "Nothing is
  published into a directory another account can write", two scenarios

## Next session: start here

**The diff wants an independent read before more code stacks on it.** Step 4 is
code-review on the diff, and §07 independence means a cleared session, not a
subagent — so that is the first action, not a continuation of §2.

After that, §2's remaining three in this order: **2.9 (the preflight), then
2.8c (`--check` names an unenrolled repository), then 2.8b (`init-project.sh`
sets the marker and its header contract is amended in the same diff).** 2.9
first because it is what unblocks running 2.2 for real, and because 2.1a
belongs in its report: the preflight should name what publishing will
**replace**, not only what the binding will newly **govern**.

**`core.hooksPath` is still unset on this machine and `./install.sh` has not
been run.** Binding without the preflight is the machine-wide act the reviewers
objected to. That hold is unchanged.

## Open questions

1. **2.1a — the published directory already holds a foreign file.**
   `~/.agenticapps/git-hooks/pre-commit` is **opencode's host-local variant**,
   25 Jul, 2270 bytes, no `global-floor-version` marker. Probed against a copy:
   the arbitrating helper reads unmarked as `0.0.0` and installs over it, exit
   0. `install-core-git-hooks.sh` *refuses* a hook it does not own; the floor
   binder *overwrites* one. The binding is protected, the file is not. Decide in
   2.9 whether that asymmetry is accepted or closed.
2. **The review is stale, and now by more than edits.** 2.1b added a *new
   requirement* no reviewer has seen — that is a different thing from the
   reworded artifacts open question 7 described last session. §2 changed shape,
   which is the condition that session set for revisiting. Worth a round.
3. **`fleet-carries-only-current` still never reviewed** — seven sessions old,
   flagged at every commit. Still the cheapest useful review left.
4. **§18's version number** — still blocking a task in `diagram-is-the-surface`.
5. **Task 3.5 has no owner** — nothing establishes core's local `core.hooksPath`
   now that `install.sh` has actually stopped calling the hook installer. This
   went from theoretical to live with `9b322fc`.
6. **Machine-level *commands* unconfirmed.** Skills are confirmed; this repo's
   `.claude/commands/opsx/` shadows the global one. Test in a repo with no
   `.claude/`.
7. **pi's opsx commands unreachable by symlink** — needs a pi package.
8. **opencode timed out** at 180s last round and was not counted. Raise
   `REVIEW_TIMEOUT` for a third opinion.
9. **CodeRabbit still has not reviewed anything here.**
