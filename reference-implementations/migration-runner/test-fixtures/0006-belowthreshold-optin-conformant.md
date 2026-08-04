---
id: 0006
slug: belowthreshold-optin-conformant
title: Below every host threshold, but opts in and is fully well-formed
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0006 — opted in below the threshold

Below every host's threshold, but declares `migration_format: executable`
anyway. A declaration can only ADD a migration to the linter's scope, never
remove one already in it — this is the positive counterpart to
`0004-belowthreshold-no-rollback.md`'s regression guard: opting in here must
still run, exactly as if it were above threshold.

## Steps

### Step 1: A complete, well-formed step

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
