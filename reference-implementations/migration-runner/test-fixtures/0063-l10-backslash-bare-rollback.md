---
id: 0063
slug: l10-backslash-bare-rollback
title: Replace the notes file
from_version: 3.5.0
to_version: 3.6.0
migration_format: executable
applies_to:
  - NOTES.md
  - RESTORE.md
---

# Migration 0063 — the same `<<\EOF` hole, poisoning a ROLLBACK

THIS FIXTURE IS EXPECTED TO BE REJECTED. It is 0062's shape moved into the
`rollback` block, and it is committed separately because the consequence is
different in kind rather than in degree.

An apply truncated this way writes a partial file and reports success. A
ROLLBACK truncated this way restores a partial file and reports success — and
the runner's failure policy is the one place an operator is explicitly told
the tree was put back. `bash -c` on the truncated body exits 0, so
`do_rollback` records the rollback as having succeeded, and the operator is
told the tree was restored by a block that wrote a prefix of what it owed.

L8 is no help here: the truncated body is non-empty and comment-free. L9 is
silent because the truncating line is bare. Before the backslash fix, L10 did
not see the `<<\EOF` opener at all, so nothing in the linter looked at this
block twice.

## Steps

### Step 1: replace the notes file

**Idempotency check:**
```bash role=check
grep -q '^replaced$' NOTES.md
```

**Pre-condition:**
```bash role=precondition
test -f NOTES.md
```

**Apply:**
```bash role=apply
printf 'replaced\n' > NOTES.md
```

**Rollback:**
```bash role=rollback
rm -f NOTES.md
cat > RESTORE.md <<\EOF
# restored

```
the original notes
```
EOF
```
