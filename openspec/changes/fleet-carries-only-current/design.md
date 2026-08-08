## Context

Written to be executed later, deliberately. `projects-bind-not-copy` establishes
the sweep pattern, the declared-fleet resolution and the both-directions check;
this change reuses all three rather than inventing a second mechanism, so it
starts after that one lands.

The inventory lives in `proposal.md` rather than here, because it is evidence,
not design. What belongs here is why the obvious sweep is wrong.

**The premise this change was built on was false, and the correction is what
this revision is.** Every earlier version said `.planning/` was removed
fleet-wide on 2026-08-05, and reasoned from it in four places. The change's own
table contradicted it: ten repositories still carry the directory. What was
removed that day was the directive, not the directories. Everything downstream
of the false claim — the retirement argument for `agenticapps-roadmap`, the
"product reads directories that no longer exist" reasoning — is re-derived below
or dropped.

## Goals / Non-Goals

**Goals:**

- A repository holds only artifacts of tools the workflow ships today.
- The next removal does not leave the same residue, because the rule says a
  removal includes the sweep — and declares what the sweep is looking for.
- Every deletion of instruction text names the thing that now carries the rule.

**Non-Goals:**

- The two declared surfaces. `projects-bind-not-copy` owns skills and hooks and
  this change does not touch them.
- The four host repositories. `claude-workflow`, `codex-workflow`,
  `opencode-workflow` and `pi-agentic-apps-workflow` hold 390 tracked planning
  files between them and are deleted wholesale by Phase 5b. Cleaning a repository
  scheduled for deletion has a negative return.
- Deciding whether the project `PreToolUse` gate should exist. That is
  `one-enforcement-floor`'s question.

## Decisions

### `.planning/` is deleted outright, and the tracked/untracked distinction is dropped

Earlier revisions made **tracked versus untracked** the criterion and built a
whole requirement on it: untracked leftovers go without ceremony, tracked
content stops the sweep until the change states its disposition. The argument
was sound and its subject is gone. It existed for `agenticapps-roadmap`'s 134
tracked files, and that checkout was deleted on 2026-08-07. In the six
repositories still in scope, the criterion would protect **two files**.

**Decided 2026-08-08 by the operator: delete all of it.** Planning is fully on
OpenSpec. `.planning/` has no second home, no reader, and no writer — keeping a
per-file criterion to protect two files is a mechanism heavier than the thing it
guards.

*Alternative rejected: keep the requirement and let it protect two files.* A
rule is not sized by today's population, and this one would have caught the next
repository with a planning tree. It loses to the fact that there is no next one:
the directive is gone, the writer is dead, and a repository that starts planning
again will do it in `openspec/`.

**Two facts recorded rather than guarded against**, because the deletion was
ordered with both in view:

`stimmung` (7 files) and `neuroflash/mcp-server` (5) hold `.planning/` content
that is untracked **and not gitignored**. That is the one shape with no copy
anywhere — not in git, not in an ignore rule someone wrote deliberately. Both
reviewers flagged untracked-is-not-disposable and they were right about the
shape; the answer is not a guard but visibility, so task 2.6 lists every file
before removing any.

The directories stay deleted only because their writer already died. The
dominant `.planning/` writer fleet-wide was never a project hook — it is
`meta-observer`, a global `SessionEnd` hook in `~/.claude/settings.json` that
wrote `.planning/skill-observations/<stamp>--<sessionId>` in **every repository
opened**. It lives in `agenticapps-dashboard/packages/meta-observer/`, deleted
2026-08-07. The registration still points at the missing path and fires every
session end on a 30-second timeout. `reference-implementations/project-hooks/`
already warned that cleaning these files without unregistering the producer "is
housekeeping that undoes itself"; task 2.7 does the unregistering.

### The invariant needs a declaration, or it is not implementable

"Remove that tool's artifacts from every repository" reads like a complete
instruction and is not one. A tool's name cannot identify its artifacts: GSD
owned `setup-gstack-gsd-superpowers-workflow.md`, whose name says so, and
`workflow-config.md`, whose name does not. Matching on names finds the first and
misses the second, and widening the match until it catches the second starts
deleting files that merely share a word.

So the change declares ownership: tool, removal date, owned paths, append-only.
Append-only matters more than it looks — an entry that can be edited away makes
a forgotten artifact indistinguishable from one nobody ever owned, which is the
failure this whole change is about, one level up.

This is the same shape as `ARTIFACTS` and `SHIMMED-HOOKS`, which already work
and which the check already resolves.

### An exception category, not a list of repositories

The invariant "every declared repository removes every removed tool's artifact"
was unsatisfiable as written, and `agenticapps-roadmap` was the proof:
`scripts/sync-gsd-linear.ts` and `sync.config.json` are artifacts *of* a removed
tool and are also that repository's own product, in its own repository. A check
with no exception must fail forever or be ignored.

*Alternative rejected: name the repository in the spec.* It is simpler and it
would already be wrong — the checkout is gone. The repositories that need the
exception are not knowable in advance, which is exactly what makes this a
category rather than a list.

A preservation entry carries a reason and the reason is reported alongside the
artifact, so a preservation nobody would defend out loud is visible rather than
silent.

### A removal in progress is not an incomplete removal

One PR per repository is the safe way to land a fleet sweep, and it guarantees a
window where some repositories are swept and some are not. Reported as a
violation, that window trains its reader to ignore the check — which is the only
outcome worse than not having one.

So completion is defined as a property of the set: every declared repository
either holds no match or holds a preservation entry. During the window the check
reports *in progress*, with both counts, naming which repositories are on which
side.

This also replaces two requirements that could not be tested. "A removal that
lands only in core SHALL NOT be described as a removal" and "the two SHALL NOT
be separated across releases" constrain commit messages and release timing; no
scenario can check either against a working tree. What is checkable is whether
the file is there.

### Instruction text is deleted last, and only against a named replacement

Several repositories inline `## Coding Discipline` in `CLAUDE.md`, around eighty
lines each. The trigger skill was written to absorb §11 so those copies could
go, and that is the intent — but intent is not evidence, and the evidence that a
rule survives its deletion is that some file still says it.

Core's own `CLAUDE.md` argued this about itself: it kept a workflow section it
called misplaced, "only until the rewritten trigger skill carries it, because
deleting a rule that has no other home deletes the rule." **On 2026-08-08 the
skill demonstrably carried it and the section was cut.** That is not a
precedent by analogy — it is this exact procedure, run once, on the file with
the most readers. The tasks repeat it per repository.

*Alternative rejected: delete every copy, on the grounds that the skill is the
authority.* Fastest, and exactly the move core refused to make on its own file
until the day the evidence arrived. A rule that exists in eight places and then
nowhere is a rule nobody decided to drop.

Two failure modes the reviewers named are now scenarios rather than good
intentions: a replacement that covers *part* of a section, and a replacement
that does not load in the repository whose text is being cut. A skill that is
not reachable from a repository is indistinguishable, from inside that
repository, from no replacement at all.

### No check of its own

`projects-bind-not-copy` builds a check with a declared fleet and two passes.
This change adds requirements, not a second tool. Enforcement lands in that
check's second pass, extended — cheaper than standing up a parallel check that
resolves the same `FLEET` and reports in a different shape. Tasks 5.1–5.3 are
that extension, and they are in this change rather than assumed of the other.

## Risks / Trade-offs

- **The `CLAUDE.md` edits are the real risk.** Deleting a shim is mechanical and
  reversible; deleting eighty lines of coding discipline from eight repositories
  is neither, because nothing else records what those lines said once they are
  gone. The tasks front-load the comparison for that reason.
- **Deleting `.planning/` outright is unrecoverable in two repositories.**
  `stimmung` and `mcp-server` hold untracked, un-ignored files with no copy
  anywhere. Accepted deliberately; mitigated by listing before deleting, not by
  a guard.
- **Written before it is needed.** Four inventory rows were measured on
  2026-08-07 across a fleet that has since lost two repositories. They are upper
  bounds until task 1.1 re-runs them, and they are labelled as such.
- **Scope creep is the standing temptation.** "Everything we do not need any
  more" is unbounded by construction, and the boundary drawn here — artifacts of
  tools the workflow *removed*, as declared — is narrower than it sounds and
  deliberately so. A stale README is not in scope. A command that installs a
  deleted tool is.
