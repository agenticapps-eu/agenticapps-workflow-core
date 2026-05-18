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

---

## Addendum — 2026-05-18: Calibration data point #3 → recalibrate skill-driven floor to ≥ 80

### Context

The 2026-05-13 addendum above called the legacy ≥ 90 quality bar "provisional" under the skill-driven gate and asked hosts to gather 2-3 calibration data points before re-anchoring. `agenticapps-dashboard` now has three:

| Phase | Surface | Composite | Nielsen | Notes |
|---|---|---|---|---|
| Phase 10 (2026-05-13) | `/coverage` initial ship | 74 | n/a | Calibration data point #1 — first skill-driven `N-IMPECCABLE.md` artifact. |
| Phase 11 (2026-05-18) | `/coverage` + trends/drift bundle | 76 | 24/40 | Calibration data point #2 — Phase 10's 4 P1s plus the trends/drift surface. |
| **Phase 11.1 (2026-05-18)** | `/coverage` post inherited-P1 closure | **~81** | 26/40 | Calibration data point #3 — column-width lock + sticky toolbar + Toast wiring + `--color-text-tertiary` swap closes all four Phase-10/11 inherited P1s. Zero `low-contrast` findings in the deterministic detector (was 3 in Phase 11). |

All three scored composites land in the **70s-low-80s** band. None reached the legacy ≥ 90 (or the Phase 6-era ≥ 87 floor the dashboard host had been carrying provisionally as `D-6-09.v1` / `D-10.5-03`).

### The empirical claim

The skill-driven `impeccable critique` output produces a **systematically tighter scoring distribution** than the v1 CLI's `--json` scalar score did. The two-assessment protocol (LLM design review at Nielsen-heuristic granularity + deterministic detector) acts as two independent low-pass filters on the score:

- The **LLM assessment** caps each heuristic at 4, with calibrated definitions per `reference/heuristics-scoring.md`. Real interfaces, even good ones, rarely score 4 on more than 2-3 of the 10 heuristics. Realistic totals fall in the 24-32/40 band (60-80%).
- The **deterministic detector** never lifts the score; it only penalizes. A clean detector pass is the *absence* of subtractions, not a contribution to the composite.

Composite math (rough): `composite ≈ Nielsen_total * 2.5 + bonus_detector_clean - per-finding_penalty`. With Nielsen capped at 40 and detector contribution ≤ +5, the practical ceiling for non-extraordinary designs is **~95**, and the realistic band for "good production work that has merit but real gaps" is **75-85**. The legacy ≥ 90 / ≥ 87 was calibrated against the v1 CLI's distribution and effectively required perfection-on-paper.

### Decision (ratified)

For hosts that have adopted the skill-driven gate (with a per-phase `<N>-IMPECCABLE.md` artifact instead of CI-enforcement):

**The recommended quality bar floor is ≥ 80**, with a **structural-debt waiver clause** for the **75-79 band**.

The waiver clause permits accepting composites in 75-79 as "passing-with-debt" when ALL of the following hold:

1. The current phase's own deliverables are detector-clean (CLI source scan = 0 findings) AND the phase's declared must-haves all verify.
2. The composite deficit vs. ≥ 80 is composed entirely of inherited issues from prior phases OR items the current phase explicitly scoped out per its `<N>-CONTEXT.md`.
3. The next phase in the queue commits — in its `<N>-CONTEXT.md` — to closing at least one tier of the carried debt (e.g., one P1 from this phase's `<N>-IMPECCABLE.md` Priority Issues section becomes a must-have in the next phase).

A composite at < 75, OR a composite at 75-79 without meeting all three waiver conditions, blocks phase close.

### Why ≥ 80 specifically (not 75, not 85)

The three calibration data points (74, 76, 81) span the 74-81 band. Picking 80 as the floor:

- **Blocks Phase 10 (74)** and **Phase 11 (76)** — both correctly identified as needing follow-up cycles. Phase 11 specifically justified Phase 11.1 (the polish bundle that produced data point #3).
- **Passes Phase 11.1 (~81)** — correctly identifies that closing four inherited P1s plus the token contrast invariant is "merit work that should land."
- **Preserves a delta** of ~10 points between the floor and the realistic ceiling (~95), which keeps room for the gate to recognize phases that exceed expectations rather than collapsing into a binary pass/fail.

Picking 75 (just below the lowest data point) would make the gate effectively un-blocking — even an obvious-debt phase like Phase 10 would pass. Picking 85 would block Phase 11.1 despite it being a clean P1-closure cycle, which inverts the gate's intended signal (closures should pass, regressions should fail).

### Application to existing artifacts

This addendum is retroactive in interpretation, prospective in enforcement:

- Phase 10's `10-IMPECCABLE.md` at composite 74: **interpreted as below floor** — the follow-up cycle (Phase 11) was the correct response.
- Phase 11's `11-IMPECCABLE.md` at composite 76: **interpreted as below floor, accepted-with-debt** because Phase 11's own deliverables landed clean and Phase 11.1 was committed as the carry-over closure cycle. Retroactively satisfies the waiver clause's condition (3).
- Phase 11.1's `11.1-IMPECCABLE.md` at composite ~81: **passes the new ≥ 80 floor** with safe margin.

Future phases (Phase 11.2 if opened, Phase 12 onward) gate against ≥ 80 by default; the waiver remains available for genuine carry-over scenarios.

### What this does NOT change

- The two-gate-point model (`design_critique` pre-phase + `impeccable_audit` finishing).
- The skill names (`impeccable:critique`, `impeccable:audit`).
- The original ≥ 90 default in the host-neutral Decision section above — that remains the default for hosts that have not opted into the skill-driven gate (i.e., hosts still using the v1 CLI distribution). The recalibration applies only to hosts adopting the skill-only / per-phase-artifact path.
- Other hosts' (codex-workflow, pi-agentic-apps-workflow) right to set their own floor independently. The ≥ 80 recommendation is what fell out of `agenticapps-dashboard`'s three data points; other hosts should gather their own.

### Trace

- **Recommended in:** `agenticapps-dashboard` `.planning/phases/DASH-11.1-impeccable-p1-polish-bundle/11.1-IMPECCABLE.md` §"D-10.5-03 calibration follow-up" (2026-05-18). The dashboard host originally carried this question as `D-6-09.v1` / `D-10.5-03` (provisional ≥ 87 floor pending 3-phase calibration).
- **Ratified by:** This addendum, written immediately after PR #36 merged Phase 11.1 to the dashboard's main branch as `8fe463a`. The merge commit captures the third calibration data point.
- **Cross-references:**
  - `agenticapps-dashboard/.planning/phases/DASH-10-coverage-matrix-page-per-repo-presence-freshness-of-claude-m/10-IMPECCABLE.md` (data point #1)
  - `agenticapps-dashboard/.planning/phases/DASH-11-coverage-trends-skill-drift/11-IMPECCABLE.md` (data point #2)
  - `agenticapps-dashboard/.planning/phases/DASH-11.1-impeccable-p1-polish-bundle/11.1-IMPECCABLE.md` (data point #3, with the ratification draft text)
  - `agenticapps-dashboard/.planning/phases/DASH-10.5-impeccable-skill-driven-gate/10.5-DECISIONS.md` (the original `D-10.5-03` provisional floor decision)

*Addendum authored 2026-05-18 by Opus 4.7 (1M context) from the agenticapps-dashboard side of the bench, immediately after PR #36 merge. Cross-repo notification per the 2026-05-13 addendum's "Quality bar threshold should be revisited per-host" recommendation now that three calibration data points are in hand.*
