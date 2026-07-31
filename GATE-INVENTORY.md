# Full gate & hook inventory — GSD/gstack → OpenSpec+Superpowers

Every gate, hook, and ritual from your current stack (grounded in
`docs/ENFORCEMENT-PLAN.md` + `spec/02-hook-taxonomy` + the gsd-binding standard),
with a keep/retire verdict. Rule of thumb: **OpenSpec touches only the spec artifact
and its lifecycle. It does not provide review, security, tests, or release. All of
those stay.**

## First, the framing you proposed — yes, with one sharpening

GSD was **both** layers at once: the *spec/durable-truth* layer (REQUIREMENTS,
plans-as-intent) **and** the *operational* layer (discuss → plan → execute → verify →
ship). Superpowers is purely operational. So the two overlapped on the operational
half — GSD's discuss/plan/verify duplicated Superpowers' brainstorm/writing-plans/
verification — and GSD's spec half was tangled into effort-state that went stale.

New split, three orthogonal jobs:
- **OpenSpec** = spec/durable truth (`specs/`) + change lifecycle (`changes/`).
- **Superpowers** = operational discipline (brainstorm, TDD, review, verification).
- **Linear** = roadmap/priority.

Now nothing overlaps: OpenSpec owns *what's true*, Superpowers owns *how you build*,
Linear owns *what's next*. That's the "complementary, not conflicting" you described.

## A. Superpowers execution gates — ALL KEEP (OpenSpec doesn't touch these)

| Gate | Skill | New-workflow home |
|---|---|---|
| brainstorm (arch/ui) | superpowers:brainstorming | execution step; only for open-ended changes |
| tdd | superpowers:test-driven-development | execution; RED→GREEN, unchanged |
| **code-review (Stage 2 independent reviewer)** | superpowers:requesting-code-review | **KEEP — this is your adversarial review of the *implementation*** (fresh `codex exec` child, ADR-0002). Now reviews the diff against the spec delta. This is the "check the implementation" review from your earlier question. |
| verification | superpowers:verification-before-completion | pre-archive; does the diff satisfy the tasks + spec delta |
| branch-close | superpowers:finishing-a-development-branch | part of ship |

## B. gstack / AgenticApps gates — KEEP (mostly conditional), OpenSpec touches only spec-review

| Gate | Skill | Verdict |
|---|---|---|
| **security (cso)** | codex-cso | **KEEP — always-on for product repos.** OpenSpec has zero security capability. cParx has real surface (JWT/RLS/IDOR — it's literally in the analysis-pipeline spec's auth requirement). Fires when a change touches executable/auth/data-exposure code. **Answer to your question: yes, absolutely keep cso.** |
| **plan-review (multi-AI adversarial)** | codex-plan-review | **KEEP — adversarial review of the *plan*** (≥2 other-vendor CLIs → REVIEWS.md). Retargeted to the change (proposal + delta). Not covered by OpenSpec (validate is a lint). Closes ADR-0018. |
| spec-review (Stage 1) | codex-spec-review | **RETIRE as a separate gate** — its structural half is `/opsx:validate`; its "does the spec make sense" half is now the plan-review adversarial pass over the delta. Fully absorbed. |
| database-sentinel | codex-database-sentinel-audit | KEEP — conditional (change touches SQL/schema/RLS). |
| qa / ui-preview | codex-qa | KEEP — conditional (change touches UI / dev server). |
| design-shotgun | codex-design-shotgun | KEEP — conditional (UI). |
| design-critique | codex-design-critique | KEEP — conditional (UI). |
| impeccable-audit | codex-impeccable-audit | KEEP — conditional (UI), **on measured trial** (MEASUREMENT.md). |
| ts-declare-first | codex-ts-declare-first | KEEP but **demote to a CI lint / tdd-strengthener**, not a standalone gate. |

## C. The enforcement hook — KEEP, retargeted (do not weaken)

| Hook | Verdict |
|---|---|
| `PreToolUse` / `apply_patch` plan-review hook (+ `check-plan-review.sh` verifier) | **KEEP.** Retarget predicate: block code edits until the active change has `openspec validate` GREEN **and** `REVIEWS.md` ≥2 reviewers. Same escape hatches (`GSD_SKIP_REVIEWS=1`, per-change skip marker). This is the teeth that makes propose-before-code non-bypassable. |

## D. Rituals & cross-cutting mechanisms — KEEP (all orthogonal to OpenSpec)

| Mechanism | Verdict |
|---|---|
| Commitment ritual · Red Flags · Rationalization Table · Pressure-Test | KEEP — trigger skill canonical prose (process). |
| §11 Coding Discipline (the 4 rules) | KEEP — process, stays in host file / workflow skill. |
| **§15 knowledge-capture (Obsidian)** | **KEEP — easy to lose.** Retarget its ritual triggers: "phase completion" → "change archive"; keep "session handoff". Routed via `.planning/config.json → knowledge_capture` (or move to `openspec/` config). |
| §10 observability generator | KEEP — delegated `agenticapps-observability` skill; unrelated to OpenSpec. |
| §14 prompt-injection defense (injection-guard) | KEEP — delegated; unrelated. Fires on prompt-building product repos. |
| secret scanner (gitleaks, ADR-0006) | KEEP — CI/pre-commit; unrelated. |
| session-handoff (host-scoped) | KEEP — but it now references the active change(s), not a GSD phase (STATE.md is gone). |
| task-size routing (tiny/small vs medium/large) | KEEP — small changes skip heavy gates; medium/large REQUIRE plan-review + code-review + an ADR. Maps 1:1. |
| migration framework + drift-report | KEEP — versions the standard; now also carries the planning→openspec migration. |

## E. What actually retires (net) — and nothing is lost

- GSD **front-end engine** (discuss/plan/verify as the *driver*) → `/opsx:propose` +
  `/opsx:validate` + Superpowers. The *capabilities* move; the driver goes.
- `gsd-plan-phase` → `/opsx:propose`. `gsd-ship` → `/opsx:archive` **+ kept ship
  mechanics** (commit/PR/changelog/version). `gsd-verify-work` →
  superpowers:verification. `gsd-audit-milestone` → `openspec validate` + `openspec
  list` + Linear coverage.
- `spec-review` as a standalone gate → validate + plan-review.
- `STATE.md` / `ROADMAP.md` / velocity → Linear + the `changes/` directory.
- The elaborate **`.planning/phases/` commit-evidence rules** (standard §5) → gone;
  `changes/` + `archive/` are ordinary committed files, no special ignore-guards.

## The two reviews you must not conflate (both survive)

1. **plan-review** (gstack, multi-AI) — reviews the *plan/spec delta*, pre-execution.
2. **code-review** (Superpowers Stage 2, independent reviewer) — reviews the
   *implementation diff*, pre-archive.

Your two-stage review was: Stage 1 spec-review + Stage 2 code-review. In the new world
that becomes: **validate + plan-review (the plan) → build → code-review (the diff) →
verification → archive → ship.** You end up with *more* review coverage, not less,
because the reviewers now critique structured specs instead of prose plans.
