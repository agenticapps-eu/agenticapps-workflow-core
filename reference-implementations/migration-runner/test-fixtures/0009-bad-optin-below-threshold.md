---
id: 0009
slug: bad-optin
title: Below every host threshold, but opts in and omits its rollback
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0009 — below-threshold opt-in

## Steps

### Step 1: Declares executable while below threshold; still missing rollback

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
