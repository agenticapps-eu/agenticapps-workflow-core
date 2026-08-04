---
id: 0017
slug: bad-l1
title: Missing rollback
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0017 — missing rollback

## Steps

### Step 1: Apply without a way back

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```
