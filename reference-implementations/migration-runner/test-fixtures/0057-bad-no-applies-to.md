---
id: 0057
slug: bad-no-applies-to
title: Add a repo .editorconfig (no applies_to declared)
from_version: 3.0.0
to_version: 3.1.0
migration_format: executable
---

# Migration 0057 — an in-scope migration with no `applies_to`

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER. Structurally it is perfect: one
step, all four roles, correct headings, exact info strings. What it does not
have is the one frontmatter field this change newly makes load-bearing.

At or above the threshold `applies_to` is the WRITE BOUNDARY an apply block may
not cross — the clause that makes the rollback contract bounded rather than
aspirational. Omitted entirely, the permitted write set is undefined and every
statement about what this migration's rollback owes the tree is vacuous. The
linter checked no frontmatter field at all before fix round 4, so this linted
clean at rc 0.

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
