---
id: 0046
slug: apply-dropped-by-step1
title: Step 1's apply rewrites the document to drop step 2's apply fence
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - s1.txt
  - s2.txt
---

# Migration 0046 — the document changes out from under the dispatch loop

Proves the apply-site `BLOCK_MISSING` branch is reachable through the REAL
public CLI, no stub collaborator required: extract.sh re-reads `$DOC` from
disk on every call, and nothing stops a step's own `apply` from writing to
the document it is itself part of. Step 1's apply rewrites `0046-doc.md` (a
RELATIVE path — the test copies this fixture into the workdir as
`0046-doc.md`, keeping the numeric ID prefix the linter's scope computation
requires, and invokes the runner against that copy) to strip step 2's entire
` ```bash role=apply ` fence, identified by a marker string unique to it.
Step 1 has already been captured as a string and is already executing by
the time it does this, so the mutation cannot affect step 1's own outcome
— only step 2's, whose apply the dispatch loop has not yet extracted.

## Steps

### Step 1: Applies, then edits the document itself

**Idempotency check:**
```bash role=check
test -f s1.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "s1" > s1.txt
awk '
  /^```bash role=apply$/ { buf = $0 ORS; instate = 1; next }
  instate && /^```$/ {
    buf = buf $0 ORS
    if (buf ~ /STEP2-APPLY-MARKER/) { instate = 0; buf = ""; next }
    printf "%s", buf
    instate = 0; buf = ""
    next
  }
  instate { buf = buf $0 ORS; next }
  { print }
' 0046-doc.md > 0046-doc.md.new && mv 0046-doc.md.new 0046-doc.md
```

**Rollback:**
```bash role=rollback
rm -f s1.txt
```

### Step 2: Its apply fence is gone by the time the runner asks for it

**Idempotency check:**
```bash role=check
test -f s2.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "STEP2-APPLY-MARKER" > s2.txt
```

**Rollback:**
```bash role=rollback
rm -f s2.txt
```
