# The initializer destroys the instruction file it exists to establish

`init-project.sh` can turn a repository's real instruction file into a symlink
loop. Both names end at mode 120000 pointing at each other, every read returns
`ELOOP`, and the content is gone from the worktree. It has already happened in
two repositories on this machine and went undetected for about 36 hours across
every host.

## Why now

An unreadable instruction file is indistinguishable, from the outside, from a
repository that never had one. Nothing in the fleet notices. Every agent on
every host silently loses the rules it was supposed to be operating under, and
the only symptom is an error message inside a tool call that no one reads.

## The defect

The initializer refuses hostile starting states rather than repairing them, and
two of those refusals dereference symlinks when they must not.

**The `cmp` guard is vacuous in exactly the case it exists for.** At line 68 the
condition is `[ -f AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]`, and
then `cmp -s AGENTS.md CLAUDE.md` must succeed or the run dies. `-f` and `cmp`
both follow links. When `AGENTS.md` is already a symlink to `CLAUDE.md`, this
compares `CLAUDE.md` to itself: trivially identical, never a refusal. The guard
that protects divergent content is defeated by the one arrangement that needs
it.

**The link guard asks about the wrong file.** At line 125, `[ -L CLAUDE.md ]`
asks "is CLAUDE.md already a link?". The condition that produces a loop is
`AGENTS.md` being a link, and that is never tested. So the else-branch at
135–138 `mv -f`s a fresh symlink over the real instruction file.

The comment at 128–134 licenses that `mv -f` with "`cmp -s` above has already
proved the two byte-identical, so it all survives in AGENTS.md". In this
arrangement `AGENTS.md` was a link back to `CLAUDE.md`, so nothing survived.
The comment documents a guarantee the code does not provide, and correcting it
is part of the fix.

## Field evidence

| Repository | `AGENTS.md` | `CLAUDE.md` | Read |
|---|---|---|---|
| `factiv/callbot` | 120000 `681311eb` | 120000 `47dc3e3d` | `ELOOP` |
| `factiv/fx-signal-agent` | 120000 `681311eb` | 120000 `47dc3e3d` | `ELOOP` |

Both are broken on `main` and in sync with origin. The blob SHAs are identical
across two unrelated repositories, which is what rules out two hand edits and
names a common scaffolder as the origin. Introduced 2026-08-08 19:46; measured
2026-08-10.

## What changes

1. Both guards become symlink-aware — the link is tested before `-f`/`-e`, and
   `cmp` is never allowed to compare a path to itself.
2. An explicit refusal for `AGENTS.md` being a symlink, in the shape of the
   refusals already there: name what it points at, name what the operator
   should do, and stop. Refuse, do not repair.
3. A positive final assertion. Before exiting 0, both names must be *readable*
   and resolve to the same non-empty content. `-L` and `readlink` cannot detect
   `ELOOP`; only a read can, which is why the existing structural assertions
   passed over two broken repositories.
4. A report-only detector that scans a set of repository roots and exits
   non-zero if any instruction file is unreadable, empty, dangling, or half of
   a mutual-symlink pair.

## Non-goals

**The detector must not write to any repository.** Recovering the correct
content is per-repository judgement — the history has to be read and the right
blob chosen. A generic "restore the last mode-100644 blob" heuristic would
silently revert legitimate edits made after the breakage, in the one file that
governs every agent's behaviour. Report; let a human decide.

Repairing `callbot` and `fx-signal-agent` is not in this change either. This
change stops the bleeding and makes the wound visible; the two repositories are
restored by hand, per repository, afterwards.
