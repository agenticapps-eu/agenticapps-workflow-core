## 1. Measure before deleting

The design rests on a claim about loader precedence that has not been observed
for this pair on this machine. Nothing below runs until it has been.

- [ ] 1.1 Establish which `agentic-apps-workflow` a session in one of the eight
      repositories actually loads — the project copy or the host binding. Record
      the evidence, not the conclusion
- [ ] 1.2 If the host binding wins, stop and re-open the proposal: the copies are
      inert, the argument for removing them survives and the urgency does not,
      and a change written on the other premise should not be executed on this one
- [ ] 1.3 Read `fbc-platform`'s copy against the three byte-identical v3.2.0
      siblings and record what differs. A local edit someone made on purpose is
      not a duplicate to collapse
- [ ] 1.4 Confirm each of the eight repositories is otherwise clean: no second
      copy under another name, and no `skills/` entry of core's shadowed by a
      differently-named directory

## 2. RED: the check, before the sweep

The check exists so the sweep cannot be undone quietly. It is written first so it
fails against the fleet as it stands, which is the only way to know it detects
the condition rather than the absence of it.

- [ ] 2.1 `tools/check-project-skills.sh <root>` — resolve each repository named
      in `FLEET` beneath `<root>`, and report a name that resolves nowhere rather
      than skipping it
- [ ] 2.2 RED: it reports every repository currently holding a copy, by
      repository and skill name, and exits non-zero
- [ ] 2.3 RED: a project skill core does **not** publish is not reported. Assert
      this with the six `openspec-*` skills, which is the case that exists —
      a check that flags them breaks `/opsx:*` in every repository
- [ ] 2.4 RED: a repository named in `FLEET` but absent from `<root>` is reported
      unresolved, and the run does not report success for it
- [ ] 2.5 RED: the clean case exits zero and states which root it examined
- [ ] 2.6 A test suite for the above, against a scratch root — no case touches a
      real repository

## 3. Sweep the fleet

One PR per repository, each stating the skill, the version the copy claimed, and
the version now resolved. `agenticapps-dashboard-add-agent-board` is a worktree,
not a fleet member, and is handled with its parent.

- [ ] 3.1 `agenticapps-roadmap` (324 lines, v3.2.0)
- [ ] 3.2 `agents-task-viewer` (324 lines, v3.2.0)
- [ ] 3.3 `agenticapps-dashboard` (331 lines, v3.2.0) — retired, and swept anyway
      for the reason in `design.md`
- [ ] 3.4 `callbot` (324 lines, v3.2.0)
- [ ] 3.5 `cparx` (324 lines, v3.2.0)
- [ ] 3.6 `fx-signal-agent` (324 lines, v3.2.0)
- [ ] 3.7 `fbc-platform` (346 lines, v3.2.0) — last, and only after 1.3 has said
      what its extra 22 lines were
- [ ] 3.8 Each PR removes only `.claude/skills/agentic-apps-workflow/`. The
      `openspec-*` skills stay, and a PR that touches them is wrong

## 4. GREEN, and the declaration

- [ ] 4.1 `tools/check-project-skills.sh ~/Sourcecode` exits zero across the
      declared fleet
- [ ] 4.2 Every repository that carried a copy is named in `FLEET`, or the
      omission is corrected there rather than special-cased in the check
- [ ] 4.3 `openspec validate --all` green; core's own suites green

## 5. Verify on the machine, not in the tests

- [ ] 5.1 Open a session in a swept repository and confirm the workflow skill
      loads and resolves into core — the same measurement as 1.1, after
- [ ] 5.2 Confirm no repository lost a capability: the `/opsx:*` commands still
      work in a swept repository, which is the concrete form of "the `openspec-*`
      skills were left alone"
- [ ] 5.3 Plan review before code, per §07, with `REVIEW_TIMEOUT=600` so opencode
      counts. `REVIEWER_TIMEOUT` does not reach `run-plan-review.sh`
- [ ] 5.4 Code review on the diff once the check exists
- [ ] 5.5 Confirm this change's branch does not merge before the branch carrying
      the host binding — the dependency in `design.md`

## 6. Hand off what this change does not do

- [ ] 6.1 Bootstrapping a fresh project still has no installed successor to
      `setup-agenticapps-workflow`. This change removes copies; it does not open
      or close that window, and it should not be read as having done either
- [ ] 6.2 `.planning/` survives in `cparx`, `fbc-platform` and `fx-signal-agent`,
      with a **tracked** `config.json` in the latter two, after a fleet-wide
      deletion on 2026-08-05 that did not complete. Adjacent, not this change —
      recorded so the next sweep does not rediscover it
