---
id: 0054
slug: bad-l8-noop-builtin-check
title: Harden the hook allowlist (check is a bare no-op builtin)
from_version: 3.1.0
to_version: 3.2.0
migration_format: executable
applies_to:
  - .claude/settings.json
---

# Migration 0054 — a check fence whose whole body is `:`

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER. Same outcome as 0053, reached
through the shell's explicit no-op rather than through a comment: `bash -c ':'`
exits 0, so the runner reported `step 1: skipped (already applied)` (rc 0) on
an untouched tree.

`:` and `true` are counted as NON-executable by L8 when they are the entire
body — see lint-migration.sh's L8 note for why, and for why `:` appearing
INSIDE a larger body (`while :; do`) is untouched by that rule.

## Steps

### Step 1: harden the hook allowlist

**Idempotency check:**
```bash role=check
:
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
printf '{"deny":["*"]}\n' > settings.json
```

**Rollback:**
```bash role=rollback
rm -f settings.json
```
