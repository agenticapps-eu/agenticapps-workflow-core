---
id: 0058
slug: bad-l10-mistyped-heredoc
title: Append release notes (heredoc terminator mistyped)
from_version: 3.3.0
to_version: 3.4.0
migration_format: executable
applies_to:
  - NOTES.md
---

# Migration 0058 — an unterminated heredoc with no nested fence anywhere

THIS FIXTURE IS EXPECTED TO FAIL THE LINTER, on L10 and ONLY L10. It exists to
show that L10 is not a restatement of L9: there is no nested fence here at all,
every fence opens and closes normally, and the apply body is non-empty and
comment-free — so L7, L8 and L9 all pass it. The heredoc's terminator is simply
mistyped (`EOFF` for `EOF`).

Run for real, `bash -c` on this body writes the partial payload and EXITS 0, so
the apply "succeeds" and the migration reports done. That is the same
silent-partial-write outcome the nested-fence truncation produces, reached by a
different route.

## Steps

### Step 1: append the release notes

**Idempotency check:**
```bash role=check
grep -q "^## Release notes" NOTES.md
```

**Pre-condition:**
```bash role=precondition
test -f NOTES.md
```

**Apply:**
```bash role=apply
cat >> NOTES.md <<'EOF'

## Release notes

Everything below this line belongs to the payload.
EOFF
```

**Rollback:**
```bash role=rollback
sed -i.bak '/^## Release notes$/,$d' NOTES.md && rm -f NOTES.md.bak
```
