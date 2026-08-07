# Session Handoff — 2026-08-06 (ninth session)

**The real run happened, it is verified, and the change is archived.**
`openspec/specs/workflow-installation/spec.md` is durable current truth — 13
requirements. `one-enforcement-floor` is the only active change and it is
unblocked. Branch `feat/one-skills-payload`, nine commits, all green, **pushed**;
PR #88 updated and retitled.

Detail lives in `openspec/changes/archive/2026-08-06-core-installer-one-entry-point/`
— `CODE-REVIEW.md`, `SECURITY-REVIEW.md`, and the round-six and round-seven
sections of `design.md`. This file carries only what does not.

## Accomplished

- **The install ran for real** (`f3db223`): 15 rebindings, 11 removals, one
  legacy copy removed — the 26 bindings into archived checkouts, now 0. All five
  hosts resolve into core; pi and omp bound for the first time.
  `docs/evidence/install-run-after.md`.
- **Verified**: fleet shims still bind the authority's bytes; the declared set is
  published at the reference hash; no host configuration file was touched.
- **Three review passes** — round five on the diff (4 real defects, fixed with
  proven negative tests), `cso`, round six, round seven. Then the archive.

## Decisions

- **The preservation requirement was wrong, not the run.** It said every replaced
  or removed binding is preserved; the run changed 26 symlinks and wrote one
  preserved directory. A symlink has no content beyond its target and a copy of
  one resolves into the checkout about to be deleted.
- **A checkout of this repo is live prompt code for five hosts.** Now stated in
  the capability rather than a security appendix. Review skill changes by diff;
  pin a worktree if a machine must run and review at once.
- **Reviewing stopped at round seven.** The code had not changed since round
  five; six and seven were spec and prose coherence. Specs get amended after
  archive.
- **`REVIEWER_TIMEOUT` does not reach `run-plan-review.sh`** — it reads
  `REVIEW_TIMEOUT`. Six rounds of opencode's opinion went to that. Silent
  failure: the reviewer times out and is simply not counted.
- **The budget test enforced 250 while the spec says 217.** Round four lowered it
  everywhere except the test enforcing it. `install.sh` is 212.

## Files modified

- `install.sh` — 212 executable lines, shellcheck clean
- `tools/install.test.sh` — 49 cases; budget corrected; three new cases proven RED
- `docs/evidence/install-run-after.md`, `.gitignore` — new
- the change bundle, now archived

## The mistake I made, and undid

`git add -A` in the archive commit (`925481a`) swept in three untracked
leftovers: six `.claude/skills/gitnexus/` skill directories, **a 44-line GitNexus
section appended to core's own `CLAUDE.md`** instructing agents to run
`npx gitnexus analyze`, and five `.planning/skill-observations/` files — the notes
the handoff had just called Donald's to delete.

Undone in `8e7eaec`: `CLAUDE.md` restored, tracking removed, both paths
`.gitignore`d. The files stay on disk, so **the gitnexus skills still load in this
repo until deleted** — a decision not yet taken. A blanket add cannot tell the
work from whatever else is lying around, and here that includes removed software
and instruction text.

## The payload is not one payload yet

| Repo | family | copy |
|---|---|---|
| agenticapps-dashboard | agenticapps | 331 lines, v3.2.0 |
| agenticapps-roadmap | agenticapps | 324 lines, v3.2.0 |
| agents-task-viewer | agenticapps | 324 lines, v3.2.0 |
| dashboard-add-agent-board | agenticapps | **415 lines, v3.0.0** |
| callbot | factiv | 324 lines, v3.2.0 |
| cparx | factiv | 324 lines, v3.2.0 |
| fbc-platform | factiv | **346 lines, v3.2.0** |
| fx-signal-agent | factiv | 324 lines, v3.2.0 |

Core ships **235 lines, v4.0.0**. All eight are committed directories in
`.claude/skills/`, not symlinks — four byte-sizes across two claimed versions,
and `fbc-platform` differs from its three v3.2.0 siblings while claiming to be
them. Each repo also carries six copied `openspec-*` skills; core carries those
six too.

So: **the project-specific workflow copies were never removed.** The run bound
host directories; project `.claude/skills/` is a different surface, and
`--project` — the mode that would have reached it — is superseded. Which skill
loads there is loader ordering between the project copy and the new core symlink.

`.planning/` also survives in `cparx`, `fbc-platform` and `fx-signal-agent`, with
a **tracked** `config.json` in the latter two. Neither `factiv-website` nor
`factiv-design-system` is a workflow project.

## Next session: start here

A proposal for the project-local copies is the live work — Donald asked for it
and it is the one that matters, because the other candidates are deferrals while
this is a payload published and then shadowed in eight repositories.

After it: `one-enforcement-floor` has **no plan review at all** (task 8.2) and no
code, which is when a plan review is cheapest — `run-plan-review.sh
one-enforcement-floor --implementing-host claude`, `REVIEW_TIMEOUT=600`. Then the
check-mode change carrying all four deferred reporting gaps.

## Open questions

1. **Four check-mode gaps**, all reported rather than silent: a host called bound
   on one of two skills; an archived binding reported as plain `bound`; core's
   pre-commit hook never reported though it is the bare-run postcondition; and no
   defined exit status for an absent, stale, modified or unreadable artifact.
   Each is a legitimate deferral; four in one mode is a change asking to be
   written.
2. **`is_archived` matches link text, not the resolved target**, and ownership is
   a repository-name substring. Both want a portable `realpath` and should land
   together.
3. **Reported paths carry `/Users/donald` and are unescaped.** Third time raised,
   third time deferred to `screen-review-egress`.
4. **`workflow.mmd` still says the gate requires "REVIEWS ≥ 2".** Untrue since
   gate 2.0.0. Probably belongs with `one-enforcement-floor`.
5. **Does `AGENTS.md` still need a workflow section** once the skill carries the
   workflow? `host-neutral-instruction-files` says yes. Still open.
6. **`~/.config/opencode/rules/gsd-oc-work-hard.md`** is a live global rule file
   reaching opencode, left over from GSD.
7. **pi reads a fifth directory**, `~/.pi/agent/skills`, neither bound nor swept.
   Measured empty: 25 entries, all relative symlinks into `~/.agents/skills`.
8. **PRs #86, #87, #88 and #78 are open.** This work sits on top of #87.
