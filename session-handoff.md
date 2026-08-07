# Session Handoff — 2026-08-07 (tenth session)

**Nothing is in flight and nothing is blocked.** `core-installer-one-entry-point`
ran for real, was reviewed three more times and is archived;
`openspec/specs/workflow-installation/spec.md` is durable truth. Two new changes
are proposed and unreviewed. Three changes are now active.

| Branch | State |
|---|---|
| `feat/one-skills-payload` | pushed; **PR #88** retitled and rewritten. Carries the payload, the installer, the real run and the archive |
| `feat/projects-bind-not-copy` | pushed, **no PR yet**. Carries `projects-bind-not-copy` and `fleet-carries-only-current`, both proposal-only |

Detail for the archived change is in
`openspec/changes/archive/2026-08-06-core-installer-one-entry-point/` —
`CODE-REVIEW.md`, `SECURITY-REVIEW.md`, and the round-six and round-seven
sections of `design.md`. This file carries only what lives nowhere else.

## The correction that matters most

**The project hook surface is the host hook, one directory down.** Donald caught
this; I had it wrong for most of the session.

`core-installer-one-entry-point` deleted the host hook for three reasons: with no
active change `gate_check` returns satisfied so it never enforced
spec-before-code (verified at `openspec-change-gate.sh:506`); the condition it
did enforce is caught again at `git commit` and in CI; and it was every
host-specific line in the repository. **All three apply verbatim to
`.claude/settings.json` inside a repository** — that file is Claude-only wherever
it sits. The change closed the surface at `$HOME` and left an identical one
committed in nine checkouts.

Measured in `cparx`, and it is worse than redundant: no `.git/hooks/pre-commit`,
`core.hooksPath` unset globally and locally, and the only invoker of the gate
shim is a `PreToolUse` entry. **The gate fires at neither of the two surfaces
`docs/HOW-IT-FITS-TOGETHER.md` claims for it.**

A git hook is *not* a host hook. `one-enforcement-floor`'s machine-wide
`core.hooksPath` fires for all five hosts and for a person with an editor. That
is the floor and it stays. What goes is `.claude/settings.json`.

Why I missed it: the handoff, the design and the topology doc all stop at "host
hooks dropped" and then leave the project shim standing without saying why. I
read that as settled rather than unfinished.

## The mistake I made, and undid

`git add -A` in the archive commit (`925481a`) swept in three untracked
leftovers: six `.claude/skills/gitnexus/` directories, five
`.planning/skill-observations/` files, and **a 44-line GitNexus section appended
to core's own `CLAUDE.md`** telling agents to run `npx gitnexus analyze`.

Undone in `8e7eaec`: `CLAUDE.md` restored, tracking removed, both paths
`.gitignore`d. The files stay on disk, so **the gitnexus skills still load in this
repo until deleted** — not yet decided.

## What the fleet actually looks like

Measured 2026-08-07 across the nine repositories carrying `openspec/`:

- **Eight carry a committed `.claude/skills/agentic-apps-workflow/`** at four
  byte-sizes (324/331/346/415) across two claimed versions, while core publishes
  235 lines at v4.0.0. `fbc-platform` differs from its three v3.2.0 siblings while
  claiming to be them.
- **Seven bind `normalize-claude-md`**, which is declared on `main` and undeclared
  the moment PR #87 merges — and keeps running either way, because
  `install-project-hooks.sh` carries forward manifest rows outside the declared
  set by design.
- `check-shims.sh` **cannot see any of this**: it iterates the declaration, so it
  detects a missing member and is blind to an extra one.
- `.planning/` survives in nine repositories and **is not one condition** —
  `agenticapps-roadmap` has **134 tracked files** under it.
- `## Coding Discipline` is inlined in eight `CLAUDE.md` files, ~80 lines each.
- `agents-task-viewer` is the clean reference: two shims, two registrations, no
  `normalize-claude-md`, no skill copy.

The six `openspec-*` skills every repo carries are **upstream OpenSpec's** — MIT,
"Requires openspec CLI" — and implement `/opsx:*`. Out of scope everywhere.

## Sequencing, which is now the fragile part

1. `one-enforcement-floor` **before** `projects-bind-not-copy`. cparx has no git
   floor at all today, so removing its `PreToolUse` entry first leaves it with no
   gate rather than a better one.
2. `projects-bind-not-copy` **before PR #87**. #87 retires `normalize-claude-md`
   in core and orphans it in seven repositories; the sweep has to land first so
   #87 keeps the narrow review it already has.
3. `fleet-carries-only-current` **after** `projects-bind-not-copy`, which builds
   the sweep pattern, the declared-fleet resolution and the both-directions check
   it reuses.

## Next session: start here

`one-enforcement-floor` has **no plan review at all** (its task 8.2), no code, and
is now first in the chain. That is the action:

```
REVIEW_TIMEOUT=600 run-plan-review.sh one-enforcement-floor --implementing-host claude
```

`REVIEWER_TIMEOUT` does **not** reach that script — six rounds of opencode's
opinion were lost to that, and it fails silently by not counting the reviewer.

Then plan-review the two new proposals, which are unreviewed and were written
fast.

## Open questions

1. **`database-sentinel` is undecided by design.** It is host-specific like the
   rest, and it is the one hook with a pre-tool argument: it guards a class of
   file before the tool call, and a pre-commit hook cannot stop an agent reading
   a `.env` and putting it somewhere. Keep it and say what it protects that
   commit-time cannot, or remove it with the surface. Not by default.
2. **`docs/HOW-IT-FITS-TOGETHER.md` is provably wrong** — "one gate, two
   surfaces", then projects binding it at a third, and in cparx it fires at
   neither. Queued as task 6.3, not fixed.
3. **`agenticapps-roadmap`'s 134 tracked planning files** are a migration
   decision, not cleanup. `fleet-carries-only-current` refuses to sweep them.
4. **Four check-mode gaps** in `--check`, all reported rather than silent: a host
   called bound on one of two skills; an archived binding reported as plain
   `bound`; core's pre-commit hook never reported; no defined exit status for an
   absent, stale, modified or unreadable artifact.
5. **`is_archived` matches link text, not the resolved target**, and ownership is
   a repository-name substring. Both want a portable `realpath`.
6. **Reported paths carry `/Users/donald` and are unescaped.** Deferred to
   `screen-review-egress` for the third time.
7. **`workflow.mmd` still says the gate requires "REVIEWS ≥ 2".** Untrue since
   gate 2.0.0.
8. **Does `AGENTS.md` still need a workflow section** once the skill carries the
   workflow? `host-neutral-instruction-files` says yes. Still open.
9. **pi reads a fifth directory**, `~/.pi/agent/skills`, neither bound nor swept.
   Measured empty.
10. **PRs #78, #86, #87, #88 are open.** No PR yet for
    `feat/projects-bind-not-copy`.
