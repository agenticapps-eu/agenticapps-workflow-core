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
Under normal operation `lint-migration.sh` refuses THIS SPECIFIC FIXTURE at
L1 before the runner ever tries to run it — see the L1 assertions elsewhere
in this suite for that path, and this fixture's own test asserts that
normal-path refusal too. This fixture exists to exercise `run_block`'s own
"the block is missing (extract.sh exit 1), not merely failed" distinction
in the dispatch loop directly. Fix round 3 found that a real, DIFFERENT
route to the same dispatch-loop branch exists through the public CLI (a
present, lint-clean pre-condition whose own command is not installed, also
producing a non-zero exit) — so "unreachable" is not a claim made about this
branch in general, only about THIS fixture's specific shape (an absent
role), which lint's L1 does still catch before the runner ever sees it. The
test that drives this fixture reaches the branch via a stub-collaborator
test double (a temp dir of symlinks to the real run-migration.sh/extract.sh
plus a stub lint-migration.sh that exits 0), not via any flag or variable in
run-migration.sh itself — there is no bypass built into the shipped script.

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
