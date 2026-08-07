# Session Handoff — 2026-08-07 (twelfth session)

The precedence measurement is **done** — it was the only thing blocking code.
Branch `feat/projects-bind-not-copy` is now **PR #89**, 18 commits, `gate` green.
Four changes in flight, all planning artifacts, **no code written yet**.

| Change | Reviews | State |
|---|---|---|
| `projects-bind-not-copy` | 2 rounds × 3 vendors | repaired; measurement folded in |
| `one-enforcement-floor` | 2 rounds × 3 vendors | repaired, artifact-complete |
| `diagram-is-the-surface` | 2 rounds × 3 vendors | repaired (1 approve, 2 request-changes) |
| `fresh-clone-needs-nothing` | **none** | proposed this session |
| `fleet-carries-only-current` | **none** | still never reviewed |

## Accomplished

- Merged **#87** and **#88**; closed **#86** (two generations stale — it carried
  the 2026-08-05 handoff). Opened **#89**, merged `main` in, `gate` passed in 32s.
- **Measured loader precedence per host.** `MEASUREMENT.md` in
  `projects-bind-not-copy`. Corrected three of its own tasks.
- Proposed and twice-reviewed **`diagram-is-the-surface`** — removes `gate/`,
  `GSD_SKIP_REVIEWS`, `gitnexus`, `database-sentinel.sh`.
- Proposed **`fresh-clone-needs-nothing`** — pi binding, project onboarding,
  installer prerequisites.

## The measurement, and what it changed

**The hosts disagree.** Claude resolves the host binding in all four repos probed,
including both outlier copies. Codex resolves it uncontested — no fleet repo has a
`.codex` copy at all. **opencode is a race**: it reads four directories carrying
the name, its logs show each collision replacing the last, and the scan order
differed in all six repos captured. Three consecutive runs in `cparx` loaded
v3.2.0, v4.0.0, v3.2.0.

That is a better argument than the proposal made. A copy that reliably loses is
untidy; a copy that wins half the time means the fleet runs two workflow versions
with no way to tell which from inside the session.

Corrections, each measured: **seven** repos not eight (core carries none);
**five** byte-identical siblings not three, and **two** outliers not one
(`agenticapps-dashboard` carries a third variant nobody had named); **pi loses
nothing** to the sweep — no repo has a `.pi` copy either, so pi resolves no
workflow skill today, before any sweep.

## Four things I had wrong, all caught

1. **§13 was in `diagram-is-the-surface` and should never have been.** I claimed
   no host bound `ts-declare-first` — derived from one dangling symlink in
   `~/.claude/skills`. Three hosts bind it, and pi reached `full` conformance at
   host v0.6.0 *by* binding it. Dropped from the change.
2. **"The hatch's only live consumers are its tests" was false.**
   `run-plan-review.sh:677` recommends `GSD_SKIP_REVIEWS=1` to the operator at a
   failure path. The real surface is 20+ files, including core's own trigger skill.
3. **The removal never reached where things execute.**
   `~/.agenticapps/bin/database-sentinel.sh` exists right now, and
   `~/.agenticapps/bin/normalize-claude-md.sh` is **still installed** after #87
   retired it. Deleting sources while installed copies survive is now its own
   requirement.
4. **"Reaches one of five hosts" is wrong.** All five hosts *support* a global
   instruction file (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`,
   `~/.config/opencode/AGENTS.md`, `~/.pi/agent/AGENTS.md`,
   `~/.omp/agent/AGENTS.md`); one is populated. The conclusion holds on the
   one-copy argument, not the stated reason. Fix in this repo *and* the global file.

Also caught by reviewers: the `db-sentinel` arm on `workflow.mmd` is the **skill
gate** (`spec/17` lines 99–100), not the removed hook — I nearly deleted a live
gate.

## Decisions

- **Close PR #78, do not rewrite it.** All four host scaffolder repos are
  archived; core has no `migrations/`. §08 governs a format with no live
  implementer. The one migration the new direction needs is a one-shot sweep, not
  a chain. §08 itself becomes a removal candidate — decided against
  `fresh-clone-needs-nothing`, not separately.
- **A repo carries `openspec/` and one instruction file**, both committed.
  `AGENTS.md` real, `CLAUDE.md` a symlink to it. Nothing else.
- **No global instruction files for workflow behaviour** — five hosts means five
  files; the skill is one file reaching all of them.
- **No `.archive/` copy in the sweep.** Files are committed, so git is the
  rollback; a retained copy is the duplication being removed.
- **One review round per change, then move on.** Saved to memory.

## Files modified

- `openspec/changes/projects-bind-not-copy/MEASUREMENT.md` — new, the evidence
- `openspec/changes/projects-bind-not-copy/tasks.md` — tasks 1.1–1.7 corrected
- `openspec/changes/diagram-is-the-surface/` — new change, twice reviewed
- `openspec/changes/fresh-clone-needs-nothing/` — new change, unreviewed
- `session-handoff.md` — this file

## Next session: start here

**Decide the two open questions in `fresh-clone-needs-nothing`'s design, then
review it once.** They are the only things blocking that change, and both are
yours rather than derivable: **where the initializer lives and what it is called**
(core has no project-side surface; making it an `install.sh` subcommand overloads
a script whose header says it targets a *machine*), and **whether a repo gets a CI
workflow file** (CI is the only enforcement surface that survives a machine
without the workflow, so "a fresh clone needs nothing" is true only for the two
local surfaces).

Then: `REVIEW_TIMEOUT=600 run-plan-review.sh fresh-clone-needs-nothing
--implementing-host claude`. The producer publishes with `mv -f` — back up any
existing `REVIEWS.md` first. `REVIEWER_TIMEOUT` does not reach that script.

## Open questions

1. **Initializer location and name** — blocking `fresh-clone-needs-nothing`.
2. **Does a repo need a CI workflow file?** Out of scope there; unowned.
3. **§18's version number** — blocking one task in `diagram-is-the-surface`.
   Removing `GSD_SKIP_REVIEWS` is breaking to the gate interface but not to the
   numbered sections; §18 is normative and two statements change.
4. **`fleet-carries-only-current` has never been reviewed.**
5. **`agenticapps-dashboard-add-agent-board`** — a stray worktree with its own gate
   and conformance harness, the likeliest source of the repeated fleet miscounts.
   A naive fleet loop would sweep it. Needs its own decision.
6. **Is omp's skill directory ever establishable?** If omp reads no skills, the
   mapping should be removed rather than corrected.
7. **CodeRabbit has not reviewed anything in this repo today** — four for four
   hollow greens ("rate limited", "116 files exceed the limit of 100"). Its check
   state is not evidence.
8. Reported paths still carry `/Users/donald` unescaped — deferred a fifth time.
9. The gitnexus skills still load in this repo until `diagram-is-the-surface`
   lands.
