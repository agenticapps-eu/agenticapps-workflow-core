# ADR-0030: Core binds no database-security or design audit skill

**Status:** Accepted
**Date:** 2026-08-09
**Supersedes:** ADR-0011, ADR-0012
**Linear:** —

## Context

The workflow's gate table bound two conditional gates to upstream skills:

- **`database-security` → `database-sentinel`** (ADR-0012), whose Critical/High
  findings blocked branch close. ADR-0012 also bound `db-pre-launch-audit` to
  the same skill.
- **`design` → `impeccable`** (ADR-0011), which wired `impeccable:critique` and
  `impeccable:audit` at two gate points.

Both bindings became wrong, for different reasons, and the difference matters
because only one of them is a cleanup.

**`database-sentinel` is gone.** The hook was retired in PR #95; the skill
checkout and both host aliases were removed on 2026-08-09 by operator decision.
No host declares the name. The binding named a skill that existed nowhere, and
nothing anywhere went red — an absent gate skill is reported and work continues,
which is precisely why a stale binding can survive indefinitely.

**`impeccable` is not gone, and unbinding it is a policy decision.** It is
installed and resolves by canonical name on every host. The operator's
instruction was that it is "really cool and worth it, but I want to use them on
demand in any of the agents" and that "it shouldn't be bound in the workflow".
A gate fires automatically on its trigger; for an on-demand tool that is the
opposite of what is wanted.

## Decision

**Core binds no skill to `database-security`, `db-pre-launch-audit`, or the
design gate.** The gate table keeps only `qa` among the conditional gates.

The gates themselves are **not removed from §02**. They keep their triggers and
required evidence, so any host with a suitable skill can bind one. §02's binding
guidance changes from "hosts bind" to "hosts **MAY** bind", and §17 records that
each fires only where a host has bound a skill.

`impeccable` remains installed on every host and callable by canonical name. Its
availability is deliberately **not** this workflow's concern: it is bound by
plain symlinks into the shared skill store that no installer here recreates.
That is the trade for having it on demand rather than on a trigger.

## Consequences

**Nothing audits database security by default.** This is the point rather than a
side effect, and it is the one consequence worth stating plainly rather than
burying. ADR-0012's finding still stands on its merits — a generic security
audit and a database-specialist audit are orthogonal, and the `cso` gate does
not cover RLS anti-patterns, definer functions or storage policy. Removing the
binding does not refute that; it accepts the loss because the skill this
repository bound is gone.

**Restoring either gate is a one-row change.** §02 still defines both, so a host
that wants the coverage binds a skill and the gate fires again.

**Risk owner:** the repository operator, who removed `database-sentinel` and
directed that `impeccable` be unbound. Recorded here because a removed control
with no named acceptor is how a gap becomes nobody's.

**Breaking.** Two gates stop firing for every consumer of this workflow, and
§02/§17 are amended with them. Released as spec **2.0.0**; prior-major
conformance claims become obsolete per §09.

**ADR-0011 and ADR-0012 are left unedited.** They are superseded, not amended —
deleting the reasoning is how an artifact gets reintroduced.

## Also removed in the same change

Recorded here rather than in a second ADR, because they share one finding: a
surface that stopped being true went on being shipped, and nothing detected it.

- **`GSD_SKIP_REVIEWS`** — the gate's documented escape hatch, across 29 files.
  It escaped nothing after gate 2.0.0 made reviews non-blocking; its only
  remaining effect was suppressing the review NOTEs, under a name promising to
  proceed without evidence that was in fact present. §18 now forbids retaining a
  review-oriented hatch as a no-op: a documented variable that does nothing
  advertises an escape the host cannot provide.
- **`gate/`** — a whole published gate, pre-2.0.0, that nothing resolved. It
  still defaulted `MIN_REVIEWERS=2`, returned a blocking exit on insufficient
  reviewers, and documented the hatch as live contract. Verified unresolved by
  digest before deletion: the installed copy matches the reference
  implementation, not this one.
- **`workflow-diagram.mmd`** — a byte-level duplicate of `workflow.mmd` carrying
  the same two false statements. Nothing referenced it.
- **Two false statements on `workflow.mmd`** — that code edits are blocked until
  "REVIEWS ≥ 2", and a conditional-gates node naming gates that no longer bind.
  The diagram wins where it and the prose disagree, so a wrong diagram decides
  wrongly.
- **The gate header's `MIN_REVIEWERS` description** — documented as a "blocking
  floor" while the code used it only to select which NOTE prints.

**§13 is not in this change.** Three attempts have proposed retiring
`spec/13-ts-declare-first.md` and all three argued from local machine state — a
skills directory, a deleted symlink, and `install.sh`'s `ARCHIVED` variable. The
section makes its implementing skill's name explicitly host-discretionary, so
local absence proves nothing about it, and measured 2026-08-09 all four host
repositories had live remotes and commits four days old. Retiring it needs an
argument about repository lifecycle and deployed consumers.

**Host-repo residue, recorded rather than patched.** `GSD_SKIP_REVIEWS` survives
in `claude-workflow` (`templates/.claude/claude-md/workflow.md`,
`templates/workflow-config.md`, `setup/snapshot/workflow-config.md`) and in
`codex-workflow` (`skills/setup-codex-agenticapps-workflow/templates/`
`config-hooks.json` and `config-lifecycle.json`). Those are archived host
repositories on this installer's own list and are not edited from here — the
standing rule is to record stale artifacts in them, not to patch them.

**What is deliberately not solved:** the installer has no retired-artifact
sweep, so removing a published artifact here does not remove it from installs on
other machines. This change removed the orphans from this machine and does not
claim more. Dated reports that mention the hatch — `PILOT-REPORT.md`,
`docs/instruction-file-audit-2026-08.md` — are annotated as superseded rather
than rewritten; a record of what was true on its date is not a stale surface.
