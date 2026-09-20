# ADR-0031: Bound skills' defaults are overridden machine-level, and the instruction file names the decision home

**Status:** Accepted
**Date:** 2026-09-20
**Linear:** —

## Context

Planning skills installed from `mattpocock/skills` write decision records to
`docs/adr/` and expect a per-repository configurator (`setup-matt-pocock-skills`)
to redirect them. The fleet keeps records in `docs/decisions/`, core in `adrs/`.
The configurator writes `docs/agents/*.md` into the repository and edits one
instruction-file name, which `project-onboarding` and the byte-identity gate
check both forbid. It was run twice on 2026-09-20 before this was noticed:
neuroflash-agent #110 (closed unmerged) and cparx #242 (merged, reverted).

## Decision

Overrides of a bound skill's defaults are carried machine-level: the rules for
records live in the `agentic-apps-workflow` skill; the one fact the skills get
wrong — where this repository's records live — is written by `init-project`
into the managed instruction-file section, because that file is loaded on every
turn and the skill is not. Bound skills are never patched and their
configurators are never run.

## Rejected alternatives

- **Run the configurator per repository.** Writes repository configuration the
  onboarding capability exists to keep out, and breaks the byte-identity of
  `AGENTS.md`/`CLAUDE.md`.
- **Patch the upstream skills.** Vendoring (ADR-0024); `npx skills update`
  would silently undo it.
- **The skill alone, no instruction-file line.** The skill is model-invoked; a
  bare `/grill-me` can run without it and `docs/adr/` then wins.
- **Put the ADR rules in the instruction file.** Copies behaviour into every
  repository — the drift the section's "pointer, never a copy" design exists to
  prevent. Only the location, a fact about the repository, goes there.
- **Migrate every repository to `docs/decisions/`.** Moves history for a naming
  preference; one home per repository is the invariant, not one name.

## Consequences

`init-project` 2.2.0 resolves the home among `docs/decisions/`, `docs/adr/` and
`adrs/` and refuses a repository with more than one. Existing repositories
receive the line by re-running the initializer. A new bound skill that brings
its own storage default is overridden the same way: a rule in the skill, a
fact in the section — never its configurator.
