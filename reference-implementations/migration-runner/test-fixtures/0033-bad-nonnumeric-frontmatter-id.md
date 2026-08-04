---
id: abc
slug: bad-nonnumeric-id
title: Frontmatter id is not numeric at all
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0033 — non-numeric frontmatter id

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
