---
id: 0043
slug: precondition-127
title: A present, lint-clean pre-condition whose own command is not installed
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0043 — the 127 collision

This is the regression guard for the fix-round-3 finding: `run_block`
returned a sentinel of 127 to mean "the block is missing", but `bash -c
"$body"` also returns 127 when the block's OWN command is not found.
Pre-conditions that shell out to `jq`, `gh`, `rg`, or `openspec` are some of
the most common blocks anyone writes, and any one of them returns 127 on a
machine where the tool isn't installed. Before the fix, this fully
lint-clean, in-scope, L7-passing migration was misreported by the runner as
having a MISSING pre-condition block, when the block is present, ran, and
told the operator (via its own exit code) that a command it needs is not
installed. This fixture's pre-condition is real, tagged, and properly
closed — the ONLY thing wrong with it is that the command it calls does not
exist on this machine, which is exactly the point.

## Steps

### Step 1: A pre-condition whose command genuinely is not installed

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
definitely-not-a-real-command-xyz
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
