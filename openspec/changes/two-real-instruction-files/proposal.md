# Two real instruction files, kept identical by the gate

Replace the `CLAUDE.md` symlink with a second regular file, and enforce by check
what the symlink enforced by construction.

The current spec asked for exactly this decision and refused to let it arrive by
the back door: *"Symlinks are assumed to work… If that changes, it is a new
decision and not a fallback smuggled in as robustness."* This is that decision,
made on its merits rather than as a fallback.

## Why the symlink stops being worth it

Its guarantee is real: two names, one inode, no drift possible. But the price is
that a mechanism delivering an **eight-line pointer** takes ownership of the
**entire file**.

Measured across the repositories that carry the section: cparx's `AGENTS.md` is
280 lines of which 13 are the workflow block; callbot's is 542 lines with none;
core's own is 54 with none. The workflow's share is at most 5%. The other 95% is
architecture notes, connection rules, conventions — content the workflow has no
stake in and cannot regenerate.

On 2026-08-10 that disproportion became concrete. The initializer set out to add
a pointer and instead left `callbot` and `fx-signal-agent` with both names as
mutual symlinks: `ELOOP` on every read, 22,292 bytes of callbot's content gone
from the worktree, undetected for about 36 hours because an unreadable
instruction file is indistinguishable from an absent one. The guards are fixed;
the blast radius is not, and it is the blast radius that made a guard bug into
data loss.

Three costs are structural rather than accidental:

- **Git stores the link target, not the content.** `git show HEAD:CLAUDE.md`
  prints `AGENTS.md`. Anything reading the object store rather than the worktree
  — `git grep <rev>`, some CI steps, GitHub's web view — sees a path where the
  instructions should be.
- **Windows checks it out as a one-line text file** unless developer mode is on,
  so an agent there reads the string `AGENTS.md` and nothing else.
- **Adoption is not additive.** A repository holding only `CLAUDE.md` gets it
  moved to `AGENTS.md`. Content survives, but the file relocates and its
  readership silently widens from Claude to all five hosts — the script prints a
  disclosure saying so, which is an admission that this is a semantic change and
  not a formatting one.

## What replaces it

Both names are regular files with identical content. The initializer's only
write is between the markers: it inserts or updates the workflow block in
whichever files exist and creates a file containing just the block where one
does not. It never moves, replaces, links or deletes a file.

The equality the symlink gave by construction becomes a gate check: `AGENTS.md`
and `CLAUDE.md` must be byte-identical, and a commit where they diverge fails.
That is the trade — machinery for blast radius — and it is only worth taking
because the check ships with the writer.

**It has to ship with the writer.** This repository has already run the other
experiment: the six "auto-synced" blocks removed from the fleet last week were
GSD's, kept in step by `normalize-claude-md.sh`. GSD was retired on 2026-07-28,
the syncer went with it, and the blocks went on claiming to be auto-synced for
months while nothing synced them. On this machine that script survives only in a
pre-install snapshot and a template — it was never live. A writer without a
check is that outcome again.

## Migration

Five repositories carry a link today and each has its link replaced by a copy of
the content: `agenticapps-workflow-core` (54 lines), `callbot` (542), `cparx`
(280), `fx-signal-agent` (303), `cmux` (274). Two of those are inverted —
`AGENTS.md` is the link — which is itself an argument: the arrangement has a
direction that a sweep already got backwards once, and two real files have no
direction to get wrong.

## Non-goals

Host-specific content stays out of scope. The two files are identical today and
the check requires them to stay identical; a repository that genuinely needs
different instructions per host is a separate decision with its own reasons, and
nothing here should be read as opening that door quietly.
