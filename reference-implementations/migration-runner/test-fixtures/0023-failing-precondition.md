---
id: 0023
slug: failing-precondition
title: A pre-condition that fails with a verbatim remediation message
from_version: 1.4.0
to_version: 1.5.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0023 — failing pre-condition

## Steps

### Step 1: A step whose assumptions do not hold

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
echo "cparx: unmanaged prose at line 42. Either (a) move it above the marker," >&2
echo "or (b) re-run with --adopt to take ownership." >&2
exit 3
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
