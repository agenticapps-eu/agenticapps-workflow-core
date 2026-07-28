# Session Handoff — 2026-07-28

## The one thing to know

**The workflow has become the project.** 987/274/127/74 files across four hosts,
77 migrations, three conformance harnesses, a 19-section spec. Today it produced
four gate versions, twelve re-vendor PRs, two ADRs and a spec change — and zero
product features. The user is explicitly fed up with this and wants it
**lightweight**.

The plan is `docs/PLAN-lightweight-fleet.md`. **Read it before doing anything.**
It is biased toward *deletion*, and it says explicitly what NOT to build.

The reframing measurement: projects `exec` `~/.agenticapps/bin/`, so
`install -m 0755 <core-artifact> ~/.agenticapps/bin/` makes a change live in
**every project instantly** — no host PR, no migration. Re-vendoring to four
hosts buys only fresh installs on other machines and CI drift checks.

## Accomplished

**GSD + GitNexus + wiki-builder removed** (global `~/.claude`: 68 skills, 34
agents, 9 settings.json hooks, MCP server, plugin symlink; 4 `.gitnexus/` dirs;
8 vendored skill dirs; global CLAUDE.md rewritten). Migration 0033 applied to all
7 OpenSpec projects (3.0.0 → 3.1.0), all committed.

**Reviewer floor is LIVE**: spec 1.1.0 §18 is now `MUST >= 1` / `SHOULD >= 2`,
gate 1.4.0 reports the shortfall instead of blocking. Published to the shared bin
with one `install` — verified through callbot's untouched shim (`0/1`, not
`0/2`). Zero PRs.

**Three §18 pipeline defects fixed and merged** earlier (7 PRs): gate reports
unaddressed REQUEST-CHANGES verdicts (1.3.0), tolerates `**bold**` verdicts
(1.3.1 — found by the very next real run), reviewer-cli splits exit 3 into
3/4/5, producer sanitises vendor stdout.

**callbot**: both open changes reviewed (3 reviewers each, all REQUEST-CHANGES);
`fix-sms-rate-limit-ordering` proposed after codex found the rate-limit row is
written `outcome:'sent'` *before* the provider call and swallowed at
`termin.ts:165`.

## Decisions

- **Four hosts stay** — user wants flexibility to switch. So ADR-0024's
  `host.json` is the target shape, and thin *projects* come first because they
  make thin hosts nearly automatic.
- **Knowledge capture is dead** — user: "none of the accumulated knowledge is
  more than what is now in the openspec specs, changes, archives." Vault notes in
  `~/Obsidian/…/44 Agentic Coding Learnings` (12 notes) are LEFT ALONE.
- **Stop re-vendoring per change.** Publish to the shared bin instead. Host CI
  drift going red in between is informational.

## Core state — 6 commits on `feat/spec-18-single-reviewer-floor`, UNPUSHED

spec 1.2.0 (§15 removed, retired-not-renumbered), gate 1.4.0, ADR-0023 (pin, +
its correction), ADR-0024 (no byte-copies), `resolve-core-artifact.sh` + 13-row
harness, `docs/PLAN-lightweight-fleet.md`. Gate harness 52 rows, all green.

## Next session: start here

**Finish step 1 of the plan — kill knowledge-capture's live surfaces.** Core is
done (spec §15 removed, ADR-0017 superseded). Remaining:

- `claude-workflow`: `skill/SKILL.md` + `setup/snapshot/agentic-apps-workflow-SKILL.md`
  (`## Knowledge Capture — Ritual Tail` runs to EOF from ~line 326),
  `templates/config-hooks.json`, `setup/snapshot/planning-config.json`,
  `.planning/config.json` (drop the `knowledge_capture` key),
  `setup/SKILL.md` (3 spots: the §15 bullet ~182, the two verify bullets ~422
  and ~428, and the `.planning/config.json` comment ~452),
  `migrations/check-snapshot-parity.sh` (block 7 at ~166-188 plus an inline
  assertion near ~99-110), then `bash bin/build-snapshot.sh`.
- Then codex (33 live refs), opencode (7), pi (3), then the 6 projects
  (`.planning/config.json` block + SKILL.md ritual tail) and 8
  `skill-observations/` dirs (198 files; only codex-workflow tracks any — 8).

**DO NOT touch the 32 references inside `migrations/`.** Those are historical
executables replayed for repos on old versions. Migration 0025's four fixtures
will fail once the feature is gone — retire the fixtures *with* the feature,
deliberately.

**A warning from this session:** I tried the `setup/SKILL.md` edit twice with
Python regex/loops and over-deleted catastrophically both times (487 → 87, then
487 → 263 lines). Everything was reverted; `claude-workflow` is clean at
PASS 222 / FAIL 2 (the 2 are the expected gate-vs-core-main drift rows). **Edit
that file with the Edit tool on exact strings, not with regex.**

## Open questions

- `agenticapps-roadmap`'s `retarget-sync-to-openspec` is **paused** pending the
  dashboard / agents-task-viewer rebuild. Questions are in that change's
  `design.md` under "Status: PAUSED".
- callbot's two changes are reviewed but unanimously rejected — read before
  implementing. `fix-sms-rate-limit-ordering` has 3 open decisions in its task
  group 0.
- fx-signal-agent: gitleaks reports **2 secrets in git history** (pre-existing,
  fails every PR).
- ADR-0023's pinning rollout is deliberately deprioritised — it optimises
  re-vendoring, which we've stopped doing per change. Resolver is built and
  harnessed if a second machine ever needs it.
- Unpushed: core (6 commits, no upstream set). `chore/remove-knowledge-capture` and
  `chore/pin-core-artifacts` exist in claude-workflow with **no commits** —
  delete or reuse.
