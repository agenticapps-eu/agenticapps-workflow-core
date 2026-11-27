# Tasks

## 1. Tests first

- [x] 1.1 `tools/init-project.test.sh:139`: `digest_outside_markers` runs
      `head` only when `b > 1`.
- [x] 1.2 RED: fixture M11, the claude-mods case. `AGENTS.md`/`CLAUDE.md` are
      a 1.1.0 section and nothing else, marker on line 1. Assert: exit zero,
      `$OUT` contains no `head:`, the section is 1.2.0, the two files are
      identical to each other. Then run again: no `head:`, both files unchanged.
- [x] 1.3 RED: fixture M12, marker on line 1 with trailing operator content.
      Assert: exit zero, no `head:`, the bytes outside the markers unchanged.
- [x] 1.4 Run both on this Mac and see them fail on the `head:` assertion.

## 2. The fix

- [x] 2.1 `init-project.sh:283`: emit the prefix only when `BEGIN_LINE > 1`.
      `init-project-version` 2.3.0 → 2.3.1, with a changelog line.
- [x] 2.2 GREEN: `tools/init-project.test.sh` all pass.

## 3. Close

- [x] 3.1 Stage-2 code review on the diff. Run in this session at the
      operator's word, by a fresh reviewer given only the diff and this change,
      not in a cleared session. Verdict: ready to merge, no critical or
      important findings. Folded in: M11/M12 assert an empty stderr (the spec's
      "or other tool error", not just `head:`), M12 checks the section became
      1.2.0, and M11 notes it is RED only on BSD head. Left: M11's second run
      checks `CLAUDE.md` through `assert_pair` only.
- [x] 3.2 `openspec validate --all` green; archive; PR closes #121.
