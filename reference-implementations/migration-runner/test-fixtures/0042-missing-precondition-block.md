---
id: 0042
slug: missing-precondition-block
title: An in-scope migration whose step has no pre-condition block at all
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0042 — missing pre-condition block

Ordinary and in-scope: `check`, `apply`, and `rollback` are all real and
tagged; `precondition` has no heading and no fence anywhere in the step.
Under normal operation `lint-migration.sh` refuses this at L1 before the
runner ever tries to run it — see the L1 assertions elsewhere in this
suite for that path. This fixture exists specifically to exercise
`run_block`'s OWN "the block is missing (extract.sh exit 1), not merely
failed" distinction in the dispatch loop, which fix round 2 confirmed is
otherwise unreachable through the public CLI once lint always runs first.
The test that drives this fixture bypasses the lint gate deliberately (see
`_RUN_MIGRATION_TEST_ONLY_SKIP_LINT` in run-migration.sh) — this is not a
document any real invocation would ever reach past lint.

## Steps

### Step 1: No pre-condition heading or fence at all

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
