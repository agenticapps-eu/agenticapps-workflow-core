#!/usr/bin/env python3
"""Move whole `### Requirement:` blocks into a target order, by heading name.

`openspec archive` appends ADDED requirements at end-of-file and cannot express
placement. This restores the intended order after the fold. It moves BLOCKS by
heading, never line ranges, so it cannot half-move a requirement, and it is
idempotent — running it on already-ordered input is a no-op.

Refuses rather than guesses: unknown heading, duplicate heading, or any change
in the multiset of lines aborts with a non-zero exit and writes nothing.

Usage:  reorder-requirements.py <spec.md>          # in place
        reorder-requirements.py <spec.md> --check  # verify order only
"""
import sys, re

# The three moved requirements go directly after this one, in this order.
ANCHOR = "A project binds a hook through a shim"
ORDER = [
    "A shim that resolves no implementation allows the call and reports it",
    "A machine's provisioning is a triple, not a state name",
    "Currency is judged against an authority checkout",
]

path = sys.argv[1]
check_only = "--check" in sys.argv
src = open(path).read()
lines = src.split("\n")

# Split into: preamble, then one block per `### Requirement:`.
idx = [i for i, l in enumerate(lines) if l.startswith("### Requirement: ")]
if not idx:
    sys.exit("no requirements found")
preamble = lines[: idx[0]]
blocks = []
for n, start in enumerate(idx):
    end = idx[n + 1] if n + 1 < len(idx) else len(lines)
    blocks.append((lines[start][len("### Requirement: "):].strip(), lines[start:end]))

names = [b[0] for b in blocks]
for want in [ANCHOR] + ORDER:
    if names.count(want) != 1:
        sys.exit(f"expected exactly one requirement named {want!r}, found {names.count(want)}")

moving = {name for name in ORDER}
rest = [b for b in blocks if b[0] not in moving]
byname = {b[0]: b for b in blocks}

out_blocks = []
for b in rest:
    out_blocks.append(b)
    if b[0] == ANCHOR:
        out_blocks.extend(byname[n] for n in ORDER)

new_names = [b[0] for b in out_blocks]
anchor_at = new_names.index(ANCHOR)
expected = [ANCHOR] + ORDER
actual = new_names[anchor_at : anchor_at + 4]

if check_only:
    current = names[names.index(ANCHOR) : names.index(ANCHOR) + 4]
    if current == expected:
        print("order OK:", " -> ".join(current))
        sys.exit(0)
    sys.exit("ORDER WRONG:\n  got:      " + " -> ".join(current)
             + "\n  expected: " + " -> ".join(expected))

out = preamble + [l for _, blk in out_blocks for l in blk]

# Content guard: the multiset of lines must be identical. A reorder that
# changes content is the same defect as a move that drops a line.
if sorted(out) != sorted(lines):
    sys.exit("REFUSING: reorder changed file content, not just order")

if actual != expected:
    sys.exit("REFUSING: could not achieve the target order")

open(path, "w").write("\n".join(out))
print("reordered:", " -> ".join(actual))
