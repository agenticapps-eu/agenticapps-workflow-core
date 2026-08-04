---
id: 0031
slug: heredoc-step
title: A step whose apply body writes a heredoc containing a step heading
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - out.txt
---

# Migration 0031 — heredoc emits a step heading

## Steps

### Step 1: Write a file whose body contains a heading-shaped line

**Idempotency check:**
```bash role=check
test -f out.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
cat <<'INNER' > out.txt
### Step 2
INNER
echo done >> out.txt
```

**Verify:**
```bash role=verify
grep -q '^done$' out.txt
```

**Rollback:**
```bash role=rollback
rm -f out.txt
```
