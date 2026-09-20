# Design

## Two surfaces, split by what they carry

| Surface | Loaded | Carries |
|---|---|---|
| `agentic-apps-workflow` skill | when the model invokes it | the **rules**: when a record is required, what it holds, `CONTEXT.md`, no configurator, the `.scratch/` tracker |
| instruction-file section (`init-project`) | every turn, every host | one **fact**: this repository's decision home, and that `CONTEXT.md` is the glossary |

The split follows the section's existing rule — a pointer, never a copy. A rule
copied into every repository is a version of it; a location is not a rule, it is
something only the repository can know. Recorded as ADR-0031.

## Resolving the home

Candidates `docs/decisions/`, `docs/adr/`, `adrs/`, in that order. A candidate
holds records if it directly contains a `.md` file other than `README.md` or
`index.md`. No naming scheme is required, because the fleet does not follow one
(cparx carries `phase22-d01-descope-decision.md` beside `NNNN-*.md`). One holder
is the home; none means `docs/decisions/`; more than one is refused before any
write. The directory is named, never created.

Only the root is inspected. `fx-signal-agent/tokentelemetry/docs/adr/` belongs to
a nested sub-project and is not a second home of the parent.

## Decisions made here that are not locked

- The section's paragraph wording, and its placement after the workflow
  paragraph inside the same markers — easily changed with a section-version bump.
- `index.md` excluded alongside `README.md` — cheap to widen.
- Candidate order — only matters for the error message, since two holders are
  refused.

## The lock test

The skill's upstream test is three criteria joined by AND (hard to reverse,
surprising, a real trade-off). Plan-review round 1 showed that this narrows the
workflow's existing "record every locked decision": "use Postgres" is hard to
reverse and a trade-off, and nobody is surprised by it. Surprise is kept as the
strongest reason to record, not as a condition.

## Plan-review round 1 (codex, opencode — both REQUEST-CHANGES)

Accepted and fixed: README counted as a record; `adrs/` unrecognised; fresh-clone
scenario lacked its precondition; `.scratch/` would be committed; the change
lacked its own `design.md` and record; `spec/00-overview.md` still hard-coded
the path; the lock test narrowed the existing rule; no scope for Small changes;
one scenario had no checkable outcome; `CONTEXT.md` collides in name with the
retired per-phase file. Rejected: "fx-signal-agent's nested records are
invisible" — they are under `tokentelemetry/docs/adr/`, a sub-project, not
`docs/adr/`.

## Plan-review round 2 (codex REQUEST-CHANGES; gemini and opencode exit 1)

Round 2 is one counted reviewer, so it is weaker evidence than round 1.
Accepted, all in the skill's prose — the initializer and the section text are
unchanged, so the staged fleet updates stand: a home that goes stale after
initialization stops the skill and is refused by a re-run; numbering is one above
the highest `NNNN-`, today's date for a date-only home, else `0001`; the exclude
file is resolved with `git rev-parse --git-path info/exclude` because `.git` is a
file in a linked worktree, and an already-tracked `.scratch/` stops the skill; an
existing root `CONTEXT.md` that is not a glossary stops the skill (none exists in
the fleet, measured 2026-09-20). Rejected: a retention and PII policy for
`.scratch/` — it is a local file like any other the operator keeps, and this
change neither creates nor widens that exposure.
