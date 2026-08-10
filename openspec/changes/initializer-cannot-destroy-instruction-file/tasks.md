# Tasks

## 1. Test first

- [x] 1.1 Add the inverted-arrangement case: real `CLAUDE.md`, `AGENTS.md ->
      CLAUDE.md`. Assert non-zero exit, the target named, and `CLAUDE.md`
      byte-identical afterwards.
- [x] 1.2 Add a readability assertion and apply it to the bare-repo case — its
      absence is what let this ship.
- [x] 1.3 Observe RED against the current script and record the output.

## 2. Fix

- [x] 2.1 Refuse when `AGENTS.md` is a symlink, before anything writes.
- [x] 2.2 Stop `cmp` comparing a path to itself.
- [x] 2.3 Correct the comment at 128–134, which claims an invariant the code
      does not provide.
- [x] 2.4 Assert both names are readable and identical before exit 0.
- [x] 2.5 Bump `init-project-version` — the publisher arbitrates on it.
- [x] 2.6 Observe GREEN on the whole suite, twice.

## 3. Reach

- [x] 3.1 Publish via `install.sh`; confirm `~/.agenticapps/bin/init-project.sh`
      carries the fix. That is the copy that runs; per-host directories and
      project copies were measured to hold none.

## 4. Verification

- [x] 4.1 New case fails before the fix, passes after. Both outputs recorded.
- [x] 4.2 `openspec validate --all` green.

## Evidence

RED, before the fix (`tools/init-project.test.sh`):

```
L. AGENTS.md is already a symlink — the arrangement that closes a cycle
  FAIL  an AGENTS.md symlink is refused
        exited 0 — this is the loop being created
  FAIL  CLAUDE.md is still readable and byte-identical
        read: cat: .../CLAUDE.md: Too many levels of symbolic links
  passed: 60   failed: 2
```

GREEN, after: `passed: 62   failed: 0`, and again on a second run.

Published copy — the one that runs — is `init-project-version: 1.2.0` at
`~/.agenticapps/bin/init-project.sh` and carries the refusal. Per-host config
directories and project trees were measured to hold no other copy.

Against an already-broken repository (both names symlinked to each other) the
fixed script exits 1 with `CLAUDE.md is a symlink with no target` and writes
nothing.
