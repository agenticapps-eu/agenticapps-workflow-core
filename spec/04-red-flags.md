---
id: 04-red-flags
section_type: canonical-prose
spec_version: 0.1.0
---

# 04 — 13 Red Flags

**Section type**: canonical prose. Host implementations MUST reproduce
the block below verbatim. Each numbered flag is a recognized
rationalization pattern that has historically led to discipline
failure. Encountering a red-flag thought is itself the trigger for
STOP → DELETE → RESTART.

Adding red flags is permitted (a host MAY define additional flags for
host-specific failure modes), but the canonical 13 below MUST appear in
the listed order with the listed wording.

## Canonical block

```
## 13 Red Flags — STOP → DELETE → RESTART

1. Code written before the test (for TDD tasks)
2. Test added after implementation
3. Test passes on first run — no RED observed
4. Cannot explain why the test should have failed
5. Tests marked for "later" addition
6. "Just this once" reasoning
7. Manual testing claimed as verification evidence
8. Two-stage review collapsed into one
9. Framing discipline as "ritual" or "ceremony"
10. Keeping pre-written code as "reference" while writing tests
11. Sunk-cost reasoning about deleting unverified code
12. Describing discipline as "dogmatic"
13. "This case is different because..."
```
