---
id: 0041
slug: unclosed-fence-precondition
title: An in-scope, otherwise-conformant migration whose pre-condition fence is never closed
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0041 — unclosed fence at end of file

This is the regression guard for the fix-round-2 finding: `mr_roles` (which
L1 is built on) prints a role from the fence's OPENING line, while
`mr_block` (what the runner actually calls) only sets `found=1` on the
fence's CLOSING line. A fence that opens and is never closed before EOF is
therefore PRESENT to `roles`/L1 but ABSENT to `block`/the runner — it lints
clean and then aborts at run time with "block missing" for a role the
linter just confirmed was there. L2 imposes no ordering between different
roles' fences (only that each fence follows its OWN matching heading), so
this fixture puts `**Pre-condition:**` last, deliberately, and never closes
its fence — the rest of the file simply ends there. Confirm what the
PRE-L7 linter says about this before assuming: it says nothing (exit 0).

## Steps

### Step 1: check/apply/rollback close normally; pre-condition does not

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
