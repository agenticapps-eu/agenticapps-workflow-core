# Session Handoff — 2026-08-07 (sixteenth session)

**Publish and bind landed, then round two of plan review found that three of
this change's own guards did not hold.** Three commits on
`feat/projects-bind-not-copy` (PR #89). Working tree clean, `openspec validate
--all` 14/14, all three suites green.

| Change | State |
|---|---|
| `fresh-clone-needs-nothing` | §3, §4, §9 built and installed. §1, §2, §5, §6 open |
| `one-enforcement-floor` | **§2's publish/bind and 3.2 done; §9 holds ten findings that need decisions, not patches** |
| `projects-bind-not-copy` | reviewed ×2, no code |
| `diagram-is-the-surface` | reviewed ×2, no code |
| `fleet-carries-only-current` | **never reviewed**, seven sessions old |

## Accomplished

- `9b322fc` — **the floor binder**, `bind-global-floor.sh` + 18 tests. Closes
  2.1, 2.2, 2.3, 2.4, 3.2. Decision 4's swap landed 217 → 217 as predicted.
- `115d594` — **round two of plan review, and its three verified fixes.**
  gemini APPROVE, codex REQUEST-CHANGES ×7, opencode REQUEST-CHANGES ×8.
- **opencode completed at `REVIEW_TIMEOUT=420`.** The 180s default was the whole
  reason it timed out last round. Three vendors on the record; question closed.
- `install.test.sh` 53/0, `global-floor.test.sh` 18/18,
  `global-floor-bind.test.sh` 18/18, `install.sh` 217, shellcheck clean.

## Decisions

- **Three guards were wrong and their ticks were wrong.** Recorded against the
  tasks that carried them rather than quietly re-ticked:
  - 2.8a's predicate read system and global scope, so one `--global` key
    enrolled the whole machine — the measured defect it was built to remove,
    reintroduced by the predicate. It also ignored the value, so `false`
    enrolled. Now `--local --type=bool`.
  - 2.7's prohibition was defeated by **one symlink** in `hooks.d`, and the
    suite did not notice. Demonstrated end to end before the fix and re-run
    against the same fixture after. `global-floor-version` 1.0.0 → 1.1.0.
- **Everything was verified in a sandbox before being written up.** Two of the
  three reviewer claims were exactly right; the budget claim (9.9) was half
  wrong and is recorded as half wrong.
- **Ten findings recorded, not patched.** Each needs a decision. Patching them
  inside a review round is how a plan gets edited to match code.
- The `cso` gate ran scoped to the diff, not as the full gstack workflow, whose
  preamble writes telemetry and CLAUDE.md routing config unasked.

## Files modified

- `reference-implementations/global-floor/bind-global-floor.sh` — new, the binder
- `reference-implementations/global-floor/pre-commit` — enrolment scope + value,
  canonical entry resolution, version 1.1.0
- `tools/global-floor-bind.test.sh` — new, 18 cases
- `tools/global-floor.test.sh` — 13 → 18 cases
- `install.sh` — `COREHOOKS` → `FLOORBIND`, the call site, one comment
- `tools/install.test.sh` — `GIT_CONFIG_GLOBAL` isolation, 16 stubs retargeted,
  three cases rewritten around the new level
- `.../tasks.md` — §2 closed out; **new §9** with the round's ten open findings
- `.../specs/workflow-installation/spec.md` — the published-directory requirement
- `.../REVIEWS.md` — round two, three vendors

## Next session: start here

**9.4 is settled as design Decision 5** — the migration enrols, verifies the
binding governs the repository by *resolving its hooks directory*, then removes.
Normative requirement + five scenarios, so it survives archival. Two corrections
fell out: the migration set is **four, not nine** (0.3a), and 3.1's predicate
was wrong — "the binding is live" is a fact about the machine, "the binding
governs this repository" is a fact about the repository, and a local
`core.hooksPath` makes those different in five repositories today.

**Next is 2.9's preflight, and 9.4a is the reason it comes before 2.8b/2.8c.**
Three things now want an operator acceptance — what the binding will newly
govern, what publishing will replace (2.1a), and what will be enrolled (9.4) —
and they must be **one** report and one acceptance rather than three that have
to agree with each other. Build it as one.

Then 9.5 (the unwind clause contradicts its own ordering — confirmed unreachable
while implementing 2.1), 9.13, 2.8c, 2.8b.

**`core.hooksPath` is still unset on this machine and `./install.sh` has not been
run.** Unchanged, and 9.4 is now a second reason to hold.

**Step 4's code review on the diff has still not happened.** §07 independence
means a cleared session, not a subagent. Two commits of shipped code are waiting
on it, and this round is evidence that the plan reviewers do not catch what a
diff reader would — they found the enrolment scope from the *snippet in
design.md*, and missed the symlink hole entirely until the spec's own
requirement was checked against the code.

## Open questions

1. **§9 holds the review findings** with the reasoning. 9.4 is now closed;
   still open and highest-consequence: 9.6 (binding activates every hook type in
   the published directory, generalising 2.1a), 9.11 (the
   `core-self-enforcement` contradiction), 9.13 (3.5 is live and collides with
   the sweep — core's only possible binding value is exactly the value 3b.2
   classifies as redundant, so the sweep would unset it).
2. **The delta changed again after the reviewers read it**, and this time it is
   not drift: 9.4's requirement is the fix codex explicitly asked for
   ("specify and test enrolment-before-removal with rollback on failure"). The
   digest is stale, and the honest reading is that round three should wait until
   the rest of §9 is decided rather than fire per finding.
2. **`fleet-carries-only-current` still never reviewed** — seven sessions old,
   flagged at every commit. Now demonstrably cheap: 420s and three vendors.
3. **§18's version number** — still blocking a task in `diagram-is-the-surface`.
4. **Machine-level *commands* unconfirmed.** Skills are confirmed; this repo's
   `.claude/commands/opsx/` shadows the global one. Test in a repo with no
   `.claude/`.
5. **pi's opsx commands unreachable by symlink** — needs a pi package.
6. **CodeRabbit still has not reviewed anything here.**
