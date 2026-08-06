# Session Handoff — 2026-08-06 (ninth session)

**The real run happened and it is verified.** Every task in
`core-installer-one-entry-point` is closed. The one thing left is the archive,
gated on round seven's verdict — see the bottom.

Branch `feat/one-skills-payload`, four commits this session, all green.

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

## Next session: start here

**Read the round-seven verdicts first** — they were still running when this was
written, in `REVIEWS.md`. Round seven exists because round six amended normative
text (the preservation `SHALL`, the consent exception) that no reviewer had
read, and codex had asked for a re-review before archive. Donald chose to run it.

If it is clean, **archive** — `/opsx:archive core-installer-one-entry-point` —
which unblocks `one-enforcement-floor`. If it finds something, fix it the way
rounds five and six were fixed: verify against the code first, then act.

After the archive, `one-enforcement-floor` still has no plan review (its task
8.2), and it has no code, which is when a plan review is cheapest.

## Open questions

1. **Two check-mode gaps, both now reported rather than silent** — `--check`
   calls a host bound on the strength of one of two skills, and it reports a
   binding into an archived checkout as plain `bound`. The spec makes check-mode
   reporting the first deferrable item, so deferring is legitimate; they should
   be done together.
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
