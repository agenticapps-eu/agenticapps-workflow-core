## 1. Establish what is being deleted, before deleting it

- [x] 1.1 Confirm nothing executes the tool: every reference in this repository
      and in the agenticapps family is a comment, and no workflow, Makefile,
      hook or script invokes it
- [x] 1.2 Confirm which declarations lose their only reader: `MATCHERS` and
      `OPT-OUTS` are read by the tool alone; `ARTIFACTS` has two other
      consumers; `FLEET` and `SHIMMED-HOOKS` are needed by the replacement
- [x] 1.3 Record the fleet's state at retirement — the last run of the
      instrument, so the claim "the migration is done" is evidenced by the thing
      being retired rather than by the thing replacing it

## 2. The replacement

- [x] 2.1 Write `tools/check-shims.sh`: for each repository in `FLEET` plus core,
      for each hook in `SHIMMED-HOOKS`, report present/missing/drifted against
      the authority bytes; honour an `OPT-OUTS` row; exit 1 if anything is
      missing or drifted
- [x] 2.2 Core is in the target list, not excluded from it — the condition the
      removed "authority's own binder" requirement guarded against is prevented
      by the tool's shape rather than by prose
- [x] 2.3 Run it against the real fleet and check its answer matches 1.3's

## 3. The deletion

- [x] 3.1 Delete `tools/project-hook-conformance.sh` and
      `tools/project-hook-conformance.test.sh`
- [x] 3.2 Correct the comments in `provisioning-check.sh`, `lib/semver.sh`,
      `FLEET`, `MATCHERS`, `SHIMMED-HOOKS` and `project-hooks/README.md` that
      point at the deleted tool — a stale comment naming a file that no longer
      exists is the shape this repository keeps repairing
- [x] 3.3 Leave `.claude/hooks/openspec-change-gate.sh`'s historical note alone
      where it describes what happened, and correct it only where it describes
      what runs

## 4. Close

- [x] 4.1 `openspec validate --all` green
- [x] 4.2 The two remaining suites still pass:
      `tools/project-hook-shim.test.sh`, `tools/project-hooks.test.sh`
- [x] 4.3 Archive this change; leave `feat/instrument-counts-what-it-names`
      unmerged rather than deleting it
- [x] 4.4 **No follow-up change is opened from this change's own output.** If
      `check-shims.sh` reports something, fix the shim it names — not the script
