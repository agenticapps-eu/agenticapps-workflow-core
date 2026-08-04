---
id: 0022
slug: bad-threshold
title: A complete step whose frontmatter never declares migration_format
from_version: 1.3.0
to_version: 1.4.0
applies_to:
  - fixture.txt
---

# Migration 0022 — no migration_format declaration

## Steps

### Step 1: Otherwise conformant, but frontmatter is silent on format

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
