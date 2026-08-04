---
id: 0045
slug: unclosed-fence-verify
title: An in-scope, otherwise-conformant migration whose verify fence is never closed
from_version: 1.10.0
to_version: 1.11.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0045 — unclosed verify fence at end of file

Same defect class as 0041-unclosed-fence-precondition.md, exercised against
`verify` instead: `mr_roles` (what L1 is built on) prints a role from the
fence's OPENING line, while `mr_block` (what the runner's verify call site
actually uses) only confirms it on the CLOSING line. An unclosed `verify`
fence at EOF is therefore PRESENT to `roles` — so the dispatch loop's
`roles | grep -qx verify` sees it and attempts to run it — but ABSENT to
`block`, which is exactly what makes the apply/verify BLOCK_MISSING branch
in run-migration.sh reachable rather than dead code. L7 catches this at
lint time (this fixture lints dirty under the CURRENT linter, unlike 0041
which was clean before L7 existed), so a normal invocation is refused
before dispatch ever begins; the dispatch-loop branch itself is reached
here only via the same stub-collaborator technique used for
0042/0044 (a stubbed lint gate that always exits 0).

## Steps

### Step 1: check/precondition/apply/rollback close normally; verify does not

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```

**Verify:**
```bash role=verify
grep -q '^applied$' fixture.txt
