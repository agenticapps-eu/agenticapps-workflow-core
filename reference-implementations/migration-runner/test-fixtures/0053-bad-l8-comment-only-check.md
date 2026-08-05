---
id: 0053
slug: bad-l8-comment-only-check
title: Harden the hook allowlist (check is a leftover TODO)
from_version: 3.1.0
to_version: 3.2.0
migration_format: executable
applies_to:
  - .claude/settings.json
---

# Migration 0053 — a check fence that is only a comment

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER. It is the review's Critical 2:
the most natural authoring accident there is, a placeholder left in.

Before L8 was widened from "empty or whitespace-only" to "contains no
executable statement", this document linted CLEAN (rc 0) and ran to
`step 1: skipped (already applied)` (rc 0) with an untouched working tree —
`bash -c '# TODO...'` exits 0, and the three-valued check contract reads exit
0 as ALREADY APPLIED, so the security-relevant apply below was never attempted
at all.

## Steps

### Step 1: harden the hook allowlist

**Idempotency check:**
```bash role=check
# TODO: check whether the allowlist is already hardened
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
