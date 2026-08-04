---
id: 0005
slug: scope-by-filename
title: In scope purely because the filename says 0030
from_version: 1.3.0
to_version: 1.4.0
applies_to:
  - fixture.txt
---

# Migration 0030 — scope decided by filename alone

This is the regression guard for property A: every other above-threshold
fixture in this suite happens to also be in scope some other way (an
`executable` declaration, or an agreeing frontmatter id). This one is not —
its frontmatter carries no `migration_format:` line at all, and its
frontmatter `id:` (0005) would put it BELOW every host threshold if that
were ever mistakenly used to decide scope instead of the filename. Only the
filename's 0030 puts it in scope. If the linter were "simplified" back to
reading the ID from frontmatter, this fixture would silently exit 0.

## Steps

### Step 1: Complete except for its rollback

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
