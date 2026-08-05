---
id: 0062
slug: l10-backslash-bare-fence
title: Document the suite
from_version: 3.5.0
to_version: 3.6.0
migration_format: executable
applies_to:
  - NOTES.md
---

# Migration 0062 — Critical 1, reachable again through `<<\EOF`

THIS FIXTURE IS EXPECTED TO BE REJECTED. It is the whole-branch review's
Critical 1 reproduced verbatim against the linter that was supposed to have
closed it, and it fired NEITHER rule:

- **L9 is silent by design.** The line that truncates the apply body is a BARE
  three-backtick line. A CommonMark closing fence may not carry an info
  string, so L9 only fires on a terminator that does — and an ordinary
  markdown fenced block is opened with a bare delimiter, which is exactly what
  a migration emitting one writes.
- **L10 was silent by omission.** Its delimiter parser accepted `<<WORD`,
  `<<'WORD'` and `<<"WORD"`. It did not accept `<<\WORD` — bash's third
  quoting form, which bash 3.2 treats identically to the single-quoted one. It
  parsed no delimiter, tracked no pending heredoc, and reported nothing.

RED, against the real CLI, before the backslash fix:

    $ lint-migration.sh --host claude-workflow 0062-l10-backslash-bare-fence.md
    $ echo $?
    0
    $ run-migration.sh --host claude-workflow 0062-...md wd
    step 1: applied            (rc 0)
    $ cat wd/NOTES.md
    ## Running the suite       <- and NOTHING else; the payload is truncated
    $ run-migration.sh --host claude-workflow 0062-...md wd
    step 1: skipped (already applied)   <- self-certifies as done, forever

The step's own idempotency check is written against `## Running the suite`,
which is the part that survives truncation — so the second run reads the
truncated file as proof the migration is complete.

The backslash on the delimiter below and the BARE fence line inside the
heredoc are both load-bearing. Quoting the delimiter any other way, or giving
that fence line an info string, makes this fixture assert nothing.

## Steps

### Step 1: document the suite

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
cat >> NOTES.md <<\EOF
## Running the suite

```
bash tools/migration-runner.test.sh
```
EOF
```

**Rollback:**
```bash role=rollback
sed -i.bak '/^## Running the suite$/,$d' NOTES.md && rm -f NOTES.md.bak
```
