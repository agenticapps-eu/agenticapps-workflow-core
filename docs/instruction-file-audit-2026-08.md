# Instruction-file audit — 2026-08-05

A one-time record, not a living document. No tool was written to produce it and
none should be written to maintain it.

Scope: every `CLAUDE.md` / `AGENTS.md` that reaches an agent — the two global
files, core, and the seven fleet projects. The four host repos were read but not
edited; they are being archived.

Conflict classes are the six from the brief: **1** dead reference · **2** split
brain · **3** coverage gap · **4** duplicated in the skill · **5** points at
deleted machinery · **6** self-rewriting.

## What makes this worth doing

Conflicting instructions do not error. Both files are concatenated into context
and the model picks silently, so a stale rule competes with the live one and you
never see it lose.

The measured surface: **13 live instruction files, 2,573 lines, 70 dead-reference
hits.**

---

## Fixed first, because nothing else was durable until it was

| # | Finding | Class | Evidence | Resolution |
|---|---|---|---|---|
| 1 | The hook that rewrites `CLAUDE.md` re-emitted a dead command | 6 + 1 | `normalize-claude-md.sh:160` printed ``Run `/gsd-profile-user` to generate``; GSD was removed 2026-07-28 | **Hook retired** (commit `1fe2464`) |
| 2 | …and pointed the live file at frozen history | 5 | same file, lines 107–112 mapped `PROJECT.md`, `STACK.md`, `CONVENTIONS.md`, `ARCHITECTURE.md` into `.planning/` | same |
| 3 | It would have overwritten a hand-written correction | 6 | `cparx/CLAUDE.md:340` had been corrected by hand to say `/gsd-profile-user` no longer exists. `build_replacement` for `slug=profile` re-emits the dead command on the next `Edit`/`Write` | same |
| 4 | A checker with no caller | — | `provisioning-check.sh` (548 lines) + its test suite (654) — not in CI, no invoker but each other | **Deleted** (commit `131995f`) |

The hook was a **no-op in five of seven** fleet repos (no marker blocks at all),
**opted out** in `agents-task-viewer`, and **live in exactly one**: `cparx`. Its
three-clause removal test in `project-hook-binding` cleared — no numbered spec
section or capability spec bound it, it produced no evidence artifact, and it
enforced no gate.

The six project shims still resolve it and will emit a once-per-hour
non-blocking notice until removed per project. The shim exits 1, never 2, so
nothing blocks.

---

## Global files

| File | Lines | Class | Finding | Fix |
|---|---:|---|---|---|
| `~/.codex/AGENTS.md` | 1 | 1 | **Its only line is dead.** It directs Codex to use GitNexus MCP tools (`query`, `context`, `impact`) "before reaching for grep". GitNexus was removed 2026-07-28 | Delete the file |
| `~/.claude/CLAUDE.md` | 93 | 3 | Carries load-bearing workflow rules that reach **one of five hosts**. opencode, pi and omp have config dirs but **no global instruction file at all**; Codex's is the dead line above | Trim to personal preferences; behaviour moves to the trigger skill |

Verified absent: `~/.config/opencode/AGENTS.md`, `~/.opencode/AGENTS.md`,
`~/.pi/AGENTS.md`, `~/.config/pi/AGENTS.md`, `~/.omp/AGENTS.md`,
`~/.config/omp/AGENTS.md`.

---

## Repositories

`C` = `CLAUDE.md` lines, `A` = `AGENTS.md` lines.

| Repo | C | A | Class | Finding | Fix |
|---|---:|---:|---|---|---|
| `agenticapps-workflow-core` | — | — | 3 | **Has neither.** Every host works this repo with no repo-level instruction | Add one `CLAUDE.md`, symlink `AGENTS.md` → it |
| `agents-task-viewer` | 276 | 153 | 2, 1, 5 | Split brain. **14 GSD marker blocks** (`-start`/`-end` form, un-normalized). `:118` points at `.claude/claude-md/workflow.md`, which Phase 5c deletes | Strip markers, keep the pinned-version stack prose, symlink |
| `cparx` | 418 | 91 | 2, 1, 5 | Split brain. **6 normalized GSD blocks** whose "auto-synced" links resolve into `.planning/` | Inline what is still true, drop the links, symlink |
| `callbot` | 542 | 124 | 2 | Split brain; largest instruction surface in the fleet | Reconcile, symlink |
| `agenticapps-dashboard` | 202 | 110 | 2 | Split brain | Reconcile, symlink |
| `agenticapps-roadmap` | 143 | — | 3 | No `AGENTS.md` — four hosts read nothing here. **See the caveat below** | Symlink after the `.planning` question is settled |
| `fbc-platform` | 132 | — | 3 | No `AGENTS.md` | Symlink |
| `fx-signal-agent` | 298 | — | 3 | No `AGENTS.md`. One **nested** file at `tokentelemetry/frontend/AGENTS.md` silently adds rules for Codex, which concatenates root-down | Symlink; read the nested file and fold or keep deliberately |

Three of seven fleet repos have no `AGENTS.md` (the brief estimated four). No
`AGENTS.md` in the fleet is currently a symlink; all four that exist are regular
files, which is why all four diverged.

Duplicated-in-the-skill (class 4) is present but not itemised per line: the
`GSD_SKIP_REVIEWS=1` escape-hatch prose and §11 coding-discipline text appear in
both instruction files and the trigger skill — `agents-task-viewer:268` and
`fx-signal-agent:262` are representative. These resolve when the trigger skill
becomes the single home for behaviour.

---

## The one thing that is not a dead reference

`agenticapps-roadmap` is a **product built on `.planning/`**, not a repo that
merely still has one. `scripts/sync-gsd-linear.ts` (wired as `pnpm sync:gsd`,
with a test beside it) walks sibling repos' `.planning/` trees and upserts them
into Linear. `sync.config.json` names three: `claude-workflow`, `cparx`,
`fx-signal-agent`. Its `CLAUDE.md:141-143` says so explicitly and ends **"Do not
delete it."**

So "`.planning` dirs can be removed" collides with a live product here, and one
of that product's three inputs is a repo being archived. **Left untouched
pending a decision.** Core's own `.planning/` was removed — core is not among
the three inputs, so nothing broke.

---

## Not in scope, recorded so it is not rediscovered

`reference-implementations/project-hooks/README.md` (831 lines) narrates the
retired hook in ~13 places, and `openspec/specs/project-hook-binding/spec.md`
(1,921 lines) uses it as a worked example in 7. Both are documentation of past
reasoning rather than instructions to an agent, and both are inside the layer the
collapse brief deletes. Their live claims were corrected; their narrative was
left alone rather than rewritten twice.
