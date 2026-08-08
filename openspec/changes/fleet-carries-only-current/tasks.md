## 0. Preconditions

- [ ] 0.1 `projects-bind-not-copy` is archived. This change reuses its sweep
      pattern, its declared-fleet resolution and its both-directions check, and
      starting first would mean building all three twice
- [ ] 0.2 Phase 5b's position is known — the core-collapse step that deletes the
      archived host checkouts. If they are already gone, four rows leave the
      inventory; if not, they stay out of scope and that is stated rather than
      assumed

## 1. Re-measure, because four rows are dated

`.planning/` was re-measured on 2026-08-08 and its table in `proposal.md` is
current. The other four rows — `workflow-config.md`, `claude-md/`,
`## Coding Discipline`, `scheduled_tasks.lock` — were counted on 2026-08-07
across a fleet that still included `agenticapps-dashboard` and
`agenticapps-roadmap`. Each is an upper bound until re-run.

- [ ] 1.1 Re-run the four dated rows across every repository in `FLEET`, and
      record the result beside the 2026-08-07 numbers so the drift is visible
      rather than absorbed
- [ ] 1.2 Exclude the four host repositories from every count rather than mixing
      them in. They come off the disk at the end of the plan and nothing should
      be fixed in them in the meantime
- [ ] 1.3 Identify anything the 2026-08-07 sweep missed: another removed tool's
      artifacts, another command, another instruction fragment. The inventory was
      built by looking for what was known to be removed, which cannot find what
      nobody remembered removing
- [x] 1.4 Two rows the 2026-08-07 inventory missed entirely, found on 2026-08-08
      and **already removed**, so 1.1 does not rediscover them as a surprise:
      core's own `.gitnexus` index (44M, gitignored, untracked — the only one in
      the fleet), and GSD's installer state in `~/.claude/` (`get-shit-done/`,
      `gsd-pristine/`, `gsd-local-patches/`, `gsd-migration-journal/`,
      `.gsd-profile`, `gsd-file-manifest.json`, `gsd-install-state.json` —
      ~12M, all of it the 2026-06-05 install snapshot). Both are exactly what
      this change is about and neither was in the table: the inventory looked at
      repositories for *checked-in* artifacts, and these are machine-level and
      gitignored. The declaration in 3.1 must own paths outside a repository's
      tracked set, or the same class goes on being invisible

## 2. The safe half — removed-tool artifacts and `.planning/`

Mechanical, reversible except where noted, and independent of the
instruction-file work. One PR per repository.

- [ ] 2.1 `setup-gstack-gsd-superpowers-workflow.md` (`cparx`, 133 lines) and
      `gsd-plan.md` / `setup.md` (`callbot`) — commands offering a tool removed
      on 2026-07-28
- [ ] 2.2 `backend-foundation.md` (`callbot`) — establish whether it belongs to a
      removed tool or is that project's own. **Only the former is in scope**, and
      guessing is how a project loses a command it wrote
- [ ] 2.3 `.claude/workflow-config.md` — pre-OpenSpec workflow config
- [ ] 2.4 `.claude/scheduled_tasks.lock`
- [ ] 2.5 `.claude/claude-md/` — fragments of the modular instruction scheme;
      confirm nothing still assembles from them before deleting
- [ ] 2.6 **`.planning/` in full, tracked and untracked**, in the six in-scope
      repositories: core, `cparx`, `fbc-platform`, `fx-signal-agent`, `stimmung`,
      `neuroflash/mcp-server`. **List every file before removing any** —
      `stimmung` (7) and `mcp-server` (5) hold untracked, un-ignored content
      that exists nowhere else, so the listing is the only record that will
      survive the deletion
- [x] 2.7 **Unregister `meta-observer`** from `~/.claude/settings.json`. Its
      `SessionEnd` entry ran
      `agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`, a
      path deleted on 2026-08-07; it fired on every session end with a 30s
      timeout and it is the reason `.planning/skill-observations/` regrew in
      every repository opened. Deleting the directories without this is
      housekeeping that undoes itself. **Done 2026-08-08, ahead of the change** —
      the hook was firing at a missing path every session, which is not worth
      preserving until a precondition clears. Backup at
      `~/.claude/settings.json.pre-meta-observer-removal`. 2.6 may now proceed
      without the directories regrowing

## 3. Declare what each removed tool owned

The invariant is not implementable without this, so it comes before the sweep it
governs is called complete.

- [ ] 3.1 Write the declaration: tool, removal date, owned paths and patterns,
      append-only, in the shape of `ARTIFACTS` and `SHIMMED-HOOKS`
- [ ] 3.2 Entries for GSD, GitNexus, the wiki-builder and the `.planning/`
      convention. `.planning/` is a directory convention rather than a tool, and
      the declaration is the right home for it precisely because ownership is
      what the check needs, not taxonomy
- [ ] 3.3 Record every preservation entry the sweep relies on — repository, path,
      reason. If the sweep needs none, say so; an empty set stated is different
      from an empty set assumed

## 4. The risky half — instruction text

Last, because it is the only irreversible part.

- [ ] 4.1 Read the trigger skill (4.0.0) against one repository's
      `## Coding Discipline` section and record, rule by rule, which the skill
      carries and which it does not
- [ ] 4.2 Any rule the skill does **not** carry stays in the repository and is
      reported. A rule that exists in eight places and then nowhere is a rule
      nobody decided to drop
- [ ] 4.3 Confirm the skill is reachable from that repository before cutting
      anything. A replacement that does not load is, from inside that repository,
      indistinguishable from no replacement
- [ ] 4.4 Repeat per repository rather than assuming the sections are identical.
      Two copies of the workflow skill once claimed one version and differed;
      there is no reason to expect better of hand-edited prose
- [ ] 4.5 Remove only what 4.1–4.4 justify, one PR per repository, each naming
      the skill section that now carries what it deleted
- [ ] 4.6 The same sweep trims each repository's `CLAUDE.md` and `AGENTS.md` to
      what is true of that repository — stack, commands, conventions, ADR
      pointers. `AGENTS.md` additionally obeys
      `openspec/specs/host-neutral-instruction-files`: one marker-delimited
      section, host-neutral body, per-agent links in frontmatter

## 5. Make the rule hold

- [ ] 5.1 Extend `projects-bind-not-copy`'s second pass to report an artifact of
      a removed tool, resolved against the 3.1 declaration
- [ ] 5.2 The pass reports *in progress* while some declared repositories are
      swept and others are not, naming both sets, and reports complete only when
      every repository holds no match or holds a preservation entry
- [ ] 5.3 Linked worktrees of a declared repository are checked independently
- [ ] 5.4 RED before GREEN, against a scratch root

## 6. Verification

- [ ] 6.1 `openspec validate --all` green; core's suites green
- [ ] 6.2 The check reports a clean fleet, and the run states which root it
      examined
- [ ] 6.3 Open a session in a swept repository and confirm nothing was lost: the
      workflow skill loads, `/opsx:*` works, the declared hooks still fire
- [ ] 6.4 Confirm no session end recreates `.planning/` after 2.7
- [ ] 6.5 Code review on the diff — particularly section 4, where the diff is
      prose and a reviewer is the only check that exists
- [ ] 6.6 `cso`

## 7. Hand off

- [ ] 7.1 Record what was deliberately left: a stale README is not an artifact of
      a removed tool, and the boundary held or it did not. Say which

### Closed, kept visible

- [x] The `agenticapps-roadmap` blocker. It was this change's one named blocker
      for seven sessions. Closed twice over: the repository was archived on
      GitHub on 2026-08-05, and its checkout was deleted on 2026-08-07. The
      134 tracked `.planning/` files it held are in the archived GitHub
      repository, which is what "kept, not migrated" always meant in practice
- [x] `sync-gsd-linear.ts` and `sync.config.json`. Artifacts of a removed tool
      *and* the retired product's own source, in its own repository — the case
      that produced the preservation category in the delta. No local disposition
      remains, since the checkout is gone
- [x] The tracked-versus-untracked criterion for `.planning/`. Dropped
      2026-08-08: its subject left the fleet and the operator's decision is
      delete-outright. Recorded rather than deleted so the handoff says
      "resolved" instead of going silent, which reads the same as forgotten
