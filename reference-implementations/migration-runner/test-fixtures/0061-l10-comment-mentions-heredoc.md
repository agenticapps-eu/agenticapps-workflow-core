---
id: 0061
slug: l10-comment-mentions-heredoc
title: Append a section, carefully
from_version: 3.5.0
to_version: 3.6.0
migration_format: executable
applies_to:
  - CLAUDE.md
---

# Migration 0061 — the author who READ THE DOCUMENTATION

THIS FIXTURE IS EXPECTED TO LINT CLEAN AND RUN. It is L10's false-accusation
guard, and it is deliberately the most sympathetic possible shape: a migration
that avoids the L9/L10 truncation hazard exactly as this runner's README tells
it to — by emitting the section with `printf` instead of a heredoc — and says
so in a comment.

Before the fix that added the whole-line-comment skip to L10's scan, that
comment was read as shell. The scan found `<<EOF` in PROSE and reported:

    L10: step 1: role 'apply' opens a heredoc delimited by 'EOF' that is
    never terminated in the captured body — running it writes a partial
    payload and still exits 0

Every substantive clause of which is false. There is no heredoc, nothing is
unterminated, and no partial payload is written: the body is valid bash that
does its work and writes the payload whole. (The trailing "and still exits 0"
is true — but it is true of the CORRECT behaviour, which is rather the point.)
`# do not use << here` fired the same way, naming the delimiter `here`.

The rule punished precisely the author who followed the documentation, which
is a worse failure than missing a detection — L8's scan in the same loop had
discarded full-line `#` comments since it was written, so the two halves of
one loop disagreed about what a comment was.

The apostrophes and the `<<` in the comment below are load-bearing. Do not
"tidy" them away: without them this fixture asserts nothing.

## Steps

### Step 1: append the section

**Idempotency check:**
```bash role=check
grep -q '^## Workflow$' CLAUDE.md
```

**Pre-condition:**
```bash role=precondition
test -f CLAUDE.md
```

**Apply:**
```bash role=apply
# Emitted with printf, not <<EOF: a fence delimiter inside a heredoc would
# truncate this block (see the runner README, L9/L10).
{
  printf '%s\n' ''
  printf '%s\n' '## Workflow'
} >> CLAUDE.md
```

**Verify:**
```bash role=verify
grep -qx '## Workflow' CLAUDE.md
```

**Rollback:**
```bash role=rollback
sed -i '' '/^## Workflow$/d' CLAUDE.md
```
