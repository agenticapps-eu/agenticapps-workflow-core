---
id: 0025
slug: bad-infostring
title: A step whose apply fence carries an extra info-string key
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0025 — extra info-string key

## Steps

### Step 1: Apply fence with an extra key

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply retry=2
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
