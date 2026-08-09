## 1. Measure before deleting

The design rests on a claim about loader precedence that has not been observed
for this pair on this machine. Nothing below runs until it has been.

**Measured 2026-08-07. Evidence in `MEASUREMENT.md`, which is the record this
section demanded — read it before acting on any conclusion restated here.**

- [x] 1.1 Establish which `agentic-apps-workflow` a session in one of the **seven**
      repositories actually loads — the project copy or the host binding. Record
      the evidence, not the conclusion.
      **Result: it depends on the host, and on opencode it is not stable.**
      *Corrected: seven repositories, not eight. `FLEET` names seven and core
      carries no copy. The eighth is the same worktree-shaped miscount that
      produced "seven bind `normalize-claude-md`" when the answer was six.*
- [ ] 1.2 If the host binding wins, stop and re-open the proposal: the copies are
      inert, the argument for removing them survives and the urgency does not,
      and a change written on the other premise should not be executed on this one.
      **Fires partly.** On Claude (4 of 4 repositories) and codex the binding
      wins and the copies are inert, so the urgency does not survive there. On
      opencode the project copy wins in some sessions and loses in others — so
      on one of three bound hosts the copies are live. The proposal is re-opened
      on that basis, not closed; see 1.7
- [x] 1.3 Read `fbc-platform`'s copy against the **five** byte-identical v3.2.0
      siblings and record what differs. A local edit someone made on purpose is
      not a duplicate to collapse.
      *Corrected twice: **five** siblings share `d95f20c0…` (roadmap,
      agents-task-viewer, callbot, cparx, fx-signal-agent), not three. And
      fbc-platform is **not** the only outlier — `agenticapps-dashboard` carries
      a third variant at 331 lines, matching the size global `CLAUDE.md`
      attributes to the archived `claude-workflow/skill`. A task that names one
      outlier would have swept the other without looking at it.*
- [ ] 1.4 Confirm each of the **seven** repositories is otherwise clean: no second
      copy under another name, and no `skills/` entry of core's shadowed by a
      differently-named directory.
      *Partly done: four repositories carry a stale `SKILL.md.pre-0034` beside
      the live file — roadmap, agents-task-viewer, callbot, fx-signal-agent.
      The rest of this check is still outstanding*
- [x] 1.5 **pi reads `~/.pi/agent/skills`, which the installer does not bind.**
      It holds **25** skills symlinked to `~/.agents/skills/`, and
      `agentic-apps-workflow` is absent. **Decided:** this capability is scoped
      to hosts whose skill directory the installer binds, so pi is out of scope
      until binding it lands as a `workflow-installation` change.
      *Corrected: the regression this task told us to record does not exist. No
      fleet repository has a copy in `.pi/skills` either — those directories hold
      the same six `openspec-*` skills. A pi session resolves no workflow skill
      **today**, before any sweep, so the sweep takes nothing from pi. The
      earlier framing charged this change for a gap it does not cause*
- [x] 1.6 **Measure precedence per host, not once.** Task 1.1 validates one
      loader; the requirement's scenarios are host-parametric and pi already
      proves the hosts differ.
      **Done, and the hosts do differ.** Claude: binding wins, stable. Codex:
      binding wins, uncontested — no fleet repository has a `.codex` copy at all.
      opencode: see 1.7. pi: unbound, nothing competes
- [ ] 1.7 **On opencode the winner is a race, and this replaces the argument the
      proposal makes.** opencode reads four directories carrying the name — the
      three global symlinks plus the project's own `.claude/skills` — and its
      logs show each collision replacing the last, so the directory scanned last
      wins. The scan order differed in all six repositories captured, and three
      consecutive runs in `cparx` loaded v3.2.0, v4.0.0, v3.2.0.
      Rewrite the proposal's case around this: a copy that reliably loses is
      untidy, but a copy that wins in half of sessions means the fleet runs two
      workflow versions non-deterministically with no way to tell which from
      inside the session. Deleting the copies collapses every ordering to v4.0.0,
      which is what makes it a fix rather than a reshuffle

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
- [x] 2b.6 **An empty declaration does not print the conformance sentence.**
      Verified defect: `check-shims.sh:34` reads the declaration through
      `sed … 2>/dev/null | awk 'NF'`, so an absent file and an empty one are
      indistinguishable, and with zero declared hooks the forward loop never
      runs, `bad` stays 0, and line 91 prints "Every declared hook is bound with
      the authority's bytes" and exits 0. This change creates that state at
      3.9b, so it fixes it: empty reports that nothing was checked, absent is an
      error, and neither claims conformance
      **Built 2026-08-08**, `tools/check-shims.sh` + a new
      `tools/check-shims.test.sh` (9 cases, RED before GREEN). Absent and empty
      are now distinguished before the read, because after it they are the same
      empty string: absent exits 65 naming the file, empty reports that nothing
      was checked and withholds the conformance sentence. Verified against the
      real fleet — exit 0, no conformance claim.
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

- [x] 3.1 `agenticapps-roadmap` (324 lines, v3.2.0)  — **not swept: the checkout was deleted from this machine on 2026-08-08** and the remote is archived.
- [x] 3.2 `agents-task-viewer` (324 lines, v3.2.0)  — **swept 2026-08-08**, rides PR #19.
- [x] 3.3 `agenticapps-dashboard` (331 lines, v3.2.0) — retired, and swept anyway
      for the reason in `design.md`  — **not swept: checkout deleted 2026-08-08.**
- [x] 3.4 `callbot` (324 lines, v3.2.0)  — **swept 2026-08-08**, rides PR #101.
- [x] 3.5 `cparx` (324 lines, v3.2.0)  — **swept 2026-08-08**, PR #130, which also collapsed two divergent instruction files into one.
- [x] 3.6 `fx-signal-agent` (324 lines, v3.2.0)  — **swept 2026-08-08**, PR #132.
- [x] 3.7 `fbc-platform` (346 lines, v3.2.0) — last, and only after 1.3 has said
      what its extra 22 lines were  — **swept 2026-08-08**, PR #143. Also removed husky, whose local `core.hooksPath` was what kept the floor out; `ci.yml:24-25` already runs lint and typecheck.
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
- [x] 3.9a Remove `database-sentinel` from `SHIMMED-HOOKS`, and delete
      `reference-implementations/project-hooks/database-sentinel.sh`
      **Done 2026-08-08 for the DECLARATION.** `SHIMMED-HOOKS` no longer names
      it and says why. The reference implementation itself is NOT yet deleted —
      see the note on 3.9b.
- [x] 3.9b `SHIMMED-HOOKS` is then **empty** — both entries are gone, since
      `openspec-change-gate`'s project binding goes with the surface too.
      Confirm the file survives as an empty declaration rather than being
      deleted: the reverse pass reads it, and an absent file and an empty one
      must not mean the same thing
      **Done 2026-08-08 — and it empties `ARTIFACTS` too, which the task did
      not anticipate.** `ARTIFACTS` declares only `database-sentinel`, so
      deleting the implementation leaves `install-project-hooks.sh` with nothing
      to publish and the whole publish/shim/check subsystem without a subject.
      That is a larger consequence than a file removal and it is unowned: 24
      references across `project-hook-shim.test.sh` and `install.test.sh` plus
      the whole of `project-hooks.test.sh` are about this one artifact. Decide
      whether the subsystem is retired with it before deleting the file.
      **DECIDED 2026-08-09: the publish half is retired, the bind half is kept.**
      Only one of the two lost its subject. `check-shims.sh` reads
      `SHIMMED-HOOKS`, `FLEET`, `OPT-OUTS` and `shim-template.sh` and exits 65
      without the template, so the bind half is driven by live code that landed
      on `main` in PR #94; `install-project-hooks.sh` with an empty `ARTIFACTS`
      dies at line 122 and is called only by `install.sh:25`. The argument and
      the three manifest measurements are in `design.md` under "The publisher is
      retired and the checker is kept". Carried out by group 3.13 below.
- [ ] 3.9c Record the reassigned protection in the operator's host permission
      configuration — a Bash deny rule for `DROP TABLE`, `TRUNCATE TABLE` and
      `DELETE` without `WHERE`. This is host-specific by nature and therefore
      **not** core's to ship; the task is to write it down where the operator
      will find it, not to install it from here
- [x] 3.9d **The deny rule exists and is verified before 3.9 deletes the hook,
      or the loss is recorded as unmitigated.** Both reviewers made this point
      and it is fair: a change that demands "verified rather than assumed"
      cannot discharge its own mitigation with a document. Either the rule is in
      place and demonstrated to block `DROP TABLE`, or the change states plainly
      that the only irreversible-action interception was removed with nothing
      replacing it. "Reassigned" is not a third option
      **Answered 2026-08-08, and the answer is the second one: THE LOSS IS
      UNMITIGATED.** 3.9c's mitigation is not expressible. The hook matched
      CONTENT — `DROP TABLE`, `TRUNCATE TABLE`, `DELETE` with no `WHERE`,
      case-insensitively, anywhere in a Bash command. Host permission deny rules
      match a command PREFIX (`Bash(psql:*)`), not a substring anywhere in the
      command, so there is no rule that expresses "any command containing DROP
      TABLE". The nearest expressible rule denies `psql` outright, which blocks
      every legitimate use and would be switched off within a day.
      So: the hook was removed from five repositories on 2026-08-08 and
      **nothing replaced it**. Commands that delete or drop tables are no longer
      intercepted before they run. This is recorded rather than softened,
      because the change's own requirement forbids describing the protection as
      preserved, and because a mitigation nobody can install is not a mitigation
- [x] 3.10 **The git floor must exist before the gate shim is removed.** In
      `cparx` there is no `.git/hooks/pre-commit` and `core.hooksPath` is unset,
      so removing the `PreToolUse` entry today leaves that repository with no
      gate at all rather than with a better one. `one-enforcement-floor` is what
      supplies the floor, so it lands first — a second sequencing constraint,
      stated like the first
      **Satisfied 2026-08-08**: `core.hooksPath` is bound globally to
      `~/.agenticapps/git-hooks`, six repositories are enrolled, and each was
      verified to invoke the gate before any project shim was removed.
- [ ] 3.11 `agents-task-viewer` and core already bind neither
      `normalize-claude-md` nor its shim — confirmed 2026-08-07 for
      `agents-task-viewer`; confirm core rather than assume
- [ ] 3.12 **`agenticapps-dashboard-add-agent-board` is swept in its own right,
      not by its parent.** It is a linked worktree on its own branch carrying the
      oldest copy on the machine — 415 lines, v3.0.0. Cleaning the dashboard's
      main checkout changes nothing about it, and a check resolving only the
      first directory matching the repository name would report it clean while
      the stale skill still loads there
- [x] 3.13 `FLEET` names retired `agenticapps-dashboard`. Decide now whether the
      name stays after its checkout is eventually deleted, and make removal
      possible with a recorded reason — otherwise "report, never skip" fails the
      check forever the day that directory goes

## 4. GREEN, and the declaration

      **Decided 2026-08-08: removed from `FLEET`**, together with
      `agenticapps-roadmap`. Both checkouts are off the machine and both remotes
      are archived, so a `MISSING REPO` line for either is noise rather than a
      finding.
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

## 3.13 Retire the project-hook publisher

Decided on 3.9b, argued in `design.md`. **RED before GREEN applies to a deletion
too**: each assertion below is written and observed failing against today's tree
before the file it names is removed, because a test written after the deletion
proves only that it can describe the present.

- [ ] 3.13a **Write the RED assertions first, and watch them fail.** Three
      claims, none of which holds today: `install.sh --check` reports no
      project-hook set; `install.sh` carries no `PROJHOOKS` delegation; and no
      manifest is written under `$HOME/.agenticapps/`. Add them to
      `tools/install.test.sh` alongside the cases they replace, run the suite,
      and record the failure count in this task before deleting anything
- [ ] 3.13b Delete `reference-implementations/project-hooks/database-sentinel.sh`
      and `reference-implementations/project-hooks/ARTIFACTS`. **3.9a's file
      half, unblocked** — the declaration half was done 2026-08-08
- [ ] 3.13c Delete `reference-implementations/shared-install/install-project-hooks.sh`
      and `tools/project-hooks.test.sh`. The suite is entirely about
      `database-sentinel`; it is deleted rather than narrowed because narrowing
      it leaves a file whose every case is about an absent artifact
- [ ] 3.13d Unwire `install.sh`: remove the `PROJHOOKS` variable (line 25), the
      delegation that publishes and attests the project-hook set, and whatever
      `--check` prints about it. The four shared artifacts keep publishing
      through `install-shared-artifact.sh`, which is a different helper and is
      not touched
- [ ] 3.13e Remove the project-hook cases from `tools/install.test.sh` — the 24
      references counted on 3.9b, including the `stub_helper` lines for the
      deleted installer and the manifest assertions at 567-571. **Read each one
      before deleting it**: a case that stubs the installer while asserting
      something else entirely is a case about `install.sh`, and it stays with its
      stub removed rather than going with the subsystem
- [ ] 3.13f Confirm the bind half still passes untouched: `tools/check-shims.test.sh`,
      `tools/project-hook-shim.test.sh`, `tools/bind-openspec-tools.test.sh`.
      **This is the assertion that the split was drawn in the right place.** Any
      failure here means a file was deleted that the checker reads, and the
      deletion is wrong rather than the test
- [ ] 3.13g Delete the machine copies: `~/.agenticapps/bin/database-sentinel.sh`
      and `~/.agenticapps/manifest.tsv`. Not a source change, so it is recorded
      here rather than inferred from the diff — and it is the step that makes the
      retirement true on the only machine that has this workflow. Verify
      afterwards that `./install.sh` and `./install.sh --check` both still exit 0
      with the manifest absent
- [ ] 3.13h Reconcile `reference-implementations/project-hooks/README.md`, 44k,
      which documents the publisher and the currency rules at lines 546 and 555.
      **Cut what described the publish half; keep what describes the shim
      contract**, which is still the authority `check-shims.sh` compares against
- [ ] 3.13i Re-run `openspec validate --all` and confirm the delta's eight
      REMOVED and two MODIFIED requirements match what was actually deleted. A
      requirement removed in the delta whose code survives, or code deleted with
      no delta entry, is the failure this task exists to catch
