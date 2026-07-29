# Session Handoff — 2026-07-28 (evening)

## The one thing to know

**Step 1 of `docs/PLAN-lightweight-fleet.md` is DONE for the agenticapps
family.** Knowledge capture (spec §15) is gone from all four hosts and all
three in-family projects. Nine commits, all on branches, **none pushed, no PRs
opened**. Read the plan before picking the next step — it is biased toward
deletion and says explicitly what NOT to build.

Next decision is the plan's **step 4**: are codex / opencode / pi actually in
daily use? Everything in steps 3 and 5 depends on that answer, and only you can
give it.

## Accomplished — nine commits across seven repos

Every commit follows the same rule: **live surfaces deleted, `migrations/`
untouched.** Migration docs are historical executables replayed for repos on
old versions; editing them rewrites the past. Where a migration's *tests*
replayed against live templates that are now deleted, the test was retired with
the feature and replaced by a retirement check (doc retained as history per §08,
plus a guard that the payload cannot reappear).

| Repo | Branch | Commit | Tests |
|---|---|---|---|
| claude-workflow | `chore/remove-knowledge-capture` | `4ce2b35` | 220/2 |
| codex-workflow | `chore/remove-knowledge-capture` | `b3e23d4` + `dfff1e4` | 562/0 |
| opencode-workflow | `chore/remove-knowledge-capture` | `7663617` + `405787e` | 126/0 |
| pi-agentic-apps-workflow | `chore/remove-knowledge-capture` | `d71edfd` | 236/0 |
| agenticapps-dashboard | `chore/remove-knowledge-capture` | `6c576e0` | — |
| agents-task-viewer | `chore/remove-knowledge-capture` | `bfad14c` | — |
| agenticapps-roadmap | `chore/untrack-skill-observations` | `3b6d0d8` + `5c61e45` | — |

**claude-workflow's 2 failures are the known, pre-existing gate-vs-core drift
rows** — the host lags core's gate 1.4.0. Expected per plan step 2; not caused
by this work. Every other repo is at zero failures. pi matches its baseline
exactly (236/0/47); opencode dropped 139 → 126 purely from retired fixture
coverage.

**Retired migration tests:** claude `0025` (4 fixtures deleted), codex `0007`
and `0010` (~380 lines), opencode `0005` (~120 lines). Also dropped: the §15
assertions inside claude's parity block 7, codex's `0012`, opencode's `0010`.

**opencode's parity guard got STRONGER.** It compared `.planning/config.json`
*modulo* `knowledge_capture`, because that block's `note` carried a resolved
repo name that could not live in a generic snapshot. With the block gone,
nothing in the file is repo-specific — it is now compared **in full**.

**Freshness probes rebased.** claude's setup Step 5 "not an old baseline" check
and parity block 7 keyed on the ritual tail's heading. They now key on
`## Verification Check (after a change is archived)` — an OpenSpec-era (3.0.0)
heading, so the staleness check the tail incidentally provided survives.

**ADRs superseded, not deleted:** claude ADR-0038, codex ADR-0008, opencode
ADR-0008 (full banners); pi ADR-0002 got a **scoped** banner — it closed three
deltas at once, and only the §15 third is retired. The §02 plan-review binding
and host-scoped session handoff still stand.

**`.planning/skill-observations/` untracked + gitignored** in codex (8 files),
opencode (1) and roadmap. claude / pi / dashboard / agents-task-viewer already
ignored it.

## Decisions

- **No migration for any of this.** A migration would install machinery to
  delete machinery. Installed projects were edited directly. No version bumps —
  claude's snapshot VERSION stays 3.2.0 because nothing joined the chain.
- **Hooks 4a/4b (`skill-router-log.sh`, `session-bootstrap.sh`) were LEFT
  ALONE.** They write to `.planning/skill-observations/` and so *look* like
  knowledge capture, but they are a separate feature (skill-router audit log)
  with their own bats tests. Deleting them is scope creep. The log files on
  disk were left too — they regenerate while the hook lives, so deleting them
  is churn. Untracking them was the durable half.
- **`docs/standards/gsd-binding-and-planning.md`** — only the §15 checklist row
  was removed, in claude / codex / opencode. **The whole document is stale**:
  it is GSD-era and GSD was removed on 2026-07-28. Retiring it belongs to plan
  step 5, not here.

## Files modified

Per repo, the shape is the same: the `## Knowledge Capture — Ritual Tail`
section in the trigger skill, the `knowledge_capture` config block, the
`config-knowledge-capture.json` / `obsidian-learnings-note.md` templates, the
setup skill's seeding step and verify bullets, ENFORCEMENT-PLAN, the ADR, and
the migration-test retirements. See each commit body — they are detailed.

## Shipped — 12 PRs open, all MERGEABLE, none merged

Core is on `feat/spec-18-single-reviewer-floor`; every other branch is
`chore/remove-knowledge-capture`. **Core's PR is the parent** — it carries spec
1.2.0, which is what the other eleven implement. Merge it first.

| Repo | PR | Repo | PR |
|---|---|---|---|
| claude-workflow | #107 | agenticapps-roadmap | #9 |
| codex-workflow | #32 | callbot | #97 |
| opencode-workflow | #22 | cparx | #108 |
| pi-agentic-apps-workflow | #18 | fbc-platform | #102 |
| agenticapps-dashboard | #83 | fx-signal-agent | #117 |
| agents-task-viewer | #14 | **agenticapps-workflow-core** | **see below** |

**A final sweep of both families finds zero §15 surfaces left.**

### factiv turned up more than the 3 repos the last count predicted

- **`fbc-platform` was missed entirely** by the earlier "6 projects" figure.
- **`cparx` carried four copies** — the vendored skill, **two** full ritual
  tails in `AGENTS.md` (codex-host block *and* opencode-host block, 123 lines
  together), the config block, and `.opencode/workflow-config.md`'s prose. It
  is developed on three hosts in parallel, which is exactly the duplication the
  plan is about.
- **`callbot` had a name collision that a blind sweep would have broken.**
  `docs/decisions/0003-knowledge-capture.md` is a **product** ADR — the
  internal admin UI for capturing practice knowledge (Supabase magic link, RLS,
  `admin.factiv.eu`). Nothing to do with §15. Left alone, as was ADR-0012's
  "admin UI knowledge area". **Check the content, not the filename.**
- `.pre-0034` SKILL.md backups sit untracked in all four factiv repos —
  leftovers from migration 0034. Harmless; left alone.

### One gate bypass, with your approval

`callbot` was committed with **`GSD_SKIP_REVIEWS=1`** because
`fix-sms-rate-limit-ordering` carries 0/1 reviewers. `openspec validate --all`
was green 13/13 and the commit touches no product code. The gate logged the
bypass; it is disclosed in both the commit body and PR #97.

## Next session: start here

**Answer the step 4 question: are codex / opencode / pi live?** If they are
not, archiving them removes three migration chains, three installers, three CI
configs and three quarters of the propagation problem at a stroke, with no new
machinery — and it changes how much of steps 3 and 5 is worth doing at all.

Before that, the 11 PRs need reviewing and merging. They are independent; the
host PRs are the substantive ones, the seven project PRs are near-identical
82-line deletions.

## Open questions

- Core's `openspec/` slot is **untracked** — along with `gate/`, `prompts/`,
  `.planning/` and a dozen loose `.md`/`.pdf` files at the repo root. None are
  gitignored; they predate this session and were left alone. The spec slot of
  the repo that owns the spec not being in git is worth a decision.
- `callbot`'s `fix-sms-rate-limit-ordering` still has **no REVIEWS.md**, and
  `complete-operations-readiness` / `provision-sms-delivery` carry unaddressed
  REQUEST-CHANGES from gemini, codex and opencode.
- `fx-signal-agent` has **ten** open changes with unaddressed REQUEST-CHANGES
  verdicts — the gate allows them on quorum but NOTEs every one on every commit.
- `agenticapps-roadmap`'s `retarget-sync-to-openspec` is still **paused**
  pending the dashboard / agents-task-viewer rebuild.
- Both roadmap and dashboard have open changes with unaddressed
  `REQUEST-CHANGES` verdicts — the gate lets them through on quorum but prints
  a NOTE naming the objectors. Address or record why not.
- fx-signal-agent: gitleaks still reports 2 secrets in git history.
