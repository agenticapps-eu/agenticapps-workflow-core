---
id: 0052
slug: bad-l9-heredoc-fence
title: Append a usage section to CLAUDE.md (truncated by a nested fence)
from_version: 3.2.0
to_version: 3.3.0
migration_format: executable
applies_to:
  - CLAUDE.md
---

# Migration 0052 — the nested-fence truncation (L9 / L10 regression fixture)

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER. It is the review's Critical 1,
committed verbatim as it was authored by hand against the README alone — the
fleet's normal idiom for patching CLAUDE.md, which happens to emit a fenced
code block from inside a heredoc.

Before L9/L10 existed this document linted CLEAN (rc 0), ran to `step 1:
applied` (rc 0), wrote only the truncated prefix to CLAUDE.md, and — because
the idempotency check then matched that truncated prefix — reported `step 1:
skipped (already applied)` on every subsequent run. It permanently
self-certified as done.

## Steps

### Step 1: append the usage section

**Idempotency check:**
```bash role=check
grep -q "^## Running the suite" CLAUDE.md
```

**Pre-condition:**
```bash role=precondition
test -f CLAUDE.md
```

**Apply:**
```bash role=apply
cat >> CLAUDE.md <<'EOF'

## Running the suite

```bash
bash tools/migration-runner.test.sh
```
EOF
```

**Rollback:**
```bash role=rollback
sed -i '' '/^## Running the suite$/,$d' CLAUDE.md
```
