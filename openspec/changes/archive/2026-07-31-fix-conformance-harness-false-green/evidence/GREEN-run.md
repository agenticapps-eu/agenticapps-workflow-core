# GREEN run — 2026-07-31T20:17:21Z

```
  PASS  D. unreadable target -> UNSCOREABLE, reason unreadable
  PASS  E. broken symlink -> UNSCOREABLE, not-a-regular-file wins
  PASS  F. newline in a path cannot forge a PASS line

═══ TOTAL: 36 passed, 0 failed, 5 skipped
```

## Live --family (task 6.1)
```
═══ core
  ── 71 passed, 0 failed, 0 inconclusive of 71 rows
═══ opencode-workflow
  ── 42 passed, 29 failed, 0 inconclusive of 71 rows
═══ pi-agentic-apps-workflow
  ── 42 passed, 29 failed, 0 inconclusive of 71 rows
═══ shared-install
  ── 71 passed, 0 failed, 0 inconclusive of 71 rows
═══ COVERAGE: scored 4 of 6 roster entries
  claude-workflow — not vendored; resolvable from pin, not attempted (--resolve)
  codex-workflow — not vendored; resolvable from pin, not attempted (--resolve)
═══ TOTAL: 226 passed, 58 failed, 0 inconclusive
```

## --resolve (task 1.24) — opt-in, reaches the pins
```
═══ core
═══ claude-workflow (resolved from pin)
═══ codex-workflow (resolved from pin)
═══ opencode-workflow
═══ pi-agentic-apps-workflow
═══ shared-install
═══ COVERAGE: scored 6 of 6 roster entries
═══ TOTAL: 368 passed, 58 failed, 0 inconclusive
```

claude-workflow and codex-workflow resolve to gate 2.0.0 and score 71/71.
The old harness could not show this: it filtered them out and printed success.
