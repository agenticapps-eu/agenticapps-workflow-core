---
id: 0032
slug: bad-l0-above
title: An unrecognised migration_format value, at or above threshold
from_version: 1.3.0
to_version: 1.4.0
migration_format: legacy
applies_to:
  - fixture.txt
---

# Migration 0032 — unrecognised migration_format, in scope by filename

## Steps

### Step 1: Otherwise conformant

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

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
