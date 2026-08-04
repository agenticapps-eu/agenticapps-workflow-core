---
id: 0028
slug: bad-nonconsec
title: Two steps whose numbering skips from 1 to 3
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0028 — non-consecutive step numbering

## Steps

### Step 1: Create the marker file

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
echo "one" > fixture.txt
```

**Verify:**
```bash role=verify
grep -q '^one$' fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```

### Step 3: Append a third line, numbering skips 2

**Idempotency check:**
```bash role=check
grep -q '^three$' fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -f fixture.txt
```

**Apply:**
```bash role=apply
echo "three" >> fixture.txt
```

**Verify:**
```bash role=verify
grep -q '^three$' fixture.txt
```

**Rollback:**
```bash role=rollback
grep -v '^three$' fixture.txt > fixture.tmp && mv fixture.tmp fixture.txt
```
