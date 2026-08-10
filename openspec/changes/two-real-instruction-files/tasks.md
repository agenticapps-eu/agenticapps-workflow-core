# Tasks

## 1. The writer — tests first

- [x] 1.1 RED: the six starting states in the delta — neither file, CLAUDE-only,
      AGENTS-only, both identical, both differing, one a symlink to the other.
- [x] 1.2 Assert the block is inserted or updated and **no other line changes**,
      by digesting the file minus the marker range before and after.
- [x] 1.3 Assert both names are readable, non-empty and byte-identical after
      every successful run.
- [x] 1.4 Replace the `ln -s` + `mv -f` step in `init-project.sh` with the block
      writer. It must never move, replace, link or delete a file.
- [x] 1.5 Refuse a symlinked name in either direction, naming which one and the
      migration step.
- [x] 1.6 GREEN, twice.
- [x] 1.7 Scope the preservation claim to bytes OUTSIDE the markers: updating an
      existing block necessarily rewrites bytes inside them.

Observed: 17 RED at 1.1, 101/101 GREEN twice at 1.6. `init-project-version`
1.2.0 → **2.0.0**. Two assertions were added beyond the list because the
happy-path rows could not otherwise tell a rewrite from a replacement, and
because one hostile state hangs rather than fails:

- the **inode** of each pre-existing name is unchanged after a run. A `mv` of a
  freshly built file over the destination satisfies every content assertion and
  is exactly what 1.4 forbids.
- a **FIFO** under either name is refused. It is not a directory, nothing in a
  listing distinguishes it, and reading one blocks until a writer appears — so
  the failure it produces is a scaffolder that never returns.

## 2. The gate check — published together with the writer

Neither ships alone. A writer without the check is the GSD outcome; a check
without the writer fails repositories nobody has migrated.

- [x] 2.1 RED: a repository whose two names differ fails the commit; a symlink
      fails; unreadable fails; one name alone does not.
- [x] 2.2 Implement it in the gate reference implementation.
- [x] 2.3 GREEN, and confirm it fails a real commit in a scratch repository
      rather than only in the harness.
- [x] 2.4 Compare the STAGED index blob and mode, never the worktree.
- [x] 2.5 Fail a staged deletion of either name in an enrolled repository,
      keyed on `agenticapps.workflow.enrolled`.
- [ ] 2.6 Bump BOTH versions and publish the writer and the gate in one step.

Observed: 6 RED of 12 new rows at 2.1 (every ALLOW row already passed against
2.0.0, which is the correct RED shape for a check that adds refusals), 81/81
GREEN at 2.3. `gate-version` 2.0.0 → **2.1.0**. CI floors raised with the reason
in the diff, as the guard demands: `MIN_SCORED_ROWS` 69 → 81, `MIN_ROW_CALLSITES`
57 → 69.

The real-commit run at 2.3 also measured something the harness cannot: a
machine-global `core.hooksPath` overrides `.git/hooks`, so the first scratch
repository ran the **published 2.0.0** gate and allowed a divergent commit. Core
escapes that only because it sets `core.hooksPath` locally to its own
`.git/hooks` (ADR-0028). Every other repository on this machine reaches the gate
through the published copy, which is why 2.6 is not a formality.

Versions are bumped; **publishing is held** — see section 5.

## 3. Migration — four repositories, one PR each

Done ahead of the check by operator decision; until section 2 lands they are
kept identical by hand. `cmux` is excluded: the repository is being removed.

- [ ] 3.1 `agenticapps-workflow-core` — PR #106, 68 lines each. **Open, not
      merged**, so core's own `AGENTS.md` is still a symlink and core's
      self-hosted hook now fails every commit here. Sequencing decision below.
- [x] 3.2 `callbot` (542) — measured migrated: both names regular, one blob
      `90cd5863`, committed.
- [x] 3.3 `cparx` — PR #132, 280 lines each
- [x] 3.4 `fx-signal-agent` — PR #134, 317 lines each
- [x] 3.6 After each: both names regular, readable, byte-identical, and a commit
      passes the new check. Verified from the index rather than the worktree,
      which is what the check reads.

## 4. Verification

- [x] 4.1 Every writer case RED before, GREEN after. Outputs recorded.
- [x] 4.2 A divergence introduced by hand fails a real commit.
- [x] 4.3 `openspec validate --all` green; `tools/spec-placement.test.sh` green.
- [x] 4.4 Re-measure the three reach surfaces for both published artifacts.

Measured 2026-08-10, before publishing:

| Surface | Resolves | Carries |
|---|---|---|
| the published copy, `~/.agenticapps/bin/` | written by `install.sh`, version-arbitrated | gate **2.0.0**, init-project **1.2.0** |
| the machine floor, `core.hooksPath` → `~/.agenticapps/git-hooks/pre-commit` | `$HOME/.agenticapps/bin/openspec-change-gate.sh`, for repositories carrying the enrolment key | whatever surface 1 carries |
| the self-hosting binder, core's local `core.hooksPath` → `.git/hooks` | core's **working tree** (ADR-0028) | gate **2.1.0** already |

Five repositories carry the enrolment key: `agents-task-viewer`, `callbot`,
`cparx`, `fbc-platform`, `fx-signal-agent`. Four of them pass the new check
today; `agents-task-viewer` does not — see 5.1.

One edit-time consumer remains, `~/.config/opencode/plugin/openspec-change-gate.ts`,
and it resolves surface 1. It is unaffected either way: it drives hook mode, and
the pair check is pre-commit only. No Claude PreToolUse hook and no project shim
binds the gate — `tools/check-shims.sh` reports no repository binding a fleet
hook at all.

## 5. Found during implementation — decisions the operator owns

- [ ] 5.1 **A sixth enrolled repository carries the old arrangement.** The
      proposal counted five, all of which are now migrated or excluded.
      `agents-task-viewer` is enrolled and stages `CLAUDE.md` at mode `120000`;
      publishing the gate blocks every commit there until it migrates. It was
      missed because the inventory enumerated repositories carrying the workflow
      **section**, not repositories carrying the **enrolment key** — a different
      set, and the enrolment key is what the floor dispatches on.
- [ ] 5.2 **§18 requires a documented escape hatch for whatever a host blocks
      on.** That MUST has been vacuous since gate 2.0.0 — "where the only
      blocking condition is a red `validate`, there is nothing a hatch could
      release". A second blocking condition makes it live again, and the delta
      argues the pair check must NOT be escapable. Either §18 is amended to name
      the pair check and say why it takes no hatch, or the check gets a hatch
      that only ever permits committing the divergence it exists to prevent.
      Amending §18 is a spec bump, which obliges every host to re-assert.
- [ ] 5.3 **Publishing is held pending 5.1.** `./install.sh` republishes both
      artifacts to `~/.agenticapps/bin/`, which is the moment the check reaches
      every enrolled repository on this machine.
