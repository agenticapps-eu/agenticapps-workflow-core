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
      be fixed in them in the meantime.
      **Corroborated 2026-08-08 from the forge, which is where this fleet keeps
      recording retirements**: `agenticapps-eu/pi-agentic-apps-workflow` is
      `archived=true`, last pushed 2026-08-05. `cparx`, `open-design` and
      `callbot` are all `archived=false` and pushed within the last three days.
      So the exclusion is not merely a plan-ordering convenience — one of the
      four is retired on the record, and the family instruction file still lists
      it under "Active repos". Same failure as `agenticapps-roadmap` in 0.3a of
      `one-enforcement-floor`: the retirement was recorded on GitHub and the
      census looked everywhere except there
- [x] 1.3 Identify anything the 2026-08-07 sweep missed: another removed tool's
      artifacts, another command, another instruction fragment. The inventory was
      built by looking for what was known to be removed, which cannot find what
      nobody remembered removing.
      **Run 2026-08-08 across all 61 repositories under `~/Sourcecode`. It found
      the largest GSD artifact in the fleet, and the inventory had no row for
      it.** See 2.1a. It also found that **`open-design` is not in this change's
      inventory at all** — not in the artifact table, not in the `.planning/`
      table, not in any count. The 2026-08-07 sweep enumerated repositories it
      already associated with the workflow, so a repository carrying a retired
      tool without carrying the workflow was structurally invisible to it. That
      is 1.3's own premise landing on 1.3
- [x] 1.3b **31 orphaned agent worktrees in `cparx`, 4.7G, and git cannot read
      any of them.** Found 2026-08-08 by the verification pass *after* this
      session had already claimed GSD was gone from the live repositories — the
      claim was wrong, and the way it was wrong is the point.
      `.claude/worktrees/` holds 31 full working trees dated 2026-04-16 to
      2026-05-03, gitignored and untracked. 31 of them still carry
      `setup-gstack-gsd-superpowers-workflow.md`, so the command removed in PR
      #129 survives 31 times over in the same repository.

      Each `.git` file reads `gitdir: /Users/donald/Sourcecode/cparx/.git/...`
      — the **pre-family-reorganisation path**. That directory is now
      `~/Sourcecode/factiv/cparx`, so every one of them points at a location
      that no longer exists and every git command inside them fails with
      `fatal: not a git repository`. They were orphaned by a directory move, not
      by `git worktree prune`, and `git worktree list` in `cparx` reports one
      entry: the main checkout.

      **A first pass reported "0 dirty, 0 unpushed" and that reading was
      vacuous** — git was erroring, the output was empty, and empty counted as
      clean. Recorded because it is the same defect as every other row here: a
      check that cannot fail is not evidence, and this one nearly retired 4.7G
      on the strength of it. Whether anything in those trees is worth keeping
      cannot be answered with git and needs content comparison against the
      repository.

      **Removed 2026-08-08 on the operator's instruction, after the comparison
      was actually done rather than assumed.** Every candidate file was hashed
      and asked of `cparx`'s object store — has this repository ever held this
      exact content? Of **19,873** candidates (excluding `node_modules`, build
      output and logs), **19,816 were byte-identical to content already
      committed**. The 57 remainder resolved to: 31 broken `.git` pointers, 11
      `settings.local.json`, a 33M compiled Go binary, seven `.planning/` files
      that 2.6 deletes anyway, two `.env` files, and three Go sources.

      The last two groups were the only ones that could have been work, and
      neither was. The repository's `frontend/.env` is a strict **superset** of
      the worktree copies by variable name. `chat_test.go` and `processor.go`
      have **zero** lines absent from the repository's current versions;
      `chat.go` had nine, and every symbol in them — `IntentAutofillRequest`,
      `runFieldStreamingLoop`, `chipIntent` — is live in `backend/` today at 17,
      44 and 15 occurrences. The code was refactored past, not lost.

      Verified after: `cparx` on the same branch with the same six dirty files,
      `git fsck` clean, `git worktree list` one entry.
- [x] 1.3c **GSD was never uninstalled, and 1.4 says otherwise.** Measured
      2026-08-08, after this change had already reported GSD "removed from the
      two live repositories". What was removed on 2026-07-28 was GSD's state in
      `~/.claude/` — and nothing else on the machine:

      | Where | What |
      |---|---|
      | `~/.pi/gsd/` | 1.9M, 201 files — 19 agents, 5 hooks, 60+ prompts |
      | `~/.config/opencode/get-shit-done/` | 3.2M, 256 files, executable `bin/` |
      | `~/.config/opencode/agents/gsd-*` | 33 agent definitions |
      | `~/.config/opencode/skills/gsd-*` | 12 skills |
      | `~/.config/opencode/rules/gsd-oc-work-hard.md` | a **rule** — always loaded |
      | `~/.codex/get-shit-done/` | 456K, 42 files |
      | `pi-gsd@2.1.4` | a global **npm package** |

      The npm package is **2.1.4 against the file trees' 1.30.0**, and
      `~/.pi/cache/gsd-update-check.json` still reads `update_available: true`,
      last checked 2026-07-21 — a retired tool that went on checking for
      upgrades a week after it was retired.

      **This was missed by the sweep that wrote 1.3a**, which searched
      `~/Sourcecode` and `~/.claude`, found three project copies, deleted two,
      and reported the tool gone — having never looked in `~/.pi`,
      `~/.config/opencode`, `~/.codex` or `npm ls -g`. 1.3a said each sweep
      searches where the workflow is; this one searched where the *last* sweep
      had been. The operational form is: **a tool is uninstalled when its
      package, its per-host config directories and its project copies are all
      gone** — check all three and never infer two from one.
      **Uninstalled 2026-08-08 on the operator's instruction.** 231 paths,
      inventoried into `gsd-machine-uninstall-inventory.md` before removal.
      Verified after against every `PATH` prefix plus every agent, config and
      cache root: nothing matches, no executable answers, `npm ls -g` reports
      none.

      **`npm rm -g pi-gsd` alone would have left most of it**, and the misses
      are the reusable part:

      - **Three npm installs, not one.** fnm's current node (removed by
        `npm rm -g`), `~/.pi/agent/npm/node_modules/pi-gsd`, and
        `/opt/homebrew/lib/node_modules/pi-gsd`. The last was found only by the
        post-removal verification — `pi-gsd --version` still answered `v2.1.4`
        after the uninstall was reported complete.
      - **Bins under a node version that is no longer active.**
        `fnm/node-versions/v24.15.0/installation/bin/` still held `pi-gsd` and
        `pi-gsd-tools`; a package manager only tidies the runtime it is pointed at.
      - **Two update caches**, `~/.pi/cache/` and `~/.cache/gsd/`, and a
        `~/.config/gsd-patches` nobody had listed.

      So the check has a third leg beyond 1.3a's: search space, search terms,
      **and then search again after removing**, because an uninstall is a claim
      like any other. Six `~/.claude/projects/*/memory/*gsd*` files were left
      alone — they are records about the tool, not the tool
- [ ] 1.3a The predicate that missed it is worth stating, because it is the same
      one that missed 21 skills behind symlinks and a 46-line `pre-commit` in
      `~/.agenticapps/git-hooks/`. Each sweep so far has searched **where the
      workflow is** and found only what the workflow put there. A removed tool
      installs itself wherever it was run, which is not the same set. The
      inventory in 3.1 should declare the search *space* — every repository on
      the machine — separately from the search *terms*, or the next removed tool
      hides in the next directory nobody associated with us
- [ ] 1.4 Two rows the 2026-08-07 inventory missed entirely, found on 2026-08-08
      and **already removed**, so 1.1 does not rediscover them as a surprise:
      core's own `.gitnexus` index (44M, gitignored, untracked — the only one in
      the fleet), and GSD's installer state in `~/.claude/` (`get-shit-done/`,
      `gsd-pristine/`, `gsd-local-patches/`, `gsd-migration-journal/`,
      `.gsd-profile`, `gsd-file-manifest.json`, `gsd-install-state.json` —
      ~12M, all of it the 2026-06-05 install snapshot). Both are exactly what
      this change is about and neither was in the table: the inventory looked at
      repositories for *checked-in* artifacts, and these are machine-level and
      gitignored. The declaration in 3.1 must own paths outside a repository's
      tracked set, or the same class goes on being invisible.
      **Reopened 2026-08-08. The GSD half of this row is wrong.** What was
      removed from `~/.claude/` was GSD's *installer state* — the snapshot,
      the patch journal, the manifests. GSD itself was never uninstalled and is
      live on three other hosts plus npm; see 1.3c. This row said "already
      removed, so 1.1 does not rediscover them as a surprise", and that framing
      is exactly what stopped anyone looking further. The `.gitnexus` half
      stands and is independently confirmed absent

## 2. The safe half — removed-tool artifacts and `.planning/`

Mechanical, reversible except where noted, and independent of the
instruction-file work. One PR per repository.

- [x] 2.1 `setup-gstack-gsd-superpowers-workflow.md` (`cparx`, 133 lines) and
      `gsd-plan.md` ~~/ `setup.md`~~ (`callbot`) — commands offering a tool
      removed on 2026-07-28. Both confirmed **tracked** on 2026-08-08, so this
      row is reversible and is an ordinary PR in each repository.
      **Done 2026-08-08** — cparx PR #129, callbot PR #102. callbot's branched
      from `origin/main` rather than its in-flight `chore/instruction-file-cleanup`,
      so each PR carries one deletion and nothing else.
      **`setup.md` was struck from this task, and the reason is the one 2.2
      already warned about.** It is not GSD's. It is callbot's own
      infrastructure-provisioning command — Twilio DID purchase, `wrangler
      secret put`, a setup log — and it mentions GSD **zero** times, against 10
      in `gsd-plan.md`. This task would have deleted a command the project
      wrote, and the only thing that caught it was reading the file instead of
      trusting the row. The row was built from filenames, and `setup.md` sitting
      beside `gsd-plan.md` in one repository is not evidence about what is in it

- [x] 2.1a **GSD itself is still installed, and this is the row the inventory
      never had.** **Removed 2026-08-08** — `cparx` and `open-design`, 348 files
      and 3.6M, verified absent afterwards; `pi-agentic-apps-workflow`'s copy
      left in place, out of scope by 1.2. Neither removal appears in either PR,
      because untracked files are in no diff — which is the whole reason nothing
      reported them for three months.

      Not a command *offering* the tool — the tool. Measured 2026-08-08:

      | Repository | files | size | tracked | gitignored | forge |
      |---|---:|---:|---:|---|---|
      | `cparx` | 201 | 1.9M | 0 | yes | active |
      | `open-design` | 147 | 1.7M | 0 | **no** | active |
      | ~~`pi-agentic-apps-workflow`~~ | 201 | 1.9M | 0 | yes | **archived — out of scope by 1.2** |

      All three are `.pi/gsd/`, all three report `VERSION` **1.30.0**, and each
      carries 66 workflows and 16 references. A pi host opened in `cparx` or
      `open-design` today loads `/gsd:*` and gets a tool this fleet retired on
      2026-07-28 — which is the exact claim every instruction file makes and the
      exact claim the disk contradicts. In scope: **two** repositories, 348
      files, 3.6M.

      **This row is not in §2's "reversible" half and must not be run as though
      it were.** Every one of the 348 files is untracked, so `git` will not give
      any of them back, and `open-design`'s tree is not even gitignored — it is
      simply untracked, un-ignored content, which is the same category 2.6 flags
      for `stimmung` and `mcp-server`. Apply 2.6's rule: **list every file before
      removing any**, and keep the listing, because after the delete the listing
      is the only record that these existed. Reinstallation is not a fallback —
      the installer that wrote them was removed on 2026-07-28
- [ ] 2.1b No symlinks this time, and that is worth recording rather than
      assuming. Every `.pi/gsd` is a **real directory**, and a search of every
      symlink under `~/Sourcecode` for a target matching `gsd`, `gitnexus` or
      `get-shit-done` returned nothing. The fleet's standing lesson is that
      sweeps scoped to symlinks miss directories; the inverse holds here and a
      sweep scoped to directories would have found all of it
- [x] 2.2 `backend-foundation.md` (`callbot`) — establish whether it belongs to a
      removed tool or is that project's own. **Only the former is in scope**, and
      guessing is how a project loses a command it wrote.
      **Established 2026-08-08: it is callbot's own and stays.** `/backend-foundation`
      runs that project's backend MVP sprint against its Linear plan and mentions
      GSD zero times. Left in place, and 2.1's identical error on `setup.md`
      is why this task was right to demand the check rather than assume
- [ ] 2.3 `.claude/workflow-config.md` — pre-OpenSpec workflow config
- [ ] 2.4 `.claude/scheduled_tasks.lock`
- [ ] 2.5 `.claude/claude-md/` — fragments of the modular instruction scheme;
      confirm nothing still assembles from them before deleting
- [ ] 2.6a **STOP — 2.6's premise is false as measured 2026-08-08, and the
      deletion was halted before it ran.** 2.6 justifies removing `.planning/`
      because it "only ever collects stale copies of what `openspec/changes/`
      already holds". Listing all 48 files first — which is 2.6's own rule, and
      the only reason this was caught — shows it holds two things, neither of
      which is that:

      **`skill-observations/` is live telemetry.** 14 files written since
      2026-08-07 across six of the seven in-scope repositories, the newest
      2026-08-08 09:13 in `fbc-platform` — while this change was being written.
      Deleting it destroys current data and does not even stick, because the
      writer recreates the directory. The writer was **not identified**: it is
      absent from `~/.claude/settings.json` hooks, from `~/.claude/plugins`,
      from nyx and from superset. An unidentified process writing into every
      repository on the machine is its own finding and wants an owner before it
      wants a sweep.

      **The four tracked files are this workflow's own config**, not a removed
      tool's. `config.json` and `config.codex.json` in `callbot`,
      `fbc-platform` and `fx-signal-agent` carry `implements_spec: 1.0.0`,
      `host: claude|codex`, `front_end: openspec`, an `_enforcement_contract`
      and a pointer at `.claude/skills/agentic-apps-workflow/SKILL.md`. They are
      AgenticApps' own declarative config from an earlier era of this workflow,
      which makes them a **migration** question — is anything still reading
      them? — and not a residue question.

      So 2.6 needs splitting before it runs: the telemetry needs an owner, the
      configs need a read-check, and `.planning/` as a *name* is doing two jobs.
      The full listing is committed as `planning-removal-inventory.md`; nothing
      was deleted. Third time this session that listing-before-removing changed
      the answer.

      **The owner was found, and the telemetry objection is withdrawn.** The
      writer was `meta-observer`, a single `SessionEnd` hook in
      `~/.claude/settings.json`:
      `node .../agenticapps-dashboard/packages/meta-observer/hooks/session-end.mjs`.
      One run per session, writing `<session-start>--<session-uuid>.jsonl` of
      every `PostToolUse` event plus an `.md` capturing the workflow commitment
      — which is why the filenames are timestamp-plus-UUID, and why the `jsonl`
      is mechanical while the `md` is prose.

      **It is dead twice over.** Unregistered 2026-08-08 **10:01** by 2.7, with
      `~/.claude/settings.json.pre-meta-observer-removal` as the evidence; and
      its script is unreachable because `agenticapps-dashboard` has been
      **deleted from disk**. The newest observation anywhere is `fbc-platform`
      at **09:13** the same morning — 48 minutes before the unregistration.
      Nothing has written since and nothing can. `skill-observations/` is
      therefore inert residue and this row's telemetry half is cleared.

      **The part worth keeping is what the retirement did not say.** The fleet's
      observability lived inside the repository that was retired, so retiring it
      silently removed a machine-wide mechanism six repositories fed, and the
      only thing that noticed was leftover files looking alarming a week later.
      A retirement ADR that lists what a repo *is* should also list what else
      runs from it
- [x] 2.6 **`.planning/` in full, tracked and untracked** — **done 2026-08-08**,
      after 2.6a's objections were resolved rather than waived. All seven
      in-scope repositories are clear; the four host repositories keep theirs by
      1.2. 48 files: 44 untracked, removed directly, and 4 tracked, removed by
      PR — callbot #103, fbc-platform #141, fx-signal-agent #130.

      **The config half was checked, not assumed.** No executable in any of the
      three repositories reads `.planning/config.json`; every surviving
      reference is prose or `docs/legacy-planning/`, and the one hook template
      that does read it — `observability-postphase-scan.sh` in the
      `agenticapps-observability` skill — is not deployed in any in-scope
      repository. fx-signal-agent's alarming 58 references were mostly its own
      orphaned agent worktrees, which is 1.3b's finding in a second repository.

      **Two consequences this leaves behind, neither of them silent:** 2.6b and
      1.3d
- [ ] 2.6b **Deleting `.planning/` made `commitment-reinject.sh` a permanent
      no-op, and that hook is worth keeping.** It fires on `SessionStart
      matcher: compact` and re-injects the commitment ritual and skill-routing
      rules that compaction strips — its own header calls it "the single
      highest-impact hook in the batch". Its guard is `[ -d .planning ] || exit
      0`, so it now exits 0 in every repository on the machine.

      Its second half was already dead before today: it reads
      `.planning/phases/*/COMMITMENT.md`, and **no `COMMITMENT.md` exists
      anywhere in the fleet** — the three `.planning/phases` directories that do
      exist are all in host repositories. So what the deletion actually cost is
      the first half, the CLAUDE.md re-injection.

      The fix is a one-line predicate change from `.planning` to `openspec`,
      which is the marker this fleet now uses for the same thing. **Not done
      here**, because it widens the hook from AgenticApps-with-`.planning` to
      every OpenSpec repository on the machine, and that is a behaviour decision
      rather than a repair. Left with the reasoning attached so it is a choice
      rather than an oversight
- [ ] 1.3d **A second field of orphaned worktrees: `fx-signal-agent`, 22 trees,
      6.4G.** Same signature as 1.3b — `.git` files pointing at
      `~/Sourcecode/fx-signal-agent`, the pre-family-reorganisation path, so git
      cannot read them and `git worktree list` does not know them. Found while
      checking `.planning/config` references, which it inflated from a handful
      to 58.

      **Not removed.** 1.3b's removal was authorised for `cparx` after the
      content comparison proved nothing unique survived there; that proof was
      about `cparx` and does not transfer. The same hash-against-the-object-store
      test should run here first. Combined with 1.3b this is **11.1G** of
      orphaned agent worktrees across two repositories, from one directory move
      nobody swept after
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
