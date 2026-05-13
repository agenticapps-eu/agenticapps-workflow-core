# ADR-0011: impeccable as design-quality gate (pre-phase critique + finishing audit)

**Status:** Accepted
**Date:** 2026-05-03
**Linear:** —

## Context

The design-shotgun gate (see spec section 02) generates 3–4 UI variants per phase but
offers no quality filter — every variant reaches the user, including ones that exhibit
the standard AI-slop tells (purple gradients, Inter-everywhere, weak hierarchy,
generic empty states). Picking from a slate that includes obvious slop wastes user
attention and pulls the chosen design toward the median.

`pbakaus/impeccable` is a multi-host skill (Claude Code, Cursor, Gemini, Codex) that
ships:

- 23 commands (`/polish`, `/audit`, `/critique`, `/typeset`, plus 19 more)
- 7 reference files (typography, OKLCH color, spatial design, motion,
  interaction, responsive, UX writing)
- An anti-pattern detector for ~24 AI-slop tells
- Active growth (~1.6k stars at adoption time)

The skill composes naturally with the existing two-stage pipeline:
the design-shotgun gate produces variants → an impeccable critique scores each →
sub-bar variants are eliminated → user picks from the surviving slate.
Finishing-stage `impeccable:audit` then runs against the deployed component
before branch close.

## Decision

Wire `impeccable` into the AgenticApps workflow at two gate points:

1. **Pre-phase (`design_critique`)** — fires after the design-shotgun gate and
   before the user picks. Runs `impeccable:critique` against each variant,
   records scores in UI-SPEC.md, eliminates sub-bar variants. Quality bar
   is a numeric threshold from the critique output (default ≥ 90 — a
   project's workflow-config artifact can override).
2. **Finishing (`impeccable_audit`)** — fires when a frontend-touching
   feature branch is ready to merge. Runs `impeccable:audit` against the
   deployed component. Blocks branch close if Red findings remain unresolved.

Patches landed (per the original action plan §1):

- The host's workflow-config artifact — Pre-Phase hook table row
- The host's hook-config JSON — `pre_phase.design_critique` and
  `finishing.impeccable_audit` entries
- The host's instruction-file sections artifact — Pre-Phase Hook 1 expanded
- The host's enforcement-plan document — Phase planning gates row

## Alternatives Rejected

- **Run impeccable as a Stage 2 reviewer subagent instead of a pre-phase
  gate.** Rejected — by Stage 2 the design is already chosen and partially
  implemented. Catching slop after the user has anchored on a variant means
  either rework or accepting the slop. Pre-phase critique catches it before
  anchor.
- **Run impeccable only at finishing, not pre-phase.** Rejected — same
  anchor problem. Finishing audit alone catches polish issues but not
  fundamental design choice issues (e.g. picking a brutalist layout for a
  consumer payment flow). Pre-phase + finishing gives two distinct catches.
- **Trust the design-shotgun variant generation to avoid slop without an
  external check.** Rejected — design-shotgun is a divergent generator,
  not a quality filter. Asking it to self-filter creates a feedback loop
  bias toward whatever its model considers "safe." Independent critic.
- **Build our own anti-slop detector instead of adopting impeccable.**
  Rejected — duplicating 24 anti-pattern rules + 7 reference docs is months
  of work. Adopt + steal the methodology if needed for our own meta-skills.

## Consequences

**Positive:**
- Variant slates surface higher-quality designs by default; user attention
  is preserved.
- Finishing audit catches polish drift between mockup and implementation.
- Composes cleanly with existing two-stage review (orthogonal — impeccable
  audits design, two-stage review audits code).
- Anti-slop bar improves consistency of client-facing visual identity.

**Negative:**
- Adds one external skill dependency. Bus factor: solo maintainer
  (`pbakaus`); MIT-licensed; can fork if abandoned.
- Pre-phase critique adds ~30 seconds per UI phase. Justified by the cost
  of redoing a design picked from a sub-par slate.
- Quality bar threshold needs project-by-project calibration (default ≥ 90
  may be too strict for prototype phases).

**Follow-ups:**
- After 4 weeks of usage, review which projects override the quality bar
  and at what value. If the default is consistently overridden in one
  direction, adjust.
- Consider a `--prototype` flag that lowers the bar for non-production work.

## References

- `pbakaus/impeccable` skill — installed per host into the host's skills
  directory.
- Composes with: the design-shotgun gate and the code-review gate (spec
  section 02).

---

*This ADR documents a host-agnostic decision. For host-specific bindings (concrete
paths, skill names, plugin invocations), see each host repo's documentation.*

---

## Addendum — 2026-05-13: CLI rename + skill remains canonical

### What changed upstream

`pbakaus/impeccable` published v1.0.1 which **renamed the CLI's `critique` subcommand to `detect`**, then bumped to v2.x. The v1.x publishes have been unpublished from npm; only v2.0.0–v2.1.9 are installable. The new `impeccable detect` CLI emits a finding-list JSON shape, not the `{routes: [{score}]}` scalar shape the v1 CLI emitted under `--json`.

The Claude-host skill `impeccable:critique` at `~/.agents/skills/impeccable/SKILL.md` is **unaffected**. Its `critique [target]` subcommand is documented in `command-metadata.json` and remains the LLM-driven design-review entry point. The skill internally uses sub-agents and may call `npx impeccable detect` as one of its deterministic detector passes — that is an implementation detail of the skill, not part of the host workflow contract.

### Why this matters for hosts

ADR-0011 wires `impeccable:critique` and `impeccable:audit` as **skill hooks** at the `design_critique` and `impeccable_audit` gate points. The `host:skill_name` syntax in workflow-config artifacts (e.g. `claude-workflow/templates/config-hooks.json:27`'s `"skill": "impeccable:critique"`) refers to the **skill**, not the CLI. Those references remain valid and require no change.

What does change: hosts that had built **standalone CI workflows** invoking `npx impeccable critique` (rather than letting Claude invoke the skill) have a broken pipeline. The `agenticapps-dashboard` host shipped such a CI workflow under Phase 6 and silently lost it; see that host's `.planning/phases/DASH-10.5-impeccable-skill-driven-gate/10.5-DECISIONS.md` for the dashboard's response.

### Recommendation for downstream hosts

- **Skill hook syntax (`impeccable:critique`, `impeccable:audit`) is unchanged** and continues to satisfy this ADR's gate-point contract.
- If a host has additionally built a **CLI-based CI gate** that called `npx impeccable critique`: it is broken. Options:
  - Migrate to `npx impeccable detect --json` and adapt to the finding-list output shape (requires new pass/fail semantics — no scalar score).
  - Retire the CI gate and adopt a per-phase artifact model where the developer invokes the skill at phase wrap-up and commits a `<N>-IMPECCABLE.md` artifact alongside the phase docs (this is the path the `agenticapps-dashboard` host chose).
  - Both approaches satisfy the ADR. Choose by host preference.
- **Quality bar threshold (default ≥ 90 in the original Decision section) should be revisited per-host.** The skill-driven scoring band may differ from the v1 CLI's distribution. Hosts adopting the skill-only approach should treat the floor as provisional until they have 2–3 calibration data points.

### What did NOT change

- The two-gate-point model (`design_critique` pre-phase + `impeccable_audit` finishing).
- The skill name (`impeccable:critique`, `impeccable:audit`).
- The `workflow-config.yaml` syntax for hooks.
- The host-agnostic positioning of this ADR — host-specific responses (CI removal in agenticapps-dashboard, no changes in claude-workflow templates because they reference the skill, codex-workflow/pi-agentic-apps-workflow at their discretion) belong in each host's own decision log.

### Trace

- **Reported by:** `agenticapps-dashboard` Phase 10 Gate 4 (2026-05-13). The host's CI pipeline (`.github/workflows/impeccable.yml`) had been silently failing since the v1.0.1 rename — no measured regression in the meantime, evidence that the CI gate was not load-bearing for quality.
- **Verified:** `npx impeccable --help` on 2026-05-13 lists only `detect`, `skills help`, `skills install`, `skills update`, `skills check`. No `critique` subcommand. `npm view impeccable versions` returns v2.0.0 onwards only.
- **Skill verified intact:** `~/.agents/skills/impeccable/SKILL.md:137` lists `critique [target]` in the command table; `command-metadata.json` describes it as "Evaluate design from a UX perspective, assessing visual hierarchy, information architecture, emotional resonance, cognitive load, and overall quality with quantitative scoring, persona-based testing, automated anti-pattern detection, and actionable feedback."

*Addendum authored 2026-05-13 by Opus 4.7 (1M context) from the agenticapps-dashboard side of the bench. Cross-repo notification only — no host-neutral spec changes.*
