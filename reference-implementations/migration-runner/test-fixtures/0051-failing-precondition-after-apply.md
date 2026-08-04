---
id: 0051
slug: failing-precondition-after-apply
title: Step 1 applies cleanly; step 2's pre-condition fails, leaving step 1's work on disk
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - s1.txt
---

# Migration 0051 — a pre-condition failure after an earlier step applied

Regression guard for fix round 2 of task 6's review: a pre-condition
failure (or a missing check/precondition block) hard-aborts unconditionally,
by design — but that abort must still report which steps already applied
and that nothing was rolled back, exactly like every other hard abort in
this script does. Before that round, only the apply/verify BLOCK_MISSING
paths gave that report; a lint-clean migration reaching THIS shape — step 1
genuinely applies, then step 2's pre-condition fails — gave no
"applied steps" report at all, reached through the real CLI with no stub
required.

## Steps

### Step 1: Applies cleanly

**Idempotency check:**
```bash role=check
test -f s1.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "s1" > s1.txt
```

**Rollback:**
```bash role=rollback
rm -f s1.txt
```

### Step 2: Pre-condition fails

**Idempotency check:**
```bash role=check
test -f s2.txt
```

**Pre-condition:**
```bash role=precondition
exit 3
```

**Apply:**
```bash role=apply
echo "s2" > s2.txt
```

**Rollback:**
```bash role=rollback
rm -f s2.txt
```
