---
id: 04-red-flags
section_type: canonical-prose
spec_version: 0.8.0
---

# 04 — 13 Red Flags

**Section type**: canonical prose. Host implementations MUST reproduce
the block below verbatim, subject to the composition rules under
*Adding host-specific flags*. Each numbered flag is a recognized
rationalization pattern that has historically led to discipline
failure. Encountering a red-flag thought is itself the trigger for
STOP → DELETE → RESTART.

## Adding host-specific flags

A host MAY define additional red flags for host-specific failure modes.
When it does:

1. Host-specific flags MUST be **appended after** the canonical 13 — at
   position 14 or higher. A host MUST NOT insert one between the
   canonical flags.
2. The canonical 13 therefore keep positions **1–13**, in the listed
   order, with the listed wording.
3. The heading's leading count is **not normative**. A host that appends
   flags updates it to its own total (e.g. `## 14 Red Flags — STOP →
   DELETE → RESTART`). The remainder of the heading — `Red Flags — STOP
   → DELETE → RESTART` — is canonical and MUST NOT be reworded.

**Rationale.** Pinning the canonical 13 to positions 1–13 keeps the
block's first thirteen numbered lines byte-identical across hosts, so
conformance is an exact match rather than an order-preserving
subsequence search that has to strip numbering first.

**What this resolves.** Before v0.8.0 this section required verbatim
reproduction of the block *and* permitted additions — two rules no host
could satisfy at once, since adding a flag necessarily changes the
count, the numbering, or both. A host that exercised the permission was
non-conformant under the verbatim rule; a host that honored the verbatim
rule could not exercise the permission. v0.8.0 makes the permission
usable by scoping what "verbatim" binds: the thirteen canonical flag
lines and the non-count portion of the heading.

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
