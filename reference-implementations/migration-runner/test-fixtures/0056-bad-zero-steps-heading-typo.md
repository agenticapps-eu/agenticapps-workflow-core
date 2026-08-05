---
id: 0056
slug: bad-zero-steps-heading-typo
title: Add a repo .editorconfig (heading typed at the wrong level)
from_version: 3.0.0
to_version: 3.1.0
migration_format: executable
applies_to:
  - .editorconfig
---

# Migration 0056 — `## Step 1:` instead of `### Step 1:`

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER. It is byte-identical to a working
migration except that its one step heading is `##` rather than `###`, so the
extractor finds no steps at all.

This is how the final review's own first authored migration went wrong. Before
the zero-steps rule existed the linter exited 0 CLEAN on it — and §08's
Conformance section requires an adopting host to run this linter IN CI, so
that CI was green on a document that cannot run. Only run-migration.sh caught
it, and CI does not run run-migration.sh.

## Steps

## Step 1: create .editorconfig

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
