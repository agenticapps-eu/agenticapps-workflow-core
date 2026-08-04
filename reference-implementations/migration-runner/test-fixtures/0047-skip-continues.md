---
id: 0047
slug: skip-continues
title: A three-step migration whose middle step fails under the skip policy
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - s1.txt
  - s2.txt
  - s3.txt
---

# Migration 0047 — skip continues rather than aborting

An earlier draft of the failure policy had `skip` fall through to an
unconditional exit, which meant skip never skipped. This fixture is the
load-bearing regression guard: step 2's apply always fails, and under
`--on-failure=skip` the runner must still reach and apply step 3, not stop
at step 2.

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

### Step 2: Apply always fails

**Idempotency check:**
```bash role=check
test -f s2.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
exit 9
```

**Rollback:**
```bash role=rollback
rm -f s2.txt
```

### Step 3: Must still be reached under skip

**Idempotency check:**
```bash role=check
test -f s3.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "s3" > s3.txt
```

**Rollback:**
```bash role=rollback
rm -f s3.txt
```
