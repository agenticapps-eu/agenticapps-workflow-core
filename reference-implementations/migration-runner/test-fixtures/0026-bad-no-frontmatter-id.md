---
slug: bad-no-id
title: No id line at all in frontmatter, and no rollback
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0026 — no frontmatter id, missing rollback

## Steps

### Step 1: In scope by filename alone; still missing its rollback

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
