---
id: 0036
slug: failing-apply
title: Step 1 applies cleanly; step 2's apply fails, leaving step 1's work on disk
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
  - step2.txt
---

# Migration 0036 — a runtime failure after earlier steps applied

This instantiates spec.md's own scenario for "Refusal is distinguishable
from failure by exit code": *"WHEN a step's apply fails AFTER EARLIER STEPS
APPLIED"*. Step 1 applies cleanly and step 2's apply exits 7 — chosen to
match the shape reserved for group 6's own `failing-apply.md` fixture
(tasks.md group 6, task 6.1: "step 2's apply exits 7"), since this is
exactly that shape; group 6 can build on this file directly rather than
duplicating it. The observable property under test is that step 1's
artefact SURVIVES on disk: this is the difference between "refused, tree
untouched" (exit 65, nothing ran) and "ran partway, tree may have changed"
(exit 1, here).

## Steps

### Step 1: Applies cleanly

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
echo "step1" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```

### Step 2: Apply fails

**Idempotency check:**
```bash role=check
test -f step2.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
exit 7
```

**Rollback:**
```bash role=rollback
rm -f step2.txt
```
