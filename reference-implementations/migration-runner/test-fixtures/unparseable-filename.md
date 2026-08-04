---
id: 0016
slug: unparseable-filename
title: Deliberately named with no leading digits at all
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Not-a-number — this fixture exists only to lack a numeric filename prefix

This file's whole purpose is its FILENAME, not its content: it has no
`<digits>-` prefix, so lint-migration.sh must reject it before it ever reads
this far. Content below is a normal conformant single step so that, if the
filename check were ever accidentally skipped, the failure would be obvious
rather than masked by some other unrelated violation.

## Steps

### Step 1: Ordinary conformant step

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
