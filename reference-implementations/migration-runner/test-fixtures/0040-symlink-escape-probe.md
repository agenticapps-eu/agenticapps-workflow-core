---
id: 0040
slug: symlink-escape-probe
title: A dry run must never write outside the workdir via a relative path through a symlink
from_version: 1.9.0
to_version: 1.10.0
migration_format: executable
applies_to:
  - probe.txt
---

# Migration 0040 — dry-run symlink escape probe

0034-escape-probe.md guards the ABSOLUTE-path variant of the dry-run escape
(an apply naming `$ESCAPE_TARGET` directly). This is the same root cause
guarded from the other side: a workdir that contains a symlink pointing
outside itself, and an apply block that only ever names a purely RELATIVE
path (`escape-link/ran`, no leading `/`, no environment variable). `cd`-ing
into the workdir first does not confine a command that then walks through a
symlink back out of it. Dry-run must never execute `apply` at all — not for
real, not against a scratch copy — so this must never appear regardless of
what the relative path resolves to. The test that drives this fixture
creates `escape-link` as a symlink to a throwaway directory standing in for
something like `$HOME`, exactly as 0034's test stands in with
`$ESCAPE_TARGET`.

## Steps

### Step 1: An apply that would escape the workdir through a symlink, if ever executed

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
date > escape-link/ran
echo "applied" > probe.txt
```

**Rollback:**
```bash role=rollback
rm -f probe.txt
rm -f escape-link/ran
```
