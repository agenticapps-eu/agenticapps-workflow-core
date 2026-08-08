# Session Handoff — 2026-08-08 (seventeenth session)

**A cleanup session that turned into three closed findings.** Three commits on
`feat/projects-bind-not-copy` (PR #89). Tree clean, `openspec validate --all`
14/14 and `--strict` green. No code written — everything below is plan, spec or
machine state.

| Change | State |
|---|---|
| `one-enforcement-floor` | 9.6, 9.11, 9.13 **closed** as Decision 6; 9.14 new; §10 opens five implementation tasks |
| `fleet-carries-only-current` | **all 14 findings folded**; Req 2 dropped; `.planning/` goes outright |
| `fresh-clone-needs-nothing` | §3, §4, §9 built. §1, §2, §5, §6 open — untouched |
| `projects-bind-not-copy` | reviewed ×2, no code — untouched |
| `diagram-is-the-surface` | reviewed ×2, no code — untouched |

## Accomplished

- **The global `~/.claude/CLAUDE.md` is rewritten**, 107 → 60 lines. Three of its
  claims were false and all three are corrected in place.
- **`fleet-carries-only-current`: all fourteen review findings folded** across
  four artifacts (`d63fa88`), then two tasks reconciled after doing them early
  (`4b7306b`).
- **`one-enforcement-floor`: Decision 6** closes 9.6, 9.11 and 9.13, and 9.14
  fell out of the work (`530af27`).
- **Machine cleanup**: `meta-observer` unregistered; ~56M of GSD and GitNexus
  residue deleted.
- **Memory saved**: `trim-fleet-instruction-files` — the fleet `CLAUDE.md` /
  `AGENTS.md` sweep the operator asked for.

## Decisions

- **`.planning/` is deleted outright, tracked and untracked** — operator's call,
  "we are fully on OpenSpec now". Requirement 2 of `fleet-artifact-currency` is
  dropped with it: it existed for `agenticapps-roadmap`'s 134 tracked files and
  that checkout is gone, so it would now protect two files.
- **The binder establishes core's local hooks binding** (Decision 6). Every other
  candidate disclaims it in its own text — `install.sh` by Decision 4,
  `init-project.sh` by "no hooks, no host configuration",
  `fresh-clone-needs-nothing` by "nothing else", CI by being a detector. Four
  correct boundaries meeting, not one oversight. Not Decision 4 returning: the
  binder repairs the one known casualty of its own act, in the one repository it
  runs from by construction.
- **9.11 is amended, not excepted.** A core-only carve-out would exempt core from
  the floor it publishes, which inverts what core is for.
- **The global file's workflow section was deleted, not trimmed.** Its own note
  said it stays "only until the rewritten trigger skill carries it" — skill 4.0.0
  carries it, including §11. That is also the procedure `fleet-artifact-currency`
  requires, performed once on the file with the most readers.

## Files modified

- `~/.claude/CLAUDE.md` — rewritten (not in git)
- `~/.claude/settings.json` — `meta-observer` `SessionEnd` entry removed; backup
  at `settings.json.pre-meta-observer-removal`. `GEMINI_API_KEY` left in place
- `openspec/changes/fleet-carries-only-current/` — all four artifacts rewritten
- `openspec/changes/one-enforcement-floor/` — `design.md` (Decision 6),
  both spec deltas, `tasks.md` (§10 added)
- **Machine, deleted**: `~/.claude/get-shit-done/`, `gsd-pristine/`,
  `gsd-local-patches/`, `gsd-migration-journal/`, `.gsd-profile`,
  `gsd-file-manifest.json`, `gsd-install-state.json`; `core/.gitnexus` (44M)

## Next session: start here

**Implement `one-enforcement-floor` §10, RED before GREEN on every task.** Five
tasks, and 10.2 is the one to write first because it is the ordering constraint:
the binder sets core's local `core.hooksPath` plus
`agenticapps.hooksbinding=declared` **before** the global binding, and does not
set the global one if either write fails. Then 10.1, the pre-bind inventory that
refuses an entry the installer did not publish until it is accepted by name.
10.3 removes core's own `PreToolUse` registration from `.claude/settings.json`,
which 9.11's amendment now permits — do it after 10.1 and 10.2, since it leaves
`pre-commit` and CI as the only two surfaces. 10.4 is prose: reword 3b.1 and
3b.2 so the sweep reads as the mechanism rather than a no-op.

Tests go in `tools/global-floor-bind.test.sh` (18 cases today), per-case `HOME`
**and** per-case git config — 6.8 exists because a test that sets a global
`core.hooksPath` against the real home rebinds the operator's machine.

Measured 2026-08-08 and true at handoff: global `core.hooksPath` **unset**,
core's local **unset**, core's `<common-dir>/hooks` is `.git/hooks`, core's own
hook is present. So the displacement 9.13 describes is still latent and fires on
the first successful bind — 10.2 has to land before anyone runs the binder.

## Open questions

1. **Step 4's code review has still never run**, and the branch is now 48
   commits. §07 independence means a cleared session. This is the largest
   accumulated risk on the branch and it only gets harder.
2. **PR #89's title is stale** — "Four changes, planned and reviewed — no code
   yet" — and there are three sessions of shipped code on it.
3. **Three credentials outlived their file.** `agenticapps-roadmap`'s `.env` held
   `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`. Deleting the
   checkout did not revoke them. Operator action.
4. **`claude-workflow` cannot be deleted safely yet.** 11 commits on no remote,
   `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
5. **§9 still holds eight open findings** — 9.4a, 9.4b, 9.5, 9.7, 9.8, 9.9,
   9.10, 9.12. 9.8's honest version now lives inside the 9.11 amendment; the task is
   still open.
6. **The fleet trim the operator asked for is four steps downstream.** It is task
   4.6 of `fleet-carries-only-current`, whose precondition is
   `projects-bind-not-copy` archived — that change has 48 open tasks and no code.
   Lifting it out and doing it standalone is a live option.
7. **CodeRabbit still has not reviewed anything here.**
