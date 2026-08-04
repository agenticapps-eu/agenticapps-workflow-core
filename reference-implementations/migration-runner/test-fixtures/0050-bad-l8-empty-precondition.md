---
id: 0050
slug: bad-l8-empty-precondition
title: A tagged pre-condition fence containing only a blank line
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0050 — a whitespace-only pre-condition passes vacuously

Not merely zero bytes between the fences — one blank line — so this also
proves L8 tests for whitespace-only content, not just a literally empty
capture. `bash -c '\n'` (a lone newline) exits 0 exactly like `bash -c ''`
does, so an idempotency-check-shaped defect exists here too: a
pre-condition that "passes" having asserted nothing.

## Steps

### Step 1: A pre-condition with only a blank line inside it

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition

```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
