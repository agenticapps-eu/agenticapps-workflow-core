---
id: 0029
slug: block-isolation
title: Each block runs in its own shell, not inheriting an earlier block's state
from_version: 1.6.0
to_version: 1.7.0
migration_format: executable
applies_to:
  - iso.txt
---

# Migration 0029 — block isolation

## Steps

### Step 1: No leakage between blocks

**Idempotency check:**
```bash role=check
FOO=leaked
iso_leak() { :; }
test -f iso.txt
```

**Pre-condition:**
```bash role=precondition
FOO=leaked
iso_leak() { :; }
test -d .
```

**Apply:**
```bash role=apply
if [ -n "${FOO:-}" ] || command -v iso_leak >/dev/null 2>&1; then
  echo "leaked" > iso.txt
else
  echo "clean" > iso.txt
fi
```

**Rollback:**
```bash role=rollback
rm -f iso.txt
```
