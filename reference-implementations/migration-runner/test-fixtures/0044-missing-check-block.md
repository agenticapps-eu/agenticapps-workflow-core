---
id: 0044
slug: missing-check-block
title: An in-scope migration whose step has no idempotency check block at all
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0044 — missing check block

This is the regression guard for the fix-round-4 finding: fix round 3's
`BLOCK_MISSING` refactor changed a missing block's return value from a
sentinel 127 to a real 1 — which collides with the THREE-VALUED check
contract's OWN meaning for 1 ("not yet applied, proceed"). Without checking
`$BLOCK_MISSING` at the check call site, a migration whose check was simply
never written silently falls into "proceed, apply it" instead of aborting,
voiding the idempotency contract entirely. `precondition`, `apply`, and
`rollback` are all real and tagged; `check` has no heading and no fence
anywhere in the step. Under normal operation `lint-migration.sh` refuses
this at L1 before the runner ever tries to run it, exactly like
0042-missing-precondition-block.md's shape for precondition — this
fixture's own test asserts that normal-path refusal too, then reaches the
dispatch loop's own check-handling via the same stub-collaborator test
double.

## Steps

### Step 1: No idempotency check heading or fence at all

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "APPLIED BLIND" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```
