---
id: 0038
slug: zero-apply-step
title: A step whose apply fence is tagged but empty
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0038 — zero-apply step

L1 only checks that a role= fence is PRESENT; it says nothing about what is
inside it. A step can therefore carry a syntactically valid role=apply fence
that opens and closes with no body at all — check, precondition and rollback
are all real here, so this lints clean under L1/L3/L5. Running this step
would apply literally nothing: `bash -c ''` exits 0 and touches no files,
which is the same silent-no-op failure this format exists to prevent, just
one level down from an un-annotated fence. The runner's own pre-flight scan
— not the linter — is what has to catch this one: it treats an EMPTY
captured apply body the same as an ABSENT one.

## Steps

### Step 1: An apply fence with nothing between its delimiters

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
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
