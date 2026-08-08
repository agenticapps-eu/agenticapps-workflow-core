## 0. Preconditions

- [ ] 0.1 `projects-bind-not-copy` is archived. This change reuses its sweep
      pattern, its declared-fleet resolution and its both-directions check, and
      starting first would mean building all three twice
- [ ] 0.2 Phase 5b's position is known. If the archived host checkouts are
      already deleted, three rows leave the inventory; if not, they stay out of
      scope and that is stated rather than assumed

## 1. Re-measure, because the inventory is dated

> **2026-08-08: the fleet shrank by two while this change sat unstarted.**
> `agenticapps-dashboard` and `agenticapps-roadmap` were deleted from the
> machine. Every count in `proposal.md`'s inventory table was taken across a
> fleet that included both, so each row is now an upper bound rather than a
> figure — `## Coding Discipline` in "8 repos", `workflow-config.md` in "7",
> `claude-md/` in "5", `scheduled_tasks.lock` in "5" all need re-running before
> any of them is acted on. That is 1.1's job and it was already its job; this is
> the drift it was written to expect, arriving early.
>
> Section 3 is entirely moot: roadmap's 134 tracked `.planning/` files are no
> longer on this machine. They live in the archived GitHub repository, which is
> what "kept, not migrated" always meant in practice.
>
> **Also re-scope against the host repositories before re-measuring.**
> `claude-workflow`, `codex-workflow`, `opencode-workflow` and
> `pi-agentic-apps-workflow` come off the disk at the end of the plan. They were
> already out of scope here; the new part is that nothing should be *fixed* in
> them in the meantime either, so any inventory row whose count depends on them
> should say so rather than mixing them in.

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

**Resolved 2026-08-08 by its retirement.** This section was the change's blocker
for seven sessions and is now three closed decisions and one live task.

- [x] 3.1 134 tracked files under `.planning/`. Establish what they are and
      whether that repository's planning has moved to `openspec/` or still lives
      there. **Established 2026-08-08: it still lives there, and the repository
      is a product built on `.planning/` rather than one that merely has one.**
      `scripts/sync-gsd-linear.ts` (wired as `pnpm sync:gsd`, with a test beside
      it) walks sibling repositories' `.planning/` trees and upserts them into
      Linear; `sync.config.json` names `claude-workflow`, `cparx` and
      `fx-signal-agent`. All three inputs were deleted on 2026-08-05, so the
      product reads directories that no longer exist
- [x] 3.2 Decide: migrate, or keep with a stated reason. **Decided: keep. The
      reason is the retirement.** Migrating planning into `openspec/` is what you
      do for a repository someone will plan in again; these 134 files are a
      retired product's development history and there is nothing left to migrate
      them to. Nothing is deleted, which is what 1.2's tracked-versus-untracked
      criterion already required — the criterion was never in doubt, the
      disposition was
- [x] 3.3 If it blocks, defer that repository explicitly and report the deferral.
      **Unused — it does not block.** The deferral path stays specified because
      the requirement behind it is general, but this change exercises none of it
- [ ] 3.4 `sync-gsd-linear.ts` and `sync.config.json` are **kept**, and the
      boundary is recorded rather than assumed. They are artifacts of a removed
      tool *and* the retired product's own source code in its own repository;
      sweeping them is gutting the thing being preserved, not removing residue.
      This is the one place in the change where the "artifact of a removed tool"
      boundary has to be drawn by judgement, so it is stated where 7.1 will find
      it

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
- [x] 7.2 If `agenticapps-roadmap` was deferred, it is the first thing the next
      change picks up. **Not deferred — closed by 3.2, so the next change
      inherits nothing here.** Recorded rather than deleted so that the handoff
      says "resolved" instead of going silent, which reads the same as forgotten
