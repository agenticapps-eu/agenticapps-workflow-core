# Session Handoff — 2026-08-08 (nineteenth session)

**PR #89 is merged and §10 is closed.** Four commits on
`feat/floor-establishes-cores-binding`, pushed, **no PR open yet**. Tree clean,
`openspec validate --all` 14/14, 14 suites green.

The floor binder now repairs what it displaces and inventories what it
activates. Then the security pass found two defects in the consent gate that
had just been built, and both are fixed.

## Accomplished

- **PR #89 merged** as `3fb113c`; branch deleted; local `main` level with
  `origin/main`, which closes last session's "32 commits behind".
- **§10 complete — 10.1 through 10.7.** The binder establishes core's local
  binding plus `agenticapps.hooksbinding=declared` before the global one (10.2),
  inventories `~/.agenticapps/git-hooks/` with per-entry consent before binding
  (10.1), core's `PreToolUse` registration is gone (10.3), and the sweep stops
  describing itself as a no-op (10.4).
- **Two security findings, both reproduced before being fixed** (10.7). See
  Decisions 4 and 5.
- **A test suite was writing into this repository** (10.6). Fixed at both ends.
- `tools/global-floor-bind.test.sh` 18 → **48 cases**, and **0 of 48 pass**
  under `GLOBAL_FLOOR_BIND_BIN=/usr/bin/true`. `test-claude-hook-wrapper.sh`
  12 → 14.

## Decisions

- **Core's binding is established only when the global bind is actually about to
  happen.** A foreign global `core.hooksPath` is refused *first*, before core is
  touched: refusing means the global binding is never set, so core's hook is
  never displaced, so there is no casualty to repair — and writing into a
  repository with nothing to repair is the shape Decision 4 removed.
- **A foreign LOCAL binding in core is reported, never overwritten** — the same
  posture the binder already takes one level up. husky sets exactly that, and a
  `declared` flag left on someone else's hooks directory would tell the sweep to
  protect it.
- **The default hooks directory comes from `--git-common-dir`.** Never
  `--git-path hooks`, which honours `core.hooksPath` and would let a wrong
  binding confirm itself.
- **Recognition of `pre-commit` is the publisher's exit status, not the presence
  of a marker.** The marker is a comment, so it cannot establish who wrote a
  file. A `pre-commit` carrying `9.9.9` is newer than the checkout's,
  arbitration declines to publish, the file survives — and the run bound the
  directory *while printing "holds nothing this installer did not publish"*.
  The false claim was the finding. Exit 3 is still not a publish failure; it is
  no longer a bind decision either, and conflating the two was the hole.
- **The acceptance list must not glob.** `for a in $ACCEPT` is unquoted for word
  splitting, and unquoted expansion also does pathname expansion, so
  `GLOBAL_FLOOR_ACCEPT='*'` expanded against whatever directory the binder ran
  from. `set -f` around the loop.
- **`.claude/settings.json` is deleted, not emptied.** `{}` is dead text and
  dead text reads as a live guarantee. The wrapper **stays** and documents
  in-file that it is deliberately unregistered — `project-hook-binding` provides
  for exactly that, and two suites read it as core's shim-contract instance.
- **10.4 corrected in all four places**, since `proposal.md` and the §3b
  preamble carried the same words. `design.md`'s "a no-op **setting**" stands —
  that describes the binding, which is genuinely redundant, not the unset.
- **No `.gstack/security-reports/` and no new ADR.** This repo carries what the
  diagram requires, so findings live beside the tasks that produced them; and
  Decision 6 is locked in the change's `design.md`, as Decisions 1–5 were.

## Files modified

- `reference-implementations/global-floor/bind-global-floor.sh` — pre-bind
  inventory with per-entry consent (`GLOBAL_FLOOR_ACCEPT` + tty prompt);
  establishes core's local binding and declaration before the global one;
  foreign global and foreign local bindings both refused, never overwritten
- `.claude/settings.json` — **deleted** (held only the `PreToolUse` registration)
- `.claude/hooks/openspec-change-gate.sh` — header records that it is
  deliberately unregistered and why the file still exists
- `tools/global-floor-bind.test.sh` — 18 → 48 cases; `$CORE` is now a real
  repository; `run_binder` reads stdin from `/dev/null`
- `tools/install.test.sh` — `new_core()` git-inits the copy; `run_install`
  records this repo's own local binding around every run and fails by case name
- `tools/test-claude-hook-wrapper.sh` — registration assertions inverted, plus
  CI-runs-the-gate and installer-exists
- `openspec/changes/one-enforcement-floor/{tasks,proposal}.md` — §10 ticked with
  its reasoning; 10.6 and 10.7 added; the no-op claim corrected

## Next session: start here

**Do 9.4a.** Nothing in the shipped code sets `agenticapps.workflow.enrolled` at
all, so the published dispatcher exits 0 in silence for every repository and the
floor governs nothing once bound. That is the remaining half of C1: §10 landed
the guard rails, but **`install.sh` still must not be run** until enrolment
exists, because `install.sh:346` binds the floor unconditionally and
`core.hooksPath` displaces `.git/hooks/pre-commit` entirely. Recovery if it is
run: `git config --global --unset core.hooksPath`. Tests go in
`tools/global-floor-bind.test.sh` or a new enrolment suite, per-case `HOME`
**and** per-case git config — and now also per-case *local* config, which is
what 10.6 was about. Measured today and still true: global `core.hooksPath`
unset, core's local unset, `agenticapps.workflow.enrolled` unset.

## Open questions

1. **No PR for this branch yet**, and four commits of §10 sit on it.
2. **Stage 2 has not read any of §10.** Per §07 it must run in a cleared session
   with no implementation context — that now covers the six `install.sh` fixes
   from last session *and* everything in this one.
3. **The newer-marked-`pre-commit` refusal is behaviour the spec delta does not
   name.** The inventory requirement has three scenarios and this is a fourth;
   it should get one, or the code is ahead of its delta.
4. **Eight §9 findings still open** — 9.4a, 9.4b, 9.5, 9.7, 9.8, 9.9, 9.10, 9.12.
5. **The vendored `opencode` `pre-commit` is still in
   `~/.agenticapps/git-hooks/`** — 2.3K, unmarked, dated 2025-07-25. Re-measured
   today. Under the new inventory a real run reports it and replaces it.
6. **Spec drift on `main`**: `openspec/specs/project-hook-binding/spec.md` names
   `normalize-claude-md` as a live shim instance in seven places; the
   implementation is gone. Planned in `diagram-is-the-surface`, 0/46.
7. **Three credentials outlived their file** — `agenticapps-roadmap`'s `.env`
   held `CLOUDFLARE_API_TOKEN`, `GH_CROSS_REPO_TOKEN`, `LINEAR_API_KEY`.
   Deleting the checkout did not revoke them. Operator action, still outstanding.
8. **`claude-workflow` cannot be deleted safely yet** — 11 commits on no remote,
   `plan/28-split-01` 9 ahead of `origin/main`, 1 stash.
9. **The fleet trim** is still task 4.6 of `fleet-carries-only-current`, gated on
   `projects-bind-not-copy` archiving, which #89 did not do.
10. **CodeRabbit still has not reviewed anything here** — it went SUCCESS on #89
    again without reading it.
