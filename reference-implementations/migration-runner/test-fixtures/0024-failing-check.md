---
id: 0024
slug: failing-check
title: An idempotency check that cannot run
from_version: 1.5.0
to_version: 1.6.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0024 — check exits neither 0 nor 1

## Steps

### Step 1: A step whose check is broken

**Idempotency check:**
```bash role=check
exit 2
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
