---
id: 0034
slug: escape-probe
title: A dry run must never write outside the workdir, not even via an absolute path
from_version: 1.7.0
to_version: 1.8.0
migration_format: executable
applies_to:
  - probe.txt
---

# Migration 0034 — dry-run escape probe

This is a permanent regression guard for the scratch-mirror defect found in
Task 4 review round 1: an earlier `run-migration.sh` copied the workdir into
a throwaway scratch directory and actually ran each pending step's `apply`
there, on the theory that a copy is not "the working tree." A step whose
`apply` writes to an ABSOLUTE path outside the workdir (here, `$ESCAPE_TARGET`
— set by the test to a throwaway directory standing in for something like
`$HOME`) escaped regardless of which directory the block's shell started in,
because `cd`-ing somewhere first does not confine a command that names its
own absolute destination. Dry-run must never execute `apply` at all — this
fixture exists to prove exactly that, not to prove the copy was faithful.

## Steps

### Step 1: An apply that would escape the workdir if ever executed

**Idempotency check:**
```bash role=check
test -f probe.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
mkdir -p "$ESCAPE_TARGET"
date > "$ESCAPE_TARGET/ran"
echo "applied" > probe.txt
```

**Rollback:**
```bash role=rollback
rm -f probe.txt
rm -rf "$ESCAPE_TARGET"
```
