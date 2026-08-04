---
id: 0004
slug: belowthreshold-no-rollback
title: Below every host threshold, no migration_format, no rollback — but fully functional otherwise
from_version: 1.2.0
to_version: 1.3.0
applies_to:
  - fixture.txt
---

# Migration 0004 — the per-document scope hole

This is the regression guard for the fix-round-1 finding: a document
numbered below every host's threshold, declaring no `migration_format` at
all, is skipped ENTIRELY by the linter (exit 0, clean) — not because it is
well-formed, but because the linter never looked at it. Unlike
`0005-belowthreshold-skip.md` (all-illustration, no tagged `check` at all),
every role here is real and tagged EXCEPT rollback, which is missing
outright. A runner that treats "the linter didn't object" as "the linter
approved" runs this to completion and reports success — the linter's silence
here means NOT EXAMINED, not EXAMINED AND FOUND WELL-FORMED, and a runner
must not confuse the two. Renaming this file to a high-numbered ID would
have made the very same content fail L1 immediately.

## Steps

### Step 1: A step that runs cleanly but has no way back

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
