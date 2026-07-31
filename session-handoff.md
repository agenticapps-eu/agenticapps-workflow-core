# Session Handoff — 2026-07-31 (evening)

## Read this first

**Done and merged:** core PR #47 and claude-workflow PR #109. The Claude
installer publishes core's artifacts from a pin instead of vendored copies.

**Also merged:** codex-workflow PR #33 (main `6c9403a`) — all checks green.
**Not started:** opencode-workflow, pi-agentic-apps-workflow.

**Method note for whoever picks this up — this is the lesson of the session.**
Do NOT start a host port before surveying that host's installer, its test
suite, AND every workflow in `.github/workflows/`. I didn't, and paid for it
three times in codex alone: symlinked templates, a bespoke 560-row suite, and a
second CI workflow I never opened. Each cost a round trip. `pi` is known to
differ more than codex did — survey it fully first.

## Merged

| | |
|---|---|
| core `main` | `6c0e3fe` (PR #47 merged at `6cd3b9c`, merge commit not squash) |
| claude-workflow `main` | `70ef922` (PR #109) |

Merged with a **merge commit** on purpose: #109 pinned a commit on #47's branch,
and a squash would have orphaned that sha. The pin then advanced to `6cd3b9c`,
core's main; all seven entries re-verified there, all byte-identical.

Verified from merged main by a real `install.sh` run: published bytes match the
pin, 0 temp leaks, `--ci` exit 0, suite 218/4 → 226/0.

## codex-workflow — MERGED (PR #33, main `6c9403a`)

Three jobs were red on the first push (`test (ubuntu/macos)`, `ci-gate`) because
`ci.yml` runs `migrations/run-tests.sh` on a fresh clone where `bin/` is empty —
I had only materialised by hand locally. Fixed in `run-tests.sh` so every caller
is covered, not just the workflow that happened to be red. Final: 563 pass /
0 fail, gate 71/71, all checks green.

What it did, and why it differs from claude's:

- **`bin/` is a gitignored CACHE, not deleted.** claude-workflow deleted its
  copies outright; that is wrong here, because the setup skill's
  `templates/*.sh` are **symlinks into `bin/`** and migration 0013 installs a
  target repo's copies from that stable installed path. So
  `bin/materialise-core-artifacts.sh` regenerates them, hash-verified against
  the manifest. A verified cache can't drift; a committed copy can, and did.
- That also keeps `test_migration_0014`'s provenance leg working **unchanged** —
  it compares on-disk bytes to the manifest, which match after materialising.
- **Adopting gate 2.0.0 broke 8 assertions, all one class:** they asserted the
  gate BLOCKS an unreviewed change. It doesn't — reviews are advisory and only
  `openspec validate --all` blocks. They now drive the deny path via
  `OPENSPEC_BIN=false` (validate red). One row added: an under-reviewed change
  must still REPORT, or "advisory" would mean "silent".
- Both conformance harnesses moved from `636f106` to `6cd3b9c`; they'd been
  scoring a 2.0.0-era gate with a 636f106-era harness.

## Still to do: opencode and pi

Both ship **gate 1.3.1 / wrapper 1.1.0** and both carry core's harnesses at
`636f106`. Neither has a manifest or the resolver. Recipe, per host:

1. Vendor `bin/resolve-core-artifact.sh` from core@`6cd3b9c`.
2. Write `tools/core-vendor.manifest` pinned at `6cd3b9c` — copy codex's, which
   documents the RESOLVED vs VENDORED split. Shas are in codex's manifest.
3. Re-vendor both `tools/*-conformance.sh` at the same commit.
4. Decide **cache-vs-delete** by whether anything else reads `bin/`. Survey first.
5. Wire the installer; expect the same 2.0.0 test breakage as codex.
6. Check **every** workflow in `.github/workflows/`, not just the obvious one.

**pi is the awkward one:** its `install.sh` also copies the gate into each
TARGET repo as a repo-local fallback (`$TARGET_REPO/bin/openspec-change-gate.sh`),
and `README.md` / `AGENTS.md` / migration 0007 all describe the gate as
"vendored verbatim". Prose needs correcting alongside the code.

**opencode extra:** `tools/change-gate-conformance.sh --family` sweeps sibling
hosts' `bin/openspec-change-gate.sh` and filters missing paths with `[ -f ]`.
Since claude-workflow no longer vendors one, that sweep now silently scores one
fewer host and still reports success. Not broken — worse, quietly narrower.

## Fleet status (re-derived, supersedes the old inventory)

**Nothing is blocked.** `openspec validate --all` is the only blocking condition
under gate 2.0.0 and it passes in all 7 checkouts. Every project hook resolves
`~/.agenticapps/bin` first, which holds gate 2.0.0 / producer 1.2.0 / wrapper
1.2.0 — so every real project runs the advisory gate today.

| repo | active changes | validate |
|---|---|---|
| agenticapps-dashboard | 5 | green |
| ” (worktree `add-agent-board`) | 8 | green |
| agenticapps-roadmap | 1 | green |
| agenticapps-workflow-core | 2 | green |
| callbot | 3 | green |
| fbc-platform | 8 | green |
| fx-signal-agent | 10 | green |

**The 37-vs-35 dispute is settled: 37 was right.** The 35 breakdown simply
omitted core's own 2 changes; there was never a contradiction. Also:
`agenticapps-dashboard-add-agent-board` is a **git worktree** of
`agenticapps-dashboard`, not a separate repo — so it's 6 repos, not 7. The count
gates nothing now; it is bookkeeping.

## Open items, most valuable first

1. **`change-gate-conformance.sh` reports success for a missing file** —
   `SKIP (not found)`, `TOTAL: 0 passed, 0 failed`, exit 0. The wrapper's
   harness fails correctly on the same input. Worked around with `test -s` /
   `--check` in the host CIs; **the real fix belongs in core**, which owns both
   harnesses. A harness that certifies nothing while looking green is the exact
   failure it exists to prevent.
2. **Core does not gate itself.** No `.claude/hooks/`, no `settings.json`, no
   git `pre-commit`, no CI gate workflow — only `pages-cheatsheet.yml`. The repo
   that defines §18 runs it at none of the three surfaces the spec names.
3. **Archive `track-and-conform-plan-review`** — task 8.4 was its last real open
   item.
4. **`shim-project-hooks` is on main as an unimplemented proposal** (landed with
   #47, intentionally). Implement or archive.
5. **Migration 0032 installs the producer without version arbitration** —
   pre-existing, left untouched to keep the shipped-migration edit minimal.

## Working-tree loose ends

- `claude-workflow`: untracked `openspec/` slot and regenerated
  `.claude/commands/opsx/*.md`, created by my real `install.sh` run (it runs
  `openspec init` when the slot is missing). Harmless; delete if unwanted.
- `claude-workflow`: two unrelated modified files left alone —
  `setup/snapshot/workflow-config.md`, `templates/workflow-config.md`.
- `codex-workflow`: on the feature branch; `bin/openspec-change-gate.sh` and
  `bin/reviewer-cli.sh` exist on disk but are now gitignored — that is correct.
- `core`: untracked `.planning/skill-observations/` (frozen GSD area, untouched).
