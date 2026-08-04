---
id: 0016
slug: conformant-fixture
title: A conformant executable migration
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0016 — conformant fixture

## Steps

### Step 1: Create the marker file

Prose explaining why. For contrast, the old shape was:

```bash
# illustration only — no role=, never executed
echo "DO NOT RUN ME" > tripwire.txt
```

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

**Verify:**
```bash role=verify
grep -q '^applied$' fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```

### Step 2: Append a second line

**Idempotency check:**
```bash role=check
grep -q '^second$' fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -f fixture.txt
```

**Apply:**
```bash role=apply
echo "second" >> fixture.txt
```

**Rollback:**
```bash role=rollback
grep -v '^second$' fixture.txt > fixture.tmp && mv fixture.tmp fixture.txt
```
