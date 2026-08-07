## 0. Preconditions

- [ ] 0.1 `projects-bind-not-copy` is archived. This change reuses its sweep
      pattern, its declared-fleet resolution and its both-directions check, and
      starting first would mean building all three twice
- [ ] 0.2 Phase 5b's position is known. If the archived host checkouts are
      already deleted, three rows leave the inventory; if not, they stay out of
      scope and that is stated rather than assumed

## 1. Re-measure, because the inventory is dated

The table in `proposal.md` was measured on 2026-08-07 and this change executes
later. Every count below is a hypothesis until re-run.

- [ ] 1.1 Re-run the inventory across every repository in `FLEET`, and record it
      beside the 2026-08-07 numbers so the drift is visible rather than absorbed
- [ ] 1.2 For every path targeted for deletion, record tracked-file counts. This
      is the criterion, not the path name
- [ ] 1.3 Identify anything the 2026-08-07 sweep missed: another removed tool's
      artifacts, another command, another instruction fragment. The inventory was
      built by looking for what was known to be removed, which cannot find what
      nobody remembered removing

## 2. The safe half — untracked leftovers and removed-tool artifacts

Mechanical, reversible, and independent of the instruction-file work. One PR per
repository.

- [ ] 2.1 `setup-gstack-gsd-superpowers-workflow.md` (`cparx`, 133 lines) and
      `gsd-plan.md` / `setup.md` (`callbot`) — commands offering a tool removed
      on 2026-07-28
- [ ] 2.2 `backend-foundation.md` (`callbot`) — establish whether it belongs to a
      removed tool or is that project's own. **Only the former is in scope**, and
      guessing is how a project loses a command it wrote
- [ ] 2.3 `.claude/workflow-config.md` (7 repos) — pre-OpenSpec workflow config
- [ ] 2.4 `.claude/scheduled_tasks.lock` (5 repos)
- [ ] 2.5 `.claude/claude-md/` (5 repos) — fragments of the modular instruction
      scheme; confirm nothing still assembles from them before deleting
- [ ] 2.6 Untracked `.planning/` leftovers only, per the criterion in 1.2

## 3. `agenticapps-roadmap`, which is not a leftover

- [ ] 3.1 134 tracked files under `.planning/`. Establish what they are and
      whether that repository's planning has moved to `openspec/` or still lives
      there
- [ ] 3.2 Decide: migrate, or keep with a stated reason. **Do not delete.** Both
      outcomes are recorded in this change; an omission is not an outcome
- [ ] 3.3 If it blocks, defer that repository explicitly and report the deferral.
      Skipping a `FLEET` member silently is the failure the declaration exists to
      prevent

## 4. The risky half — instruction text

Last, because it is the only irreversible part.

- [ ] 4.1 Read the trigger skill against one repository's `## Coding Discipline`
      section and record, rule by rule, which the skill carries and which it does
      not
- [ ] 4.2 Any rule the skill does **not** carry stays in the repository and is
      reported. A rule that exists in eight places and then nowhere is a rule
      nobody decided to drop
- [ ] 4.3 Repeat per repository rather than assuming the eight sections are
      identical. Three copies of the workflow skill claimed one version and
      differed; there is no reason to expect better of hand-edited prose
- [ ] 4.4 Remove only what 4.1–4.3 justify, one PR per repository, each naming
      the skill section that now carries what it deleted

## 5. Make the rule hold

- [ ] 5.1 Extend `projects-bind-not-copy`'s second pass to report an artifact of
      a removed tool, so the next removal cannot leave the same residue
- [ ] 5.2 The extension needs a declaration of what "removed" means — a list of
      retired tool names that does not shrink when one is forgotten, in the shape
      of `ARTIFACTS` and `SHIMMED-HOOKS`
- [ ] 5.3 RED before GREEN, against a scratch root

## 6. Verification

- [ ] 6.1 `openspec validate --all` green; core's suites green
- [ ] 6.2 The check reports a clean fleet, and the run states which root it
      examined
- [ ] 6.3 Open a session in a swept repository and confirm nothing was lost: the
      workflow skill loads, `/opsx:*` works, the declared hooks still fire
- [ ] 6.4 Plan review before code, `REVIEW_TIMEOUT=600` so opencode counts
- [ ] 6.5 Code review on the diff — particularly section 4, where the diff is
      prose and a reviewer is the only check that exists
- [ ] 6.6 `cso`

## 7. Hand off

- [ ] 7.1 Record what was deliberately left: a stale README is not an artifact of
      a removed tool, and the boundary held or it did not. Say which
- [ ] 7.2 If `agenticapps-roadmap` was deferred, it is the first thing the next
      change picks up
