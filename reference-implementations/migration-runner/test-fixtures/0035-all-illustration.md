---
id: 0035
slug: all-illustration
title: A migration whose every fence is un-annotated illustration
from_version: 1.8.0
to_version: 1.9.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0035 — all-illustration

This is the regression guard for the exact failure this format exists to
prevent: a document that LOOKS like a migration — it has a step, it has
prose, it has fenced code — but every fence is un-annotated illustration.
None of role=check/precondition/apply/rollback is ever tagged. A runner that
executes whatever it is handed can run this end to end, print nothing wrong,
and report success, having changed nothing on disk. The linter must reject
this outright, and a runner must refuse to run it even if nobody linted
first.

## Steps

### Step 1: A step that looks complete but tags nothing

Prose describing what a real migration would do here.

```bash
# illustration only — no role=, never executed, never even inspected as
# a real step by extract.sh's roles/block commands.
echo "DO NOT RUN ME" > tripwire.txt
```

**Idempotency check:**
```bash
test -f fixture.txt
```

**Pre-condition:**
```bash
test -d .
```

**Apply:**
```bash
echo "applied" > fixture.txt
```

**Rollback:**
```bash
rm -f fixture.txt
```
