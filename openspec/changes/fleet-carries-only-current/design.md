## Context

Written to be executed later, deliberately. `projects-bind-not-copy` establishes
the sweep pattern, the declared-fleet resolution and the both-directions check;
this change reuses all three rather than inventing a second mechanism, so it
starts after that one lands.

The inventory was measured on 2026-08-07 across the nine repositories carrying
`openspec/`, and it is in `proposal.md` rather than here because it is evidence,
not design. What belongs here is why the obvious sweep is wrong.

## Goals / Non-Goals

**Goals:**

- A repository holds only artifacts of tools the workflow ships today.
- The next removal does not leave the same residue, because the rule says a
  removal includes the sweep.
- Every deletion of instruction text names the thing that now carries the rule.

**Non-Goals:**

- The two declared surfaces. `projects-bind-not-copy` owns skills and hooks and
  this change does not touch them.
- The archived host repositories. `claude-workflow`, `codex-workflow` and
  `opencode-workflow` hold 390 tracked planning files between them and are
  deleted wholesale by Phase 5b. Cleaning a repository scheduled for deletion has
  a negative return.
- Deciding whether the project `PreToolUse` gate should exist. That is
  `one-enforcement-floor`'s question.

## Decisions

### `.planning/` is two problems, and the sweep must not conflate them

The path was removed fleet-wide on 2026-08-05 and now reads as leftover. It is
not, uniformly:

| Repository | tracked files |
|---|---:|
| `agenticapps-roadmap` | **134** |
| `opencode-workflow` | 19 (out of scope — deleted by Phase 5b) |
| `fbc-platform`, `fx-signal-agent` | 1 each |
| `cparx`, `agenticapps-dashboard`, core | 0 |

A sweep matching on the directory name deletes `agenticapps-roadmap`'s planning
history and calls it cleanup. The commit message would be true about the path and
false about the content, which is the most dangerous kind of correct.

So the criterion is **tracked versus untracked**, not the path. Untracked
leftovers go without ceremony. Tracked content stops the sweep for that
repository until this change says what happens to it — and for
`agenticapps-roadmap` that is a migration decision belonging to whoever owns that
repository's planning, not to a fleet cleanup.

*Alternative rejected: exclude `agenticapps-roadmap` from the sweep.* Simple, and
it converts a decision into an omission. The next person reads a `FLEET` sweep
that skips one member and cannot tell whether it was considered or missed.

**Decided 2026-08-08: kept, and the reason is retirement.** This was the change's
one open blocker and it is closed by a fact from outside the change rather than
by the migration nobody had time for.

`agenticapps-roadmap` is a **product built on `.planning/`**, not a repository
that merely still has one: `scripts/sync-gsd-linear.ts` walks sibling
repositories' `.planning/` trees and upserts them into Linear, wired as
`pnpm sync:gsd` with a test beside it, and `sync.config.json` names three inputs.
`.planning/` was removed fleet-wide on 2026-08-05, so the product's inputs are
gone and it reads directories that do not exist. The retirement is a consequence
of that, not a coincidence beside it.

Its own 134 tracked files are therefore the development history of a retired
product. "Migrate to `openspec/`" is what you do for a repository someone will
plan in again, and nobody will plan in this one — so the disposition is **keep**,
stated rather than defaulted. Nothing is deleted, which is what the criterion
above required all along; the criterion was never the thing in doubt, the
disposition was.

**`sync-gsd-linear.ts` and `sync.config.json` stay too**, and the boundary is
worth stating because they look like exactly what this change deletes. They are
artifacts *of* a removed tool, but they are also the retired product's own source
code, in the retired product's own repository. Sweeping them is not removing
residue, it is gutting the thing being preserved. The same line the family
instruction file already draws around `agenticapps-dashboard`: reading it is
encouraged, so what is in it stays.

### Instruction text is deleted last, and only against a named replacement

Eight repositories inline `## Coding Discipline` in `CLAUDE.md`, around eighty
lines each. The trigger skill was written to absorb §11 so those copies could go,
and that is the intent — but intent is not evidence, and the evidence that a rule
survives its deletion is that some file still says it.

Core's own `CLAUDE.md` already argues this, about itself: it keeps a workflow
section it calls misplaced, "only until the rewritten trigger skill carries it,
because deleting a rule that has no other home deletes the rule." The same
sentence applies here, so the tasks read the skill against each repository's
section and delete only what the skill demonstrably says.

*Alternative rejected: delete all eight, on the grounds that the skill is the
authority.* Fastest, and it is exactly the move core refused to make on its own
file. A rule that exists in eight places and then nowhere is a rule nobody
decided to drop.

### The retired repositories are swept; the archived ones are not

`agenticapps-dashboard` is retired and its `CLAUDE.md` actively encourages
reading it as an example of the spec discipline. A repository people are told to
read is a repository an agent will open, and an agent that opens it loads what is
there. It is swept.

`agenticapps-roadmap` joins it on 2026-08-08, on the same reasoning rather than a
new one. Retired is not archived: it stays on disk, so whatever it carries stays
loadable, and a repository nobody is working in is one whose stale artifacts have
longer to sit there being read as current.

`claude-workflow`, `codex-workflow` and `opencode-workflow` are archived and
scheduled for deletion. They are not swept, and the difference is not
inconsistency: two are repositories that stay and are read, the others are
repositories that go. **The line is deletion, not activity** — worth stating
plainly, because "retired" and "archived" are close enough in ordinary use that
the next reader will otherwise have to re-derive which side each lands on.

### No check of its own

`projects-bind-not-copy` builds a check with a declared fleet and two passes.
This change adds requirements, not a second tool. Where its rules need
mechanical enforcement — "no artifact of a removed tool" — the natural home is
that check's second pass, extended, and extending it is cheaper than standing up
a parallel one that resolves the same `FLEET` and reports in a different shape.

## Risks / Trade-offs

- **The `CLAUDE.md` edits are the real risk.** Deleting a shim is mechanical and
  reversible; deleting eighty lines of coding discipline from eight repositories
  is neither, because nothing else records what those lines said once they are
  gone. The tasks front-load the comparison for that reason.
- ~~**`agenticapps-roadmap` may block the change.**~~ **Closed 2026-08-08.** The
  repository was retired, which resolves the disposition to *keep* without a
  migration — so the change no longer waits on anything, and the deferral path it
  reserved is unused. Left visible rather than deleted: this was the change's one
  named blocker for seven sessions, and a risk that quietly disappears reads as a
  risk nobody took seriously.
- **Written before it is needed.** The inventory is measured on 2026-08-07 and the
  change executes later, so the counts will drift. Task 1 re-measures rather than
  trusting the table, and the table is dated for that reason.
- **Scope creep is the standing temptation.** "Everything we do not need any
  more" is unbounded by construction, and the boundary drawn here — artifacts of
  tools the workflow *removed* — is narrower than it sounds and deliberately so.
  A stale README is not in scope. A command that installs a deleted tool is.
