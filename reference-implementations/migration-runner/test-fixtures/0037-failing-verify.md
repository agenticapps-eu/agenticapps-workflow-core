---
id: 0037
slug: failing-verify
title: Step 1 applies and verifies cleanly; step 2's apply succeeds but its verify fails
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - s1.txt
  - s2.txt
  - rollback.log
---

# Migration 0037 — a verify failure after apply succeeded

Companion to 0036-failing-apply.md, for the OTHER half of "A verify failure
is rolled back, a partial apply is not": here `apply` itself succeeds and
`verify` is what fails, so — unlike 0036's step 2 — this step's state is
known and its rollback describes something that actually exists. It must
NOT be recorded as applied, but it MUST be included in an interactive
rollback. Each rollback block appends to `rollback.log` rather than merely
deleting a file, so a test can observe THAT a rollback ran (and in what
order), not just infer it from an absence.

## Steps

### Step 1: Applies and verifies cleanly

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

**Verify:**
```bash role=verify
grep -q '^s1$' s1.txt
```

**Rollback:**
```bash role=rollback
printf 'rollback:1\n' >> rollback.log
rm -f s1.txt
```

### Step 2: Apply succeeds; verify fails

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

**Verify:**
```bash role=verify
grep -q 'this-content-never-appears' s2.txt
```

**Rollback:**
```bash role=rollback
printf 'rollback:2\n' >> rollback.log
rm -f s2.txt
```
