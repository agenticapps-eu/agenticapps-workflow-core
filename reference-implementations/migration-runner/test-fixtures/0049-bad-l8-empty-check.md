---
id: 0049
slug: bad-l8-empty-check
title: A tagged check fence that opens and closes with nothing inside
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0049 — an empty check fence is a silent no-op, not illustration

`role=check` is present per L1 (a fence with that exact tag opens and
closes), so before this fixture's own rule (L8) existed it linted CLEAN.
Run for real, `bash -c ''` exits 0 — which the three-valued check contract
reads as "already applied" — so the runner reports `step 1: skipped
(already applied)` and applies nothing at all, on a tree where nothing was
ever applied. This is the same silent-no-op class the whole format exists
to close, just one layer beneath an un-annotated fence: this one IS
tagged, and still does nothing.

## Steps

### Step 1: An idempotency check with nothing inside it

**Idempotency check:**
```bash role=check
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
