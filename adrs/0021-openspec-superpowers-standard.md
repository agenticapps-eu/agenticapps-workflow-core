# ADR-0021: Replace the GSD-engine front end with OpenSpec + Superpowers (spec v1.0.0)

**Status**: Accepted  **Date**: 2026-07-24
**Supersedes**: remaps §02 (hook taxonomy) and §07 (two-stage review) for
1.0.0 hosts; supersedes the 0.x "bind-upstream-gsd" convention with
"bind-upstream-openspec". Host-level: on adoption, claude-workflow's
ADR-0003 (gsd-entry-points), ADR-0007 (bind-upstream-gsd), ADR-0009
(plan-review-gate), and `docs/standards/gsd-binding-and-planning.md` are
superseded in that host.
**Spec trajectory:** v1.0.0 — the first major. OpenSpec front end added
as §16–§19; §02/§07 remapped; §00/§09 framing updated.

## Context

Through the 0.x line the workflow had two layers:

- an **execution discipline** — Superpowers (the commitment ritual §01,
  rationalization table §03, red flags §04, pressure test §05, coding
  discipline §11, plus TDD, evidence, independent review), and
- a **planning discipline** — the GSD engine: `.planning/` phases moving
  CONTEXT → PLAN → execute → VERIFY → REVIEW, with a fixed gate taxonomy
  (§02) and a two-stage review (§07).

The execution discipline has earned its keep across the fleet. The
planning discipline has two structural weaknesses that surfaced as the
factiv app repos (cparx, fx-signal-agent, fbc-platform) scaled:

1. **No single current-truth artifact.** A project's product guarantees
   were scattered across phase artifacts and the always-loaded
   instruction file. There was a history of *how* it was built but no
   validatable statement of *what it currently does*. Answering "what
   does the pipeline guarantee today?" meant reading a dozen phase dirs.
2. **Review fired late.** `spec-review` and `plan-review` were separate
   gates; the spec-compliance check ran *after* code in the 0.x
   ordering, and plan-review's value (adversarial review before code)
   depended on a bespoke multi-AI gate.

[OpenSpec](https://github.com/Fission-AI/OpenSpec) supplies exactly the
missing piece: a `specs/` slot that *is* the current truth, `changes/`
deltas that are proposed and validated before code, and an `archive/`
history. It keeps Superpowers as the execution layer and replaces the
GSD engine as the front end.

**This standard encodes a proven recipe, not a hypothesis.** The
2026-07-24 cParX pilot (`PILOT-REPORT.md`) ran a real tech-debt task
(OBS-04) end-to-end through propose → validate → multi-AI review → TDD
(RED→GREEN) → archive → ship in a throwaway sandbox. The retargeted gate
demonstrably blocked a code edit before review and permitted it after,
and — the single highest-value moment — an adversarial reviewer caught a
**real semantic defect in the spec delta before any code was written**.
Measurements are recorded in `MEASUREMENT.md`.

## Decision

**Adopt OpenSpec + Superpowers as the AgenticApps workflow front end at
spec v1.0.0**, expressed as four new declarative-contract sections and a
remapping of the two review-related sections:

- **§16 — OpenSpec spec slot.** The three-slot model (`specs/` durable
  truth, `changes/` deltas, `archive/` history), the two-part done-ness
  rule (delta folded **and** `validate --all` green), and the
  **bind-upstream** rule: OpenSpec is a per-host upstream tool, generated
  by the CLI, never re-ported or hand-maintained. The installed CLI is
  authoritative over this prose where they disagree on file names or
  subcommands.
- **§17 — Lifecycle & gate mapping.** propose → validate →
  Superpowers-execute → archive; `archive ≠ ship`; and the table mapping
  every §02 gate to a fate: `plan-review`/`spec-review` **collapse into
  validate**; `code-review`/`tdd`/`verification`/`security` are
  **retained**; `security` is **always**; design / database / qa gates
  stay **conditional**; §13 declare-first maps to a **lint** gate.
- **§18 — Retargeted change-gate.** The 0.x `PreToolUse` plan-review hook
  (host ADR-0018's `multi-ai-review-gate.sh` mechanism) is retargeted
  from "`*-PLAN.md` without `*-REVIEWS.md`" to "active OpenSpec change
  without validation + review." The exit-code truth table (0 = allow,
  2 = block; OpenSpec-artifact writes exempt; documented escape hatch;
  fail-open on malformed stdin; `validate` green **and** ≥2 reviewers
  required) is normative.
- **§19 — Spec-vs-process placement & Linear coupling.** The "is this a
  product guarantee or a way of working?" test — guarantees to the spec
  slot, process to the instruction file, effort history to
  `docs/legacy-planning/`; capabilities **merged, not mirrored** from
  phases; and Linear coupled **loosely by convention, never synced**.

§02 and §07 are **remapped, not deleted** — they stay normative for 0.x
hosts and are read through §17's gate mapping for 1.0.0 hosts.

### Specific records

- **gitnexus removed.** The GSD-era workflow bound gitnexus for
  code-finding in host configs. It is not part of the OpenSpec front end
  and has **no normative binding in the core spec** (a grep of `spec/`
  and the active ADRs finds only one incidental, historical mention in
  ADR-0019, which is immutable record). A host adopting 1.0.0 drops its
  gitnexus workflow binding; nothing in §16–§19 references it.
- **Linear loose-coupled.** A change SHOULD reference a Linear ID for
  traceability; there is deliberately **no** bidirectional sync and none
  is permitted to be required (§19).
- **Gate collapse.** The two review gates become one `validate` stage;
  the enforcement surface is the §18 change-gate plus `openspec
  validate`, not a standalone `plan-review`/`spec-review` gate.
- **Skills on measured trial.** The OpenSpec + Superpowers skill set is
  adopted **provisionally on a measured trial**, not as a permanent
  irreversible commitment. `MEASUREMENT.md` holds the trial's evidence
  (seeded from the cParX pilot: ~30 min wall-clock end-to-end, one real
  spec defect caught pre-code, gate block/allow reproduced). Adoption is
  justified by that measurement and revisited as more data lands; a host
  adds a data point when it runs the workflow on real work.

## Alternatives Rejected

- **Keep GSD, bolt a spec index on top.** Rejected: a second,
  hand-maintained "current truth" doc alongside `.planning/` recreates
  the drift §08 exists to forbid — a second source of truth that silently
  diverges. OpenSpec's `specs/` *is* the truth, kept green by `validate`.
- **Re-port OpenSpec into a host-local format.** Rejected: the fleet's
  bind-upstream posture (consume upstream Superpowers/GSD rather than
  re-author host copies) exists precisely because re-ported copies fork.
  §16 binds OpenSpec upstream for the same reason.
- **Ship as a minor (0.11.0).** Rejected: this is breaking. The §02/§07
  review gates are remapped and the front-end lifecycle changes; a host
  cannot claim the new behavior while implementing the old gates. Per the
  §09 versioning policy that is a **major** — hence 1.0.0. The whole 0.x
  fleet stays conformant at its cited version until it adopts.
- **Delete §02/§07.** Rejected: "supersede, don't delete." Four hosts
  cite 0.x versions and reproduce those contracts today; deleting them
  would strand valid claims. They are remapped with a banner.
- **Author before the pilot.** Rejected by sequencing: the standard was
  written only after the cParX pilot proved the recipe end-to-end, so the
  exit-code contract, the `archive ≠ ship` boundary, and the CLI-schema
  reality are recorded as observed, not assumed.

## Consequences

- **The core spec now carries two front ends.** §09 states the coexistence
  rule: 0.x hosts stay valid; 1.0.0 hosts implement §16–§19. No host is
  forced to migrate on any schedule.
- **No host cites 1.0.0 yet.** The pilot ran in a torn-down sandbox; the
  fleet remains at 0.10.0 (`reference-implementations/README.md`). The
  first real adoption is the cParX app repo, whose runnable
  `run-tests.sh` migration fixture and live `openspec/` are host
  deliverables — the planning→openspec **recipe** in
  `docs/recipes/0001-planning-to-openspec.md` is the reference they
  apply.
- **The migration recipe is a reference, not a shipped migration.** This
  repo is spec-only prose (README: "not a library… no application code"),
  so it does not ship a runnable `migrations/` chain; it defines the §08
  format and provides the recipe. The executable fixture lands in the
  adopting host.
- **Host-level supersessions on adoption.** When claude-workflow adopts
  1.0.0, its ADR-0003 / ADR-0007 / ADR-0009 and
  `docs/standards/gsd-binding-and-planning.md` are marked superseded with
  a pointer here. Core has no standalone GSD-binding standards file; the
  binding lived in §02/§07 and the `reference-implementations` bind rule,
  which this ADR remaps.
