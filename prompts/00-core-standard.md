# Claude Code prompt — author the OpenSpec+Superpowers standard in the core repo

**Run with Claude Code inside `agenticapps-workflow-core`.** Run this AFTER the cParx
pilot (prompt 03) succeeds, so the standard encodes a proven recipe. It makes the core
repo the canonical source of the new workflow; the host repos will bind to it.

---

## Paste to Claude Code:

You are authoring the AgenticApps workflow standard, v2: **OpenSpec (spec slot) +
Superpowers (execution) + Linear (roadmap)**, replacing the GSD-engine front end. The
core repo is spec-only prose that each host implements. Guardrails: this repo has no
application code; you are writing standards, an ADR, and a migration recipe. Keep
existing ADRs; supersede, don't delete.

### 1. Write the standard as spec
`openspec init`, then author `openspec/specs/` (or keep the core's existing spec/ prose
convention, whichever the repo already uses) capturing these contracts as requirements
with scenarios:
- **Spec-slot contract** — `specs/` is durable current truth; `changes/` are deltas;
  `archive/` is history; done = spec folded + validate green.
- **Lifecycle contract** — propose → validate → Superpowers-execute → archive; validate
  replaces plan-review + spec-review.
- **Gate mapping** — the gate→lifecycle collapse table (spec-review/plan-review →
  validate; security always; db-sentinel/qa/design conditional; ts-declare → lint).
- **Retargeted-hook contract** — `PreToolUse` blocks edits until an active change
  validates. Specify inputs/exit codes so every host implements the same behavior.
- **Linear coupling** — loose convention: change references a Linear ID; no sync.
- **CLAUDE.md/AGENTS.md content rule** — product-capability → specs; process → host
  file; effort history → docs/legacy-planning. Give the "is this a product guarantee or
  a way of working?" test.
- **Bind-upstream rule** — OpenSpec is linked upstream, generated per host, not re-ported.

### 2. Write the planning→openspec migration recipe
Author `migrations/NNNN-planning-to-openspec.md` in this repo's existing idempotent
apply-block format, with a `run-tests.sh` fixture (git-ref fixture like your other
migrations). It must encode the two tiers explicitly:
- **Tier 1 (mechanical, scripted):** each `.planning/phases/<slug>/` → a completed
  `changes/archive/<date>-<slug>/` (proposal from CONTEXT/SUMMARY, tasks from PLAN
  checklists all `[x]`, evidence carried). Provide the script.
- **Tier 2 (supervised):** reconstruct `specs/<capability>/` by MERGING related phases
  into capabilities (not one-phase-one-spec); flag ambiguities as `> [GAP: …]`; require
  a human to ratify before archive. This step is procedure, not an unattended script.
- **Tier 0:** keep `.planning/` (move to `docs/legacy-planning/`), never delete.

### 3. ADR
Write `docs/decisions/NNNN-openspec-superpowers-standard.md`: Accepted; supersedes
ADR-0007 (bind-upstream-gsd, now bind-upstream-openspec), ADR-0009 plan-review-gate
(retargeted), ADR-0003 (gsd-entry-points → opsx commands). Record: gitnexus removed;
Linear loose-coupled; gate collapse; go-skills on measured trial (link MEASUREMENT.md).
Mark `docs/standards/gsd-binding-and-planning.md` SUPERSEDED with a pointer.

### 4. Copy `docs/WORKFLOW.md` (the explainer) into the repo and reference it from AGENTS.md.

### Acceptance criteria
- Standard expressed as validatable spec (`openspec validate --all` green).
- Migration recipe present with a passing `run-tests.sh` fixture.
- ADR written and supersessions recorded; GSD-binding standard marked superseded.
- No gitnexus references remain.
