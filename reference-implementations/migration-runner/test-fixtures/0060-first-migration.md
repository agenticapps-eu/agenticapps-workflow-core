---
id: 0060
slug: first-migration
title: Add a repo .editorconfig
from_version: 3.0.0
to_version: 3.1.0
migration_format: executable
applies_to:
  - .editorconfig
---

# Migration 0060 — Add a repo .editorconfig

THIS FIXTURE IS EXPECTED TO LINT CLEAN AND RUN. It is the worked example
reproduced verbatim in the README's "Your first executable migration" section,
committed here so that the README's example is machine-checked rather than
transcribed by hand and left to rot.

It is also the smallest complete migration this format admits: one step, the
four required roles, the five headings, and the six frontmatter fields an
in-scope migration must carry.

## Steps

### Step 1: create .editorconfig

**Idempotency check:**
```bash role=check
test -f .editorconfig
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
printf 'root = true\n' > .editorconfig
```

**Rollback:**
```bash role=rollback
rm -f .editorconfig
```
