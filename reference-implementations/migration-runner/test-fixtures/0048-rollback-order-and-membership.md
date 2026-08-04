---
id: 0048
slug: rollback-order-and-membership
title: Three steps proving reverse-order rollback, exclusion of the failed step, and continuing past a failed rollback
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - s1.txt
  - s2.txt
  - rollback.log
---

# Migration 0048 — reverse order, membership, and a rollback that itself fails

One fixture, three load-bearing properties at once, all read off a single
`rollback.log` whose CONTENT proves each claim rather than merely its
existence:

- Step 1 and step 2 both apply successfully; step 3's apply fails, so an
  interactive rollback choice should roll back step 2 then step 1 — REVERSE
  document order — and must NEVER roll back step 3 (its apply failed
  part-way; its state is unknown).
- Step 2's rollback itself fails (after recording that it was attempted),
  which must not stop step 1's rollback from being attempted too.

## Steps

### Step 1: Applies; its rollback succeeds

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
printf 'rollback:1:ok\n' >> rollback.log
```

### Step 2: Applies; its rollback fails after recording an attempt

**Idempotency check:**
```bash role=check
test -f s2.txt
```

**Pre-condition:**
```bash role=precondition
test -f s1.txt
```

**Apply:**
```bash role=apply
echo "s2" > s2.txt
```

**Rollback:**
```bash role=rollback
printf 'rollback:2:attempted\n' >> rollback.log
exit 1
```

### Step 3: Apply fails; must never be rolled back

**Idempotency check:**
```bash role=check
test -f s3.txt
```

**Pre-condition:**
```bash role=precondition
test -f s2.txt
```

**Apply:**
```bash role=apply
exit 9
```

**Rollback:**
```bash role=rollback
printf 'rollback:3:should-never-run\n' >> rollback.log
```
