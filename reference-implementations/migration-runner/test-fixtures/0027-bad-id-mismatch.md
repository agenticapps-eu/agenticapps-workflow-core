---
id: 0005
slug: bad-id-mismatch
title: Frontmatter id disagrees with the filename id
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0027 — frontmatter id disagrees with filename

## Steps

### Step 1: Otherwise conformant; scope is still decided by the filename

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
