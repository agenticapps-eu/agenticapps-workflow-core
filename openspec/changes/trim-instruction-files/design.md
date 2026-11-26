# Design

## The section after this change

```
<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
<!-- section-version: 1.2.0 -->

## The AgenticApps workflow

Code, spec and decision-record work here follows the `agentic-apps-workflow`
skill. Add no copies of workflow skills, hooks or host config: `install.sh`
provides them machine-level.

Decision records live in `<home>` and nowhere else, whatever directory an
installed skill defaults to. Once merged, a record is append-only: correct it
with a new record.

<!-- END: agentic-apps-workflow sections -->
```

## Where each rule lands, and why

| Rule | Lands in | Why there |
|---|---|---|
| follow the skill | section | the pointer is the section's job; hosts without a global pointer depend on it |
| no repo-local surfaces | section | an agent adds a repo-local skill on any turn, not only code turns |
| decision home | section | a repository fact no machine supplies (unchanged) |
| records append-only | section | records are edited on doc turns, where the skill may not load |
| glossary is `CONTEXT.md` | skill only (already there) | fleet constant; needed only when writing the glossary |
| gate blocks on two conditions | skill | needed when a commit is blocked, which is a code turn |
| removed-tool residue is stale | skill | stale docs are read during code work; the skill reaches all five hosts |

A rule lives in the section or in the skill, never both.

## Rejected

- **Cut the pointer, trust the description trigger.** Cheaper by ~20 words. Rejected
  because Codex, opencode and pi carry no global workflow pointer, so the section
  is the only in-file sign that the loop applies.
- **Put append-only in the skill's Decisions section.** Rejected: the skill is not
  loaded on a turn that only edits a record, which is exactly when the rule binds.
- **Keep core's gate explanation in core's file.** Rejected: it duplicates the
  skill; the fix is to make the skill right, then cut the copy.

## The gate wording, fixed at its owner

`change-gate-enforcement` says the gate blocks on "exactly one condition" and,
900 lines later, requires it to fail a commit whose instruction pair differs.
The skill, `docs/WORKFLOW.md` and `docs/HOW-IT-FITS-TOGETHER.md` copied the first
sentence. The fix is at the owner: one condition blocks an edit, a commit is
blocked on that and on the pair. The skill and the two docs then say the same.

## Plan-review round 1 (codex, opencode REQUEST-CHANGES; gemini APPROVE)

Folded in: the ban is limited to copies of what the workflow publishes, with
core's sources exempt; the pointer names decision-record work; append-only binds
once merged; the gate sentence is fixed in the spec and both docs, not only the
skill; the residue rule says what to do; a 1.1.0 fixture is added. Not taken: a
test for the skill's prose — no test reads skill text today, and adding one is
tooling this change does not need. One round, then decide.

## Not locked

No ADR. The section's prose is versioned and changes again whenever the template
does; nothing here is hard to reverse.
