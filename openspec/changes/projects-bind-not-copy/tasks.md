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
- [ ] 1.5 **pi reads `~/.pi/agent/skills`, which the installer does not bind.**
      It holds **26** skills symlinked to `~/.agents/skills/` — not empty, which
      an earlier revision claimed on the handoff's unverified word. Only
      `agentic-apps-workflow` is absent. **Decided:** this capability is scoped
      to hosts whose skill directory the installer binds, so pi is out of scope
      until binding it lands as a `workflow-installation` change. Record that a
      pi session in a swept repository will resolve no workflow skill
- [ ] 1.6 **Measure precedence per host, not once.** Task 1.1 validates one
      loader; the requirement's scenarios are host-parametric and pi already
      proves the hosts differ. Either measure on each host whose directory is
      bound, or state which hosts the claim covers

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

## 2b. RED: the second pass, for hooks

`check-shims.sh` iterates `SHIMMED-HOOKS` and asks whether each declared hook is
bound. It cannot ask what is bound that is not declared, which is why it reported
a clean fleet on 2026-08-06 while six repositories bound `normalize-claude-md`.

- [ ] 2b.1 A pass over each declared repository's `.claude/hooks/` **and** its
      `.claude/settings.json`, reporting any fleet-shared hook `SHIMMED-HOOKS`
      does not name. Both surfaces, because a shim file with no settings entry is
      dead weight and a settings entry with no shim file is a broken hook
- [ ] 2b.2 RED: it reports `normalize-claude-md` in all six repositories that
      bind it, and exits non-zero — dashboard, roadmap, callbot, cparx,
      fbc-platform, fx-signal-agent. **Not** `agents-task-viewer`, which does not
      bind it; an earlier revision said seven and counted the worktree
- [ ] 2b.3 RED: a repository binding exactly the declared set is reported
      conformant by both passes
- [ ] 2b.4 RED: one clean pass does not suppress the other's finding — a
      repository correct on hooks and wrong on skills is reported wrong
- [ ] 2b.5 A hook the fleet never declared and never installed is not reported.
      The criterion is fleet-shared provenance, not "every hook in the
      directory" — a project's own hooks are its business. Note that
      `SHIMMED-HOOKS` is empty after 3.9b, so membership can no longer be the
      test; the pass asks whether a *fleet-shared* hook is bound at all
- [ ] 2b.6 **An empty declaration does not print the conformance sentence.**
      Verified defect: `check-shims.sh:34` reads the declaration through
      `sed … 2>/dev/null | awk 'NF'`, so an absent file and an empty one are
      indistinguishable, and with zero declared hooks the forward loop never
      runs, `bad` stays 0, and line 91 prints "Every declared hook is bound with
      the authority's bytes" and exits 0. This change creates that state at
      3.9b, so it fixes it: empty reports that nothing was checked, absent is an
      error, and neither claims conformance
- [ ] 2b.7 The reverse pass identifies a fleet hook by its shim resolving an
      implementation under `~/.agenticapps/bin/`, not by declaration membership
      — which is empty after 3.9b and cannot discriminate. RED: a project's own
      unrelated `PostToolUse` hook is not reported
- [ ] 2b.8 Retired hook names are kept as **tombstones** in the declaration, so
      a stale `normalize-claude-md` binding is reported as retired rather than
      becoming indistinguishable from a project-authored hook
- [ ] 2b.9 A sanctioned-transition entry exists for the interim in which a hook
      is retired in core and still bound in repositories. Retirement across nine
      per-repo PRs cannot be atomic, so the check needs a way to say "extra, and
      deliberate, until this lands" — the `OPT-OUTS` axis, kept rather than
      dissolved

## 3. Sweep the fleet

One PR per repository, each stating the skill, the version the copy claimed, and
the version now resolved.

`agenticapps-dashboard-add-agent-board` is a worktree and **not** a fleet
member, so it gets no `FLEET` entry — but it is swept and checked **in its own
right**, not "handled with its parent", which is what an earlier revision of
this line said and which task 3.12 then contradicted. It sits on its own branch
with the oldest copy on the machine, so cleaning the dashboard's main checkout
changes nothing about it.

Discovery is the unresolved part and it is a task, not an assumption:
`check-shims.sh:44` resolves a repository with
`find "$root" -maxdepth 2 -type d -name "$name" | head -1` — first match wins,
so it cannot see a second checkout of the same repository at all. Worktrees have
to be enumerated (`git worktree list` from each resolved repository is the
obvious mechanism) or they are invisible by construction. Note the trap this
sets with the removability rule: once retired `agenticapps-dashboard` leaves
`FLEET`, a worktree discovered only *via* its parent becomes undiscoverable.

- [ ] 3.1 `agenticapps-roadmap` (324 lines, v3.2.0)
- [ ] 3.2 `agents-task-viewer` (324 lines, v3.2.0)
- [ ] 3.3 `agenticapps-dashboard` (331 lines, v3.2.0) — retired, and swept anyway
      for the reason in `design.md`
- [ ] 3.4 `callbot` (324 lines, v3.2.0)
- [ ] 3.5 `cparx` (324 lines, v3.2.0)
- [ ] 3.6 `fx-signal-agent` (324 lines, v3.2.0)
- [ ] 3.7 `fbc-platform` (346 lines, v3.2.0) — last, and only after 1.3 has said
      what its extra 22 lines were
- [ ] 3.8 Each PR removes `.claude/skills/agentic-apps-workflow/` **and** the
      `.claude/settings.json` hook surface: the `openspec-change-gate` and
      `normalize-claude-md` entries with their shim files. The `openspec-*`
      skills stay, and a PR that touches them is wrong
- [ ] 3.9 **`database-sentinel` is removed with the surface — decided
      2026-08-07, no longer an open question.** Each PR removes its
      `.claude/settings.json` entry and its shim alongside the others. The
      decision and its cost are argued in `proposal.md`; the short form is that
      its destructive-SQL arms are a real loss that no other surface replaces,
      and it goes anyway because it reaches one host of five
- [ ] 3.9a Remove `database-sentinel` from `SHIMMED-HOOKS`, and delete
      `reference-implementations/project-hooks/database-sentinel.sh`
- [ ] 3.9b `SHIMMED-HOOKS` is then **empty** — both entries are gone, since
      `openspec-change-gate`'s project binding goes with the surface too.
      Confirm the file survives as an empty declaration rather than being
      deleted: the reverse pass reads it, and an absent file and an empty one
      must not mean the same thing
- [ ] 3.9c Record the reassigned protection in the operator's host permission
      configuration — a Bash deny rule for `DROP TABLE`, `TRUNCATE TABLE` and
      `DELETE` without `WHERE`. This is host-specific by nature and therefore
      **not** core's to ship; the task is to write it down where the operator
      will find it, not to install it from here
- [ ] 3.9d **The deny rule exists and is verified before 3.9 deletes the hook,
      or the loss is recorded as unmitigated.** Both reviewers made this point
      and it is fair: a change that demands "verified rather than assumed"
      cannot discharge its own mitigation with a document. Either the rule is in
      place and demonstrated to block `DROP TABLE`, or the change states plainly
      that the only irreversible-action interception was removed with nothing
      replacing it. "Reassigned" is not a third option
- [ ] 3.10 **The git floor must exist before the gate shim is removed.** In
      `cparx` there is no `.git/hooks/pre-commit` and `core.hooksPath` is unset,
      so removing the `PreToolUse` entry today leaves that repository with no
      gate at all rather than with a better one. `one-enforcement-floor` is what
      supplies the floor, so it lands first — a second sequencing constraint,
      stated like the first
- [ ] 3.11 `agents-task-viewer` and core already bind neither
      `normalize-claude-md` nor its shim — confirmed 2026-08-07 for
      `agents-task-viewer`; confirm core rather than assume
- [ ] 3.12 **`agenticapps-dashboard-add-agent-board` is swept in its own right,
      not by its parent.** It is a linked worktree on its own branch carrying the
      oldest copy on the machine — 415 lines, v3.0.0. Cleaning the dashboard's
      main checkout changes nothing about it, and a check resolving only the
      first directory matching the repository name would report it clean while
      the stale skill still loads there
- [ ] 3.13 `FLEET` names retired `agenticapps-dashboard`. Decide now whether the
      name stays after its checkout is eventually deleted, and make removal
      possible with a recorded reason — otherwise "report, never skip" fails the
      check forever the day that directory goes

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
- [ ] 6.3 `docs/HOW-IT-FITS-TOGETHER.md` is internally inconsistent: it says one
      gate at two surfaces, git pre-commit and CI, and then describes projects
      binding it at a third. Reconcile it against what this change leaves behind
- [ ] 6.4 **Superseded — kept for the record.** This asked whether the project
      `PreToolUse` gate is worth keeping and deferred it to
      `one-enforcement-floor`. It is answered here instead: the surface is
      Claude-only, which is the reason the host hook was deleted, so the question
      was already decided and only its scope was missed. Original text: verified
      at source
      (`openspec-change-gate.sh:506`): `gate_check` returns 0 with no active
      change. That is the measurement `one-enforcement-floor` used to delete the
      *host* hook, and it holds identically for the project one — same
      implementation, reached through a shim. What the project hook has that the
      host one did not is a repository with `openspec/` in it, so an active
      change is likelier and it buys in-session latency over `git commit`. That
      is the whole of what it buys. **The question belongs to
      `one-enforcement-floor`**, which is the change reasoning about enforcement
      surfaces and which has no plan review yet — the cheapest possible moment to
      put it. Not decided here
- [ ] 6.4 Every fleet project still carries a
      `setup-gstack-gsd-superpowers-workflow.md` slash command offering to
      install GSD, removed on 2026-07-28 — 133 lines in `cparx`. Same class as
      the skill copies and not swept by this change, because a command is neither
      a skill nor a hook and widening the check to "anything stale under
      `.claude/`" is a different rule needing its own argument
