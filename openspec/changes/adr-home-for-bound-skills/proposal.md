# One home for decision records, whoever writes them

Bound planning skills now write decision records and a glossary on their own.
They pick a different directory from the one the fleet uses, and the only
per-repository fix they offer breaks two things this workflow requires. This
change puts the decision in the workflow skill, machine-level, where every host
reads it.

## What arrived

On 2026-09-20 `mattpocock/skills` (v1.2.3) was installed machine-wide with
`npx skills add`, into the shared `~/.agents/skills` store the other hosts read.
Four of its skills are wanted: `grill-me`, `grill-with-docs`,
`improve-codebase-architecture` and `wayfinder`. Three of them reach
`domain-modeling`, and that skill writes records to `docs/adr/`, numbered by
scanning that directory. `improve-codebase-architecture` reads `docs/adr/` to
avoid re-suggesting rejected refactors — it will find nothing in this fleet and
re-litigate every one.

The fleet's home is `docs/decisions/`, which `spec/00-overview.md` names. Measured
on 2026-09-20: cparx 44 records, callbot 16, observability 8, fx-signal-agent 6,
fbc-platform 5, stimmung 1. Two directories use `docs/adr/` (neuroflash-agent 8,
fx-signal-agent's `tokentelemetry/` 5), and fx-signal-agent numbers by date
(`ADR-2026-05-13-…`), not by sequence.

## Why the skill's own fix is not available

The skills expect `/setup-matt-pocock-skills` to run once per repository. It
writes `docs/agents/{issue-tracker,domain}.md` and inserts an `## Agent skills`
block into **one** instruction file — `CLAUDE.md` if it exists. Both results
are non-conforming here:

- `project-onboarding` allows a repository exactly two workflow artifacts,
  `openspec/` and the instruction file. Per-repository skill configuration is
  what that requirement exists to keep out.
- The instruction file exists under two byte-identical names, and the gate fails
  a commit where they differ. A writer that edits one name produces exactly
  that commit.

Patching the upstream skills is vendoring, which ADR-0024 forbids, and
`npx skills update` would undo it anyway.

## What changes

The workflow skill gains one section that decides, for every bound skill, where
records and the glossary live, when a record is required, and what it must
contain. The skill is already loaded on every design and code-touching turn on
every host, so the override needs no per-repository step and survives upstream
updates.

**The skill alone is not enough, because it is not always loaded.** It is
model-invoked: a bare `/grill-me` can run without it, and then `domain-modeling`'s
`docs/adr/` wins. The one file every host loads on every turn is the instruction
file. cparx and callbot already name `docs/decisions/` there by hand;
fx-signal-agent, fbc-platform and stimmung do not. So the initializer's section
(1.0.0 → 1.1.0, `init-project` 2.1.0 → 2.2.0) gains one short paragraph naming
the repository's decision home and `CONTEXT.md`. The home is resolved per
repository — whichever of `docs/decisions/`, `docs/adr/` and core's `adrs/`
holds records, `docs/decisions/` if none — so neuroflash-agent is told `docs/adr/`
and core `adrs/`, and neither is handed a second home. More than one holding
records is refused. This keeps the section a
pointer: it states where the records are, a fact about the repository, and
leaves the rules for writing them in the skill. Re-running the initializer
updates the section in place, which is how the fleet receives it.

The two ADR rules are reconciled rather than stacked: the workflow's rule
(Medium and Large changes record every locked decision) says *when a record is
mandatory*; "locked" is defined as hard to reverse *and* the outcome of a real
trade-off. The skill's third criterion — surprising without context — is kept as
the strongest reason to record, not as a condition, because requiring it would
exclude the classic record ("use Postgres") and narrow the existing rule. Records
always name a rejected alternative — `spec/00-overview.md` already defines an ADR
that way, and a real trade-off guarantees there is one. The locked decision this
change makes is ADR-0031.

## Non-goals

No record is moved. A repository that already keeps records in `docs/adr/`
keeps them there; the rule is one home per repository, not a rename. Repositories
receive the new section only by re-running the initializer, one reviewable commit
per repository, after this change ships.
Binding these skills into the loop — grilling in place of brainstorming, the
architecture scan on a cadence, rule sets at design and review time — is a
separate change.
