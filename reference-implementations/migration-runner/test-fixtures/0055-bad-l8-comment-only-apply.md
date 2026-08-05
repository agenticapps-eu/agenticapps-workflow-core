---
id: 0055
slug: bad-l8-comment-only-apply
title: Harden the hook allowlist (apply is a leftover TODO)
from_version: 3.1.0
to_version: 3.2.0
migration_format: executable
applies_to:
  - .claude/settings.json
---

# Migration 0055 — an apply fence that is only a comment

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER. This is the variant an earlier
round recorded on the deferred list as an ACCEPTED GAP. It is strictly milder
than 0053 — the step is attempted and vacuous, rather than never attempted at
all — and the same one-line widening of L8 closes it, so there was no reason
to keep deferring it.

Before that widening: lint rc 0, `step 1: applied` (rc 0), empty working tree.

## Steps

### Step 1: harden the hook allowlist

**Idempotency check:**
```bash role=check
test -f settings.json
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
# TODO: write the settings file
```

**Rollback:**
```bash role=rollback
rm -f settings.json
```
