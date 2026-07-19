# ADR-0020: The always-loaded instruction file carries §11 and a pointer, nothing more

**Status**: Accepted  **Date**: 2026-07-19  **Supersedes**: —
**Spec trajectory:** v0.10.0 (§12 addition — "Instruction-surface economy")

## Context

Every host runtime injects one project-instruction file into context on
every turn: `CLAUDE.md` for Claude Code, `AGENTS.md` for codex and opencode.
Its cost is not paid once per session — it is paid **per turn**, including
turns that never touch code. The trigger skill (`SKILL.md`), by contrast, is
loaded lazily, on exactly the code-touching turns where the workflow binds.

The spec has always had opinions about *where in* the eager file prose goes.
§12's "Placement of behavior-critical prose (advisory)" says the §11 block
lives near the top and that "long auxiliary discussion … lives near the bottom
or in an ADR." It has never had an opinion about *what belongs in that file at
all*. That gap is not theoretical — the fleet split on it:

| Host | Always-loaded file | Shape |
|---|---|---|
| claude-workflow | `CLAUDE.md`, 98 lines | §11 block + trigger-skill pointer |
| codex-workflow | `AGENTS.md`, ~220–250 lines | §11 + gate table + routing + §15 ritual tail + session-handoff |
| opencode-workflow | `AGENTS.md`, ~220–250 lines | same as codex (forked from it) |
| pi (retired) | — | followed the heavy pattern |

`claude-workflow` puts the gate table, task-size routing, the §15 ritual tail,
and the session-handoff procedure in `skill/SKILL.md`, where they load when
they are needed. The `AGENTS.md` hosts inline all of it. Both are legal today,
because the spec never said otherwise — so the divergence was never a
conformance finding, and each host re-litigated the question locally.

There is also a latent inconsistency: §15 already **requires** the
knowledge-capture ritual to live in "the host's SKILL.md (or equivalent)."
Inlining that tail into `AGENTS.md` is off-pattern against an existing MUST,
not merely against taste.

Two mechanisms make eager weight costly rather than merely inelegant:

1. **Per-turn re-billing.** Eager tokens are charged on every request, so a
   150-line delta between hosts is a 150-line delta *per turn*, for the life
   of the session.
2. **Position.** Models systematically underweight content in the middle of
   long contexts (Liu et al., *Lost in the Middle*, arXiv:2307.03172 — the
   citation §12 already reasons from). Padding the eager file with procedure
   pushes the §11 block toward exactly the position the placement advisory
   exists to avoid. The two failure modes compound.

## Decision

**Codify claude-workflow's split as a §12 convention at SHOULD level.**

The always-loaded instruction file SHOULD carry:

- the §11 canonical block, verbatim, near the top, and
- a short pointer to the trigger skill.

Procedural and reference content needed only once a code task is underway
SHOULD live in the lazily-loaded trigger skill or a workflow-config: the §02
gate-binding table, task-size routing, the §15 ritual tail, session-handoff,
and gate-procedure prose (e.g. a plan-review runbook). Where a runtime
enforces a gate programmatically, the **hook wiring** stays wherever the
runtime requires it; only the explanatory prose moves.

§01 (commitment ritual), §03 (rationalization table), and §04 (red flags) MAY
move to the trigger skill, since it loads on precisely the turns where those
blocks bind — but a host MAY keep them eager if it judges the budget
affordable. These are the judgment cases, so the spec declines to force them.

This extends §12 from ordering to membership, which is why it lands in §12
rather than as a new section: same file, same citation, same concern.

## Alternatives Rejected

- **Make it a MUST.** Rejected as over-reach. §02 and §09 deliberately leave
  the host's instruction-file idiom to the host — §09 speaks of "the host's
  instruction file" without prescribing its contents, and hosts differ in what
  their runtimes will even read lazily. A MUST would convert three conformant
  hosts into non-conformant ones overnight for a cost concern, not a
  correctness one. SHOULD matches the tone of the adjacent branchy-workflow
  requirement, which likewise moves a host above the bar without gating.
- **Leave it to host discretion.** Rejected: that *is* the status quo, and it
  is what produced the drift. Two hosts converged on one shape and two on the
  opposite, with no written basis for either, so each new host re-derives the
  answer and each review re-argues it.
- **Specify a hard eager-token budget (e.g. "≤ 2k tokens").** Rejected as
  unmeasurable across runtimes: tokenizers differ, hosts inject different
  scaffolding around the file, and a line count is a proxy for the real
  concern (membership) that would go stale the moment a host reformats. The
  membership rule states the intent directly and is checkable by reading the
  file.
- **Put it in a new section.** Rejected: §12 already owns authoring
  conventions for instruction files and already cites Liu et al. for the
  neighbouring placement advisory. A new section would split one concern
  across two citations.

## Consequences

- **`claude-workflow` already conforms.** Its 98-line `CLAUDE.md` is the
  reference shape named in the spec text. No action; it may re-assert at
  0.10.0 opportunistically.
- **`codex-workflow` and `opencode-workflow` adopt by slimming** their
  `AGENTS.md` and bumping `implements_spec`, each via its own migration and
  adoption PR. Neither is non-conformant in the meantime: a host at 0.9.x
  remains conformant for its 0.9.x claim, and a host at 0.10.0 with a heavy
  eager file is below a SHOULD, not outside the spec.
- **No canonical-prose bytes change.** §01/§03/§04/§05/§11 are untouched, so
  `tools/drift-report.sh` — which scores canonical-block presence in each
  host's declared prose files — is unaffected and continues to pass.
- **A follow-on tension to watch:** if a host moves §01/§03/§04 into its
  trigger skill, the drift report's declared prose paths for that host must
  move with them (ADR-0019's `HOSTS` table). The tool fails loudly (`ERROR`)
  rather than silently in that case, which is the intended behavior, but the
  one-line edit is easy to forget during an adoption PR.

## References

- Liu, N. F., Lin, K., Hewitt, J., Paranjape, A., Bevilacqua, M., Petroni, F.,
  Liang, P. *Lost in the Middle: How Language Models Use Long Contexts.*
  arXiv:2307.03172. (TACL 2024.)
- ADR-0019 — drift report checks a declared prose set, not the whole clone.
- spec/12 — "Placement of behavior-critical prose (advisory)", the ordering
  rule this membership rule extends.
- spec/15 — already requires the knowledge-capture ritual to live in the
  host's SKILL.md or equivalent.
