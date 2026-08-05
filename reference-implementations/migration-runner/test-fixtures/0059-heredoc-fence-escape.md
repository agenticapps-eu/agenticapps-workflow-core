---
id: 0059
slug: heredoc-fence-escape
title: Emit a fenced code block from a migration, all three documented ways
from_version: 3.4.0
to_version: 3.5.0
migration_format: executable
applies_to:
  - NOTES.md
---

# Migration 0059 — the three documented escapes, CONFORMANT

THIS FIXTURE IS EXPECTED TO LINT CLEAN AND RUN. It is the counterpart to
`0052-bad-l9-heredoc-fence.md`: the same thing that migration was trying to do
— emit a fenced code block into a file — written the three ways the README
documents, so that "there is an escape" is an executed fact rather than a
claim. A four-backtick outer fence is NOT one of them: it cannot carry a role
tag at all (`substr($0,4)` starts with a backtick and fails the info-string
grammar), which is why the README names these three instead.

Step 1 uses `printf`, which reproduces the payload byte-for-byte with no
leading whitespace. Step 2 indents the nested fence by one space, which keeps
it below CommonMark's three-space limit so the emitted block still renders as a
fenced block — at the cost of that one leading space appearing in the file.

Step 3 uses `<<-` with a TAB-indented payload. `<<-` strips leading tabs from
every body line before the shell hands it on, so the nested fence is at column
1 in the migration's own source (where this format's fence state machine, which
tests `index($0, "```") == 1`, therefore does not see it) and ALSO at column 1
in the emitted file. That makes it byte-exact like step 1 and heredoc-shaped
like step 2, with neither the one-space cost nor the per-line `printf`.

THE TABS IN STEP 3 ARE LOAD-BEARING AND MUST NOT BE CONVERTED TO SPACES.
`<<-` strips tabs only — spaces are preserved verbatim, so an editor or a
formatter that expands them silently converts step 3 from an escape into
0052's defect. This fixture's byte-exact assertion in
tools/migration-runner.test.sh is what catches that.

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
sed -i.bak '/^## Running the suite$/,$d' NOTES.md && rm -f NOTES.md.bak
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
sed -i.bak '/^## Indented escape$/,$d' NOTES.md && rm -f NOTES.md.bak
```

### Step 3: emit a fence via a tab-stripped heredoc

**Idempotency check:**
```bash role=check
grep -q '^## Dash escape$' NOTES.md
```

**Pre-condition:**
```bash role=precondition
test -f NOTES.md
```

**Apply:**
```bash role=apply
cat >> NOTES.md <<-'EOF'
	
	## Dash escape
	
	```text
	payload
	```
	EOF
```

**Verify:**
```bash role=verify
grep -qx '```text' NOTES.md && grep -qx 'payload' NOTES.md
```

**Rollback:**
```bash role=rollback
sed -i.bak '/^## Dash escape$/,$d' NOTES.md && rm -f NOTES.md.bak
```
