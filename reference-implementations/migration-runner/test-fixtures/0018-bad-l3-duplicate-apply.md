---
id: 0018
slug: bad-l3
title: Duplicate apply block
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0018 — duplicate apply

## Steps

### Step 1: Apply twice

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

**Apply:**
```bash role=apply
echo "twice" >> fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
