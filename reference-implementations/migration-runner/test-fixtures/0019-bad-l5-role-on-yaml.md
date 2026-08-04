---
id: 0019
slug: bad-l5
title: role= on a non-bash fence
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0019 — role on a yaml fence

## Steps

### Step 1: Full quartet plus a stray yaml fence

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

```yaml role=apply
key: value
```
