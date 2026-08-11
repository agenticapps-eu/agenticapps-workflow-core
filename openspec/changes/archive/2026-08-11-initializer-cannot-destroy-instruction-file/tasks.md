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

## 5. Reconciled before archiving (2026-08-11)

The delta could not be archived as written. `two-real-instruction-files` shipped
on 2026-08-10 and made two of its statements false:

- *"After a correct run the two names **do** resolve to the same inode — that is
  the intended end state."* The intended end state is now two regular files with
  different inodes.
- A scenario asserting `CLAUDE.md` is a symlink to `AGENTS.md` and that
  verification **SHALL succeed**. That arrangement is now refused by the
  initializer and blocked by the commit gate.

Archiving it unchanged would have written both into the live spec.

- [x] 5.1 **Drop `A tool SHALL NOT create a symlink cycle`** — subsumed. The live
      `project-onboarding` already carries `One name is a symlink to the other`,
      `` `CLAUDE.md` is already a symlink to something else ``, `An instruction
      path is a directory or a dangling link`, and `neither name is a symlink`.
      Nothing it said is lost; all of it is said in the capability that owns the
      initializer.
- [x] 5.2 **Keep `The arrangement is verified by reading`**, rewritten for two
      regular files. This is the half that is not stated anywhere else: the
      initializer performs it (`init-project.sh`, three `refusing to report
      success` guards) and no live requirement asks for it. A guarantee that
      exists only as code is one nobody knows to preserve.
- [x] 5.3 **Moved from `host-neutral-instruction-files` to `project-onboarding`.**
      The original placement needed a paragraph of defence — "this constrains what
      a tool may do to a repository", in a capability about what the shared file
      must contain. The initializer's contract lives in `project-onboarding`, and
      the gate's half of the same rule is already live in
      `change-gate-enforcement`.
- [x] 5.4 Added the partial-write scenario. The initializer writes two names in
      sequence and the second can fail, which the read check already catches in
      code and no requirement described.
