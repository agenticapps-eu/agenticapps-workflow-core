# Session Handoff — 2026-08-06 (ninth session)

**The real run happened, it is verified, and the change is archived.**
`openspec/specs/workflow-installation/spec.md` is durable current truth — 13
requirements, 634 lines. `one-enforcement-floor` is the only active change and
it is unblocked.

Branch `feat/one-skills-payload`, eight commits this session, all green,
**pushed**. PR #88 updated and retitled — it no longer just carries the payload.

## Accomplished

- **The install ran for real** (`f3db223`). `./install.sh --host auto
  --replace-unrecognised`: 15 rebindings, 11 removals, one legacy copy removed —
  the 26 bindings into archived checkouts `design.md:231` measured, now 0. All
  five hosts resolve into core; **pi and omp are bound for the first time**. The
  skill list refreshed mid-session, which is live proof the wrong-trigger-skill
  problem is fixed. `docs/evidence/install-run-after.md`.
- **8.5–8.7 verified**: every declared hook in all seven fleet repos still binds
  the authority's bytes; the declared set is published at the reference hash and
  the retired `normalize-claude-md.sh` row survived as predicted; no host
  configuration file was created or modified.
- **Round five, on the diff** (`f400e46`) — gemini REQUEST-CHANGES, codex
  REQUEST-CHANGES. Four real, all fixed with proven negative tests:
  a failed `ln` during rebind left a binding as nothing while the run reported
  success; a candidate was accepted on `[ -e ]`, which a stray file named `cso`
  satisfies; the restore command quoted neither path; a bare `--host` aborted
  under `set -u`. `CODE-REVIEW.md`.
- **`cso`** (`0516ac8`) — two findings, `SECURITY-REVIEW.md`.
- **Round six, the 9.2 re-review** (`6c3a0a5`) — gemini APPROVE, codex
  REQUEST-CHANGES. Four fixed, four bounded, two rejected; dispositions are the
  last section of `design.md`.

## Decisions

- **The preservation requirement was wrong, not the run.** It read "every
  replaced or removed binding is preserved"; the run changed 26 symlinks and
  wrote one preserved directory. A symlink has no content beyond its target, a
  copy of one resolves into the checkout about to be deleted, and the reported
  previous target restores it exactly. Copying is for directories and regular
  files. Codex found this after four rounds had not.
- **The live-checkout property is now in the capability, not a security
  appendix.** A checkout of this repo is live prompt code for five hosts, so
  `gh pr checkout` of a branch touching `skills/` arms every host before the
  review, including the agent doing it. Not a reason to copy — a reason to
  review by diff, and to pin a worktree if a machine must do both.
- **The budget test enforced 250 while the spec says 217.** Round four lowered
  the number everywhere except the test that enforces it. Found while reading my
  own diff, not by a reviewer. `install.sh` is 212.
- **Two round-four findings that were "not actioned" were right.** The missing
  `--host` operand and the unquoted restore command. Both fixed in round five.
- **`REVIEWER_TIMEOUT` does not reach `run-plan-review.sh`** — it reads
  `REVIEW_TIMEOUT`. That is why opencode timed out at 180s in round six.

## Files modified

- `install.sh` — 212 executable lines, shellcheck clean
- `tools/install.test.sh` — 49 cases; budget corrected to 217; three new cases
  under task 8.8, each proven RED without its fix
- `openspec/changes/core-installer-one-entry-point/` — `CODE-REVIEW.md` and
  `SECURITY-REVIEW.md` are new; `spec.md`, `design.md`, `tasks.md`, `REVIEWS.md`
  updated
- `docs/evidence/install-run-after.md` — new
- `.gitignore` — `.gstack/` (security reports stay local)

## Round seven, and where the reviewing stopped

Run because round six amended normative text no reviewer had read. gemini
APPROVE, codex REQUEST-CHANGES, **opencode REQUEST-CHANGES — and opencode
counted for the first time**, because the timeout knob is `REVIEW_TIMEOUT`, not
`REVIEWER_TIMEOUT`. Six rounds of its opinion went to that typo.

opencode read the script instead of the prose and found that Decisions still
claimed `install-project-hooks.sh` rewrites the manifest in full so the stale
`normalize-claude-md.sh` row disappears — **disproved at round three, corrected
in the Impact section then, and left standing here**, in a document whose
declared failure mode is stale artifacts, after a real run that had already
falsified it. Also fixed: `--project` asserted as deferred, superseded and a
Phase 5b precondition in three places; wiring-era `SHALL`s about configuration
blocks and serialisers; round six's own scenario conflict; the host prefix set
enumerated (`codex-`, `opencode-`); and pi's fifth directory recorded.

Donald called it there rather than running round eight. The reasoning was that
the code had not changed since round five — rounds six and seven were spec and
prose coherence only — and every outstanding item is a dispositioned
carry-forward. Specs are current truth and get amended after archive.

## The mistake I made, and undid

`git add -A` in the archive commit (`925481a`) swept in three untracked
leftovers nobody chose: six `.claude/skills/gitnexus/` skill directories,
**a 44-line GitNexus section appended to core's own `CLAUDE.md`** telling agents
to run `npx gitnexus analyze`, and five `.planning/skill-observations/` files —
the notes the handoff had just said were Donald's call to delete.

Undone in `8e7eaec`: `CLAUDE.md` restored, tracking removed, both paths added to
`.gitignore` so a blanket add cannot reinstate them. The files stay on disk.
**The gitnexus skills still load in this repo until deleted from disk**, which is
a separate decision and has not been taken.

The lesson is narrower than "don't use `-A`": a blanket add cannot tell the work
from whatever else is lying around, and this repository is one where "whatever
else is lying around" includes removed software and instruction text.

## The payload is not one payload yet

Measured after the archive, across the fleet:

| Repo | family | `agentic-apps-workflow` copy |
|---|---|---|
| agenticapps-dashboard | agenticapps | 331 lines, v3.2.0 |
| agenticapps-roadmap | agenticapps | 324 lines, v3.2.0 |
| agents-task-viewer | agenticapps | 324 lines, v3.2.0 |
| dashboard-add-agent-board | agenticapps | **415 lines, v3.0.0** |
| callbot | factiv | 324 lines, v3.2.0 |
| cparx | factiv | 324 lines, v3.2.0 |
| fbc-platform | factiv | **346 lines, v3.2.0** |
| fx-signal-agent | factiv | 324 lines, v3.2.0 |

Core ships **235 lines, v4.0.0**. Every one of those is a committed directory in
`.claude/skills/`, not a symlink — **four distinct byte-sizes across two claimed
versions**, and `fbc-platform` differs from its three v3.2.0 siblings while
claiming to be them. Each repo also carries six copied `openspec-*` skills;
core carries those six too.

So the answer to "did we remove the project-specific claude workflows" is **no**.
The install run bound host directories; project `.claude/skills/` is a different
surface and `--project`, the mode that would have reached it, is superseded.
Which skill loads in those repos is loader ordering between the project copy and
the new core symlink — the condition core's own `CLAUDE.md` says not to leave to
chance, now live in eight repositories.

Neither `factiv-website` nor `factiv-design-system` is a workflow project.
`.planning/` also survives in `cparx`, `fbc-platform` and `fx-signal-agent`, with
a **tracked** `config.json` in the latter two.

## Next session: start here

Donald asked for a proposal on the project-local skill copies, and it is being
drafted now — that is the live work. Three candidates were on the table and this
is the one that matters most, because the other two are deferrals while this is a
payload that was published and then shadowed in eight repositories.

The other two, in order after it:

- `one-enforcement-floor` has **no plan review at all** (its task 8.2) and no
  code, which is when a plan review is cheapest:
  `run-plan-review.sh one-enforcement-floor --implementing-host claude`, with
  `REVIEW_TIMEOUT=600` so opencode counts.
- The check-mode follow-up: four reporting gaps have accumulated in one mode
  (open question 1), which is the argument for one change rather than four
  amendments.

## Open questions

1. **Four check-mode gaps, all reported rather than silent.** `--check` calls a
   host bound on the strength of one of two skills; reports a binding into an
   archived checkout as plain `bound`; never reports core's pre-commit hook,
   which is the bare-run postcondition; and has no defined exit status for an
   absent, stale, modified or unreadable artifact. Check-mode reporting is the
   first deferrable item in the declared order, so every one of these is a
   legitimate deferral — but four in one mode is a change asking to be written.
2. **`is_archived` matches link text, not the resolved target**, and ownership is
   a repository-name substring. Both want a portable `realpath`; they are the
   same dependency and should land together.
3. **Reported paths still carry `/Users/donald` and are unescaped.** Third time
   raised, third time deferred to `screen-review-egress`. It has a home; it is
   just not there yet.
4. **`workflow.mmd` still says the gate requires "REVIEWS ≥ 2".** Untrue since
   gate 2.0.0. Probably belongs with `one-enforcement-floor`, which is the change
   that moves the gate.
5. **Does `AGENTS.md` still need a workflow section** once the skill carries the
   workflow? `host-neutral-instruction-files` says yes. Still deliberately open.
6. **`~/.config/opencode/rules/gsd-oc-work-hard.md`** is still a live global rule
   file reaching opencode, left over from GSD.
7. **`.planning/` is answered**: nothing automated writes it. Past sessions wrote
   their commitment blocks there by hand, into a directory that was deleted
   fleet-wide on 2026-08-05. Neither skill mentions it. Safe to delete — not
   deleted, because they are notes and that is Donald's call.
8. **PRs #87 and #88 remain open**, as do the five fleet PRs. This work sits on
   top of them and nothing has been pushed this session.
9. **pi reads a fifth directory.** `~/.pi/agent/skills` is loaded by pi and is
   neither bound nor swept by the installer, so a binding into an unmaintained
   checkout placed there survives both the sweep and the negative test written to
   catch exactly that. Measured before it was accepted: 25 entries, all relative
   symlinks into `~/.agents/skills`, none archived. Real gap, currently empty.
10. **`REVIEWER_TIMEOUT` does not reach `run-plan-review.sh`.** It reads
   `REVIEW_TIMEOUT`. Worth reconciling the two names in `reviewer-cli.sh` and
   `run-plan-review.sh`, because the failure mode is silent: a reviewer times out
   and is simply not counted.
