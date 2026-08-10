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
- [x] 2.6 Bump BOTH versions and publish the writer and the gate in one step.

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

Published 2026-08-10 by one `./install.sh` run: `~/.agenticapps/bin/` now carries
gate **2.1.0** and init-project **2.0.0**. The published copy scores 81/81 against
the harness, and a real `git commit` in an enrolled scratch repository is refused
through the whole machine path — global `core.hooksPath` → floor dispatcher →
published gate.

## 3. Migration — four repositories, one PR each

Done ahead of the check by operator decision; until section 2 lands they are
kept identical by hand. `cmux` is excluded: the repository is being removed.

- [x] 3.1 `agenticapps-workflow-core` — PR #106, 68 lines each. Merged into this
      branch rather than waited on: core's hook resolves its own working tree, so
      the new check failed every commit here until the migration landed. #106 is
      redundant now, its commit being in this branch's history.
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

Five repositories carried the enrolment key at that measurement:
`agents-task-viewer`, `callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`. Four
passed the new check; `agents-task-viewer` did not — see 5.1, which retired it.

Re-measured after publishing: surfaces 1 and 3 both carry gate **2.1.0** and
init-project **2.0.0**, surface 2 resolves surface 1, and the enrolled set is
**four** repositories, each dry-run at `rc=0` before the publish was allowed.

One edit-time consumer remains, `~/.config/opencode/plugin/openspec-change-gate.ts`,
and it resolves surface 1. It is unaffected either way: it drives hook mode, and
the pair check is pre-commit only. No Claude PreToolUse hook and no project shim
binds the gate — `tools/check-shims.sh` reports no repository binding a fleet
hook at all.

## 5. Found during implementation — decisions the operator owns

- [x] 5.1 **A sixth enrolled repository carried the old arrangement.** The
      proposal counted five, all of which are now migrated or excluded.
      `agents-task-viewer` is enrolled and stages `CLAUDE.md` at mode `120000`;
      publishing the gate blocks every commit there until it migrates. It was
      missed because the inventory enumerated repositories carrying the workflow
      **section**, not repositories carrying the **enrolment key** — a different
      set, and the enrolment key is what the floor dispatches on.

      **Resolved by retiring it, not by migrating it.** `agents-task-viewer` was
      an experiment nobody is carrying forward. Retirement notice merged (PR
      #20), GitHub repository archived, 84M checkout deleted 2026-08-10, and the
      family `CLAUDE.md` carries the record. Nothing ran out of it — measured,
      not assumed: no symlink into the checkout, no host config or hook, no npm
      link, no live roster entry.
- [x] 5.2 **§18 required a documented escape hatch for whatever a host blocks
      on.** That MUST had been vacuous since gate 2.0.0 — "where the only
      blocking condition is a red `validate`, there is nothing a hatch could
      release" — and a second blocking condition made it live again, demanding a
      hatch for the one check whose value is that it has none.

      **§18 amended, spec 2.0.0 → 2.1.0, minor.** It now names both blocking
      conditions and states that neither takes a hatch: for a red `validate`
      there is nothing to release, and for the pair a hatch could only ever
      permit committing the divergence the check exists to prevent. Minor because
      it removes an obligation and adds none, and because §18 does **not** oblige
      hosts to implement the pair check — where the two names live belongs to the
      instruction-file requirements, and the gate script is only where the
      pre-commit surface happens to be.
- [x] 5.3 **Published, once 5.1 was resolved.** The enrolled set is four
      repositories now — `callbot`, `cparx`, `fbc-platform`, `fx-signal-agent` —
      and each was dry-run against the new gate at `rc=0`, with zero pair-check
      complaints, before `./install.sh` was allowed to run.

- [x] 5.4 **`tools/test-install-core-git-hooks.sh` was RED on `main`, and the
      cause is the same leak this change kept tripping over.** The suite's
      fixtures inherited the machine's **global** `core.hooksPath`, so every
      scratch repository resolved its hooks directory to `~/.agenticapps/git-hooks`
      — where the global floor's own `pre-commit` lives. The installer then
      refused, correctly, to overwrite a hook another installer wrote, and eight
      cases asserting a successful install failed for a reason unrelated to the
      installer. CI has no global git config, so CI was green throughout. Fixed
      by exporting `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_SYSTEM=/dev/null`
      in the harness, on the same principle as the change-gate harness's
      `unset OPENSPEC_GATE_SELF`: a measurement tool must not inherit state from
      the thing it measures. 8/16 → **16/16**.
