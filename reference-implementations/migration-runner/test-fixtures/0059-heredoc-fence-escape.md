---
id: 0059
slug: heredoc-fence-escape
title: Emit a fenced code block from a migration, both documented ways
from_version: 3.4.0
to_version: 3.5.0
migration_format: executable
applies_to:
  - NOTES.md
---

# Migration 0059 — the two documented escapes, CONFORMANT

THIS FIXTURE IS EXPECTED TO LINT CLEAN AND RUN. It is the counterpart to
`0052-bad-l9-heredoc-fence.md`: the same thing that migration was trying to do
— emit a fenced code block into a file — written the two ways the README
documents, so that "there is an escape" is an executed fact rather than a
claim. A four-backtick outer fence is NOT one of them: it cannot carry a role
tag at all (`substr($0,4)` starts with a backtick and fails the info-string
grammar), which is why the README names these two instead.

Step 1 uses `printf`, which reproduces the payload byte-for-byte with no
leading whitespace. Step 2 indents the nested fence by one space, which keeps
it below CommonMark's three-space limit so the emitted block still renders as a
fenced block — at the cost of that one leading space appearing in the file.

## Steps

### Step 1: emit a fence via printf

**Idempotency check:**
```bash role=check
grep -q '^## Running the suite$' NOTES.md
```

**Pre-condition:**
```bash role=precondition
test -f NOTES.md
```

**Apply:**
```bash role=apply
{
  printf '%s\n' ''
  printf '%s\n' '## Running the suite'
  printf '%s\n' ''
  printf '%s\n' '```bash'
  printf '%s\n' 'bash tools/migration-runner.test.sh'
  printf '%s\n' '```'
} >> NOTES.md
```

**Verify:**
```bash role=verify
grep -qx '```bash' NOTES.md && grep -qx 'bash tools/migration-runner.test.sh' NOTES.md
```

**Rollback:**
```bash role=rollback
sed -i '' '/^## Running the suite$/,$d' NOTES.md
```

### Step 2: emit a fence via an indented heredoc

**Idempotency check:**
```bash role=check
grep -q '^## Indented escape$' NOTES.md
```

**Pre-condition:**
```bash role=precondition
test -f NOTES.md
```

**Apply:**
```bash role=apply
cat >> NOTES.md <<'EOF'

## Indented escape

 ```text
 payload
 ```
EOF
```

**Verify:**
```bash role=verify
grep -qx ' ```text' NOTES.md
```

**Rollback:**
```bash role=rollback
sed -i '' '/^## Indented escape$/,$d' NOTES.md
```
