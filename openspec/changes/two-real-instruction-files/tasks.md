# Tasks

## 1. The writer — tests first

- [ ] 1.1 RED: the six starting states in the delta — neither file, CLAUDE-only,
      AGENTS-only, both identical, both differing, one a symlink to the other.
- [ ] 1.2 Assert the block is inserted or updated and **no other line changes**,
      by digesting the file minus the marker range before and after.
- [ ] 1.3 Assert both names are readable, non-empty and byte-identical after
      every successful run.
- [ ] 1.4 Replace the `ln -s` + `mv -f` step in `init-project.sh` with the block
      writer. It must never move, replace, link or delete a file.
- [ ] 1.5 Refuse a symlinked name in either direction, naming which one and the
      migration step.
- [ ] 1.6 GREEN, twice.
- [ ] 1.7 Bump `init-project-version` — the publisher arbitrates on it — and
      publish via `install.sh`.

## 2. The gate check

- [ ] 2.1 RED: a repository whose two names differ fails the commit; a symlink
      fails; unreadable fails; one name alone does not.
- [ ] 2.2 Implement it in the gate reference implementation.
- [ ] 2.3 GREEN, and confirm it fails a real commit in a scratch repository
      rather than only in the harness.
- [ ] 2.4 Bump the gate version and publish.

## 3. Migration — five repositories, one PR each

- [ ] 3.1 `agenticapps-workflow-core` (54 lines, `AGENTS.md` is the link)
- [ ] 3.2 `callbot` (542)
- [ ] 3.3 `cparx` (280)
- [ ] 3.4 `fx-signal-agent` (303, `AGENTS.md` is the link)
- [ ] 3.5 `cmux` (274)
- [ ] 3.6 After each: both names regular, readable, byte-identical, and a commit
      passes the new check.

## 4. Verification

- [ ] 4.1 Every writer case RED before, GREEN after. Outputs recorded.
- [ ] 4.2 A divergence introduced by hand fails a real commit.
- [ ] 4.3 `openspec validate --all` green; `tools/spec-placement.test.sh` green.
- [ ] 4.4 Re-measure the three reach surfaces for both published artifacts.
