# Session Handoff — 2026-08-09 (twenty-seventh session)

gstack removed and reinstalled clean. **Spec 2.0.0 shipped and archived.** Three
PRs merged, one closed. Nothing is in flight — the tree is clean, there are no
open PRs, and no branch is waiting.

## Accomplished

- **gstack: full removal and clean reinstall.** One checkout at
  `~/.claude/skills/gstack` (→ **v1.61.0.0**), `./setup --host auto`, native on
  claude + codex + opencode. Removed 55 link-dirs, the hand-vendored
  `setup-gstack`, six duplicate prefixed links, `~/.pi/agent/gstack-pi`
  (**1.0 GB**) and the `pi-gstack` npm package. Kept by decision: `~/.gstack`
  (API key, learnings, 308M browser profiles) and eight project `.gstack/` dirs.
- **`database-sentinel` removed** from every host — skill checkout and both
  aliases. No host declares the name.
- **`impeccable` made on-demand everywhere** — canonical name on all four skill
  dirs, one declaration each, via plain symlinks **nothing in the workflow owns**.
- **PR #99 merged** — the gate-resolution measurement evidence.
- **PR #100 merged — spec 2.0.0.** Two gate bindings removed
  (`database-security`, design), `GSD_SKIP_REVIEWS` deleted from the live
  surface, `gate/` and `workflow-diagram.mmd` deleted, `workflow.mmd`'s two false
  statements corrected, **§13 retired**, ADR-0030 superseding ADR-0011+0012.
- **PR #101 merged** — change archived; `vestigial-surface-removal` is now a spec
  slot (13 requirements), `change-gate-enforcement` gained 3.
- **PR #78 closed** as outdated (131 commits behind, conflicting). Its branch
  `feat/executable-migration-format` is **preserved** — +12,318 lines recoverable.

## Decisions

- **Kill the custom prefixed links, go native on all hosts.** The six removed
  were true duplicates — `codex-cso` and `gstack-cso` both declared `cso`.
- **`~/.gstack` kept.** Holds a live OpenAI key and months of learnings, and
  causes no duplication.
- **`impeccable` unbound but not uninstalled.** It is a policy change, labelled
  as one rather than buried under "dead surface". Its availability is
  deliberately not the workflow's concern.
- **§13 retired on the fourth argument.** Three attempts argued from local
  machine state and were wrong. The one that holds: this release is already
  major, so the three hosts binding §13 re-assert against 2.0.0 either way —
  retiring it now imposes no break the release does not already impose, and
  retiring it later would impose a second. `reference-implementations/README.md`
  **keeps** the binding facts; only their status changed.
- **2.0.0, not 1.7.0.** Two reviewers independently called the minor argument
  self-serving. They were right.
- **CI floor lowered 71 → 69** with the reason in the diff, as the guard demands.

## Files modified

Merged in #100 (39 files) and #101. Principal:
`spec/00-overview.md` (2.0.0, §13 retirement), `spec/02`, `spec/17`, `spec/18`,
`spec/13-ts-declare-first.md` (deleted), `skills/agentic-apps-workflow/SKILL.md`,
`reference-implementations/openspec-change-gate/*`, `tools/change-gate-conformance.sh`,
`.github/workflows/openspec-gate.yml`, `workflow.mmd`, `gate/` + `workflow-diagram.mmd`
(deleted), `adrs/0030-*`, `CHANGELOG.md`, `reference-implementations/README.md`,
`docs/evidence/gate-skill-resolution-measured.md`.
Machine, not version-controlled: gstack, database-sentinel, impeccable,
ts-declare-first as above.

## Next session: start here

**Nothing is half-finished.** Pick one of three live changes, all reviewed, none
started this session:

| Change | Open | What it is |
|---|---|---|
| `one-enforcement-floor` | 45 | largest; has a CODE-REVIEW.md already |
| `fresh-clone-needs-nothing` | 36 | |
| `fleet-carries-only-current` | 32 | carries three GSD/planning removal inventories |

`projects-bind-not-copy` shows 34 open tasks and is **CLOSED** — its `tasks.md`
says so on line 1, obsolete by measurement. Do not work it.

Two of these predate spec 2.0.0 and may need their version claims reconciled.
**Check that first**, before executing tasks — this session lost most of a day to
a change whose premise had expired.

## Open questions

1. **`impeccable` is bound by two hand-made symlinks** no installer recreates.
   Deliberate, but a machine rebuild loses them.
2. **The installer has no retired-artifact sweep**, so removals don't reach other
   machines' installs. Scoped honestly to this machine; gap open.
3. **Host-repo residue** — `GSD_SKIP_REVIEWS` survives in `claude-workflow` and
   `codex-workflow` templates. Recorded, not patched; those are archived repos.
4. **After any `gstack-upgrade`, re-run `./setup --host auto`** — upgrade runs a
   bare `./setup`, which relinks claude only.
5. `feat/executable-migration-format` — reopen as a fresh change against 2.0.0 if
   the executable migration format is still wanted.
6. Carried over: AGE-510 (nothing detects an unreadable instruction file),
   AGE-509 (`check-shims.sh` has no reverse pass), no interception of destructive
   SQL, `normalize-claude-md` has no implementation, `claude-workflow` has 11
   commits on no remote.

## Mistakes worth not repeating

- **I measured skill presence by directory basename.** codex and opencode key on
  the declared frontmatter `name:`. That one error produced a whole proposed
  change with no subject. Use `grep -lm1 "^name: X$" */SKILL.md`.
- **I over-decomposed the plan** — 64 checkboxes for ~26 actions, after two
  proposed changes that were discarded. The operator called it out; the actual
  implementation then took one pass with no further review.
- **I stopped at "your reason was wrong" instead of finding a better one.** §13's
  retirement was available the whole time via the marginal-cost argument; it took
  the operator asking twice to go look.
- **I talked myself down from a correct 2.0.0 to a wrong 1.7.0** and needed two
  external reviewers to put it back.
