---
id: 0021
slug: bad-l4
title: A stray fence whose role value is misspelled
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0021 — misspelled role value

## Steps

### Step 1: Full quartet plus a stray misspelled-role fence

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

```bash role=aply
echo "should never run" > tripwire.txt
```
