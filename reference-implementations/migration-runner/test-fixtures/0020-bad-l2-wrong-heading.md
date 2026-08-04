---
id: 0020
slug: bad-l2
title: Apply and rollback tags swapped under their headings
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0020 — swapped role/heading agreement

## Steps

### Step 1: Apply and rollback tags swapped under their headings

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=rollback
rm -f fixture.txt
```

**Rollback:**
```bash role=apply
echo "applied" > fixture.txt
```
