---
id: 0003
slug: bad-l0-below
title: An unrecognised migration_format value, below threshold
from_version: 1.3.0
to_version: 1.4.0
migration_format: legacy
applies_to:
  - fixture.txt
---

# Migration 0003 — unrecognised migration_format, out of scope by filename

Being below threshold does not excuse a garbage declaration: this fixture
exercises the OTHER L0 branch, the one that fires before the "skip it
entirely" exit — a bogus `migration_format:` value must not be hidden just
because the migration would otherwise be out of scope.

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
