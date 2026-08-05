# Session Handoff — 2026-08-05 (sixth session)

Donald gave two briefs: collapse the workflow to one repo
(`PROMPT-core-collapse-to-one-repo.md`) and, as a companion to run first, audit
the instruction files for conflicting rules. This session did the audit's items
1–3 and closed Phase 1 of the collapse. **Everything below is subtraction:
10,657 deletions against ~180 insertions in core.**

Note: the fifth-session handoff carrying Donald's verdict is on the unmerged
branch `docs/handoff-donalds-verdict` (`cc71fd3`), not on `main`. Read it.

## Accomplished

- **Phase 1 of the collapse — verified already done, skipped, not deferred.**
  All four hosts pin core commit `ef030d0`; every sha256 in all four manifests
  matches core's current tree byte-for-byte, including both conformance
  harnesses. 43 commits have landed since the pin and none touched those five
  files. The 1.3.1/1.1.0 drift the brief cites was repaired 2026-07-31.
- **Retired `normalize-claude-md`** (core `1fe2464`). It re-emitted the dead
  `/gsd-profile-user` command and would have overwritten cparx's hand-written
  correction saying that command no longer exists. No-op in 5 of 7 fleet repos,
  opted out in a 6th, live in exactly one. Its three-clause removal test cleared.
- **Deleted `provisioning-check.sh` + its test suite** (`131995f`) — 1,202 lines,
  not in CI, no caller but each other.
- **Removed core's `.planning/`** and gave core its first `CLAUDE.md`, with
  `AGENTS.md` a symlink to it (`a266e44`).
- **Merged `agents-task-viewer`'s split brain** (that repo, branch
  `chore/one-instruction-file`): 429 lines across two diverging files → 289 in
  one, `CLAUDE.md` now a symlink to `AGENTS.md`.
- **Wrote `docs/instruction-file-audit-2026-08.md`** — 13 live instruction files,
  2,573 lines, 70 dead-reference hits, classified.

## Decisions

- **Skipped Phase 1 rather than doing it** — the drift is gone, and acting would
  have meant commits in two repos §5a archives untouched (a stop condition).
- **Deleted the provisioning checker instead of repairing its 14 failing tests** —
  repairing a checker nothing runs is the anti-pattern both briefs name.
- **Symlinked `CLAUDE.md` → `AGENTS.md` in agents-task-viewer** (the brief's
  example is the other direction) because that repo already declared `AGENTS.md`
  canonical.
- **Kept the §11 discipline block.** See open question 1 — it is not redundant.
- Left the 831-line project-hooks README and the 1,921-line
  `project-hook-binding` spec narrating the retired hook. Their live claims were
  corrected; rewriting narrative inside a layer Phase 5b/6 deletes is doing it
  twice.

## Files modified

- `reference-implementations/project-hooks/` — `normalize-claude-md.sh` deleted;
  `ARTIFACTS`, `SHIMMED-HOOKS`, `OPT-OUTS`, `README.md` updated
- `tools/` — `provisioning-check.sh`, `project-hook-provisioning.test.sh`,
  `lib/semver.sh`, `normalize-claude-md.test.sh`, `fixtures/normalize-claude-md/`
  all deleted
- `CLAUDE.md` (new), `AGENTS.md` (symlink), `docs/instruction-file-audit-2026-08.md` (new)
- `.planning/` removed
- `agents-task-viewer/AGENTS.md` rewritten, `CLAUDE.md` → symlink

Core branch `chore/retire-normalize-claude-md`, 4 commits, unpushed. ATV branch
`chore/one-instruction-file`, 1 commit, unpushed. All 9 core test suites pass;
`openspec validate --all` green; the gate exits 0 on its own.

## Also done, after Donald's mid-session answers

He said `.planning` can go, then that `agenticapps-roadmap` is being retired
anyway, then "mark the repos to be retired as such".

- **Archived on GitHub:** `claude-workflow`, `codex-workflow`,
  `opencode-workflow`, `pi-agentic-apps-workflow`, `agenticapps-roadmap`. That is
  collapse-brief §5a done by settings toggle, no commits spent tidying them.
- **`.planning/` removed from all seven fleet repos and core.** Safe: its
  `config.json` is declarative only — its own `_note` says "Orchestrator code
  does not read this block" — and no hook, gate or bin script reads it.
- **The false §18 rule corrected** in `callbot` (both files) and
  `fx-signal-agent`, using `agenticapps-dashboard`'s already-correct wording.
- **`~/.codex/AGENTS.md` deleted** — its single line pointed at GitNexus.
- Dangling `.planning` references removed from four instruction files; cparx's
  six broken "auto-synced" blocks deleted.

**Mistake to know about:** three of those repos were not on `main`, so the
`.planning` commit landed on in-progress branches — `retire-v1-surfaces`
(dashboard), `chore/remove-vestigial-host-installs` (cparx) and the AGE-495
branch (fbc-platform). Donald is actively working in dashboard (he committed 13
seconds after mine), so history was **not** rewritten. Drop those commits if the
PRs should stay clean.

## Next session: start here

Fold the coding discipline into the trigger skill — open question 1, and the
Phase 2 rewrite needs it anyway. Only then can §5c remove the embedded §11
blocks. After that: symlink `AGENTS.md` in `callbot`, `cparx`,
`agenticapps-dashboard`, `fbc-platform` and `fx-signal-agent` (§5c's "one project
first" week applies — `agents-task-viewer` is that project), read
`fx-signal-agent`'s nested `tokentelemetry/frontend/AGENTS.md`, and trim
`~/.claude/CLAUDE.md` to preferences.

## Open questions

1. **Phase 5c would delete rules that have no other home.** It removes the
   embedded §11 block on the premise the trigger skill carries it. It does not —
   neither the project skill (324 lines) nor the global one contains *Think
   Before Coding*, *Simplicity First*, *Surgical Changes* or *Goal-Driven
   Execution*. That text lives only in core's `spec/11` and in each project's
   instruction files. Fold it into the skill first.
2. ~~`.planning` vs the roadmap product~~ — **resolved.** Roadmap is retired
   and archived, so its `.planning`-reading feature goes with it. All
   `.planning/` dirs removed.
3. The collapse brief's tier-3 list names four skills, but the diagram's
   conditional-gate node names **security · db-sentinel · design · qa**. So `cso`
   and `qa` look like survivors too. Unresolved; it shapes the Phase 2 payload.
4. Minor data corrections to the collapse brief: core has **no** `migrations/`
   (the 645 migration files are in the four host repos, archived untouched, so
   §5b's "73 migration documents" has no target in core); `run-plan-review.sh` is
   757 lines not ~900; the four installers total 1,866 not 1,544; **3** of 7
   fleet repos lack `AGENTS.md`, not 4.
