# OpenSpec + Superpowers — Measured Trial

ADR-0021 adopts the OpenSpec + Superpowers front end **on a measured
trial**: the decision is justified by evidence, and the evidence is
tracked here rather than asserted once and forgotten. Each real run of
the workflow adds a data point. A sustained negative signal (review adds
no value, the gate blocks nothing real, the lifecycle costs more than it
saves) is grounds to revisit the standard.

## What we are measuring

1. **Does review earn its keep?** — does the pre-code multi-AI review
   catch real defects *before* implementation, or is it theatre?
2. **Does the gate work?** — does the retargeted change-gate block a code
   edit before review and permit it after, reproducibly?
3. **Cost** — wall-clock and friction to run a unit of work end-to-end.
4. **Placement** — is the spec-vs-process split (§19) clean in practice?

## Data points

### DP-1 — cParX pilot (2026-07-24)

Source: `PILOT-REPORT.md`. Throwaway sandbox worktree of cparx `7c28a66f`,
branch `openspec-pilot`; torn down after review. One real tech-debt task
(OBS-04: log the classifier's attempted model).

| Metric | Result |
|---|---|
| Lifecycle completed | propose → validate → multi-AI review → TDD (RED→GREEN) → archive → ship ✓ |
| Review earned its keep | **Yes.** Codex (openai) REQUEST-CHANGES caught a real semantic defect in the spec delta *before code*: "the model that **produced** the classification" is wrong on tolerant fallback paths (LLM error / bad JSON / unknown enum) where the fallback produced `general`. Retargeted to the *attempted* model; requirement tightened; fallback scenario + test added. Gemini (google) APPROVE. |
| Gate block-before / allow-after | **Yes, reproducibly** (direct invocation, simulated payloads). No REVIEWS.md → exit 2 (block); validate green + ≥2 reviewers → exit 0 (allow); OpenSpec-artifact write → 0 (exempt); `GSD_SKIP_REVIEWS=1` → 0; garbage stdin → 0 (fail-open). |
| Wall-clock | ~30 min end-to-end in sandbox, incl. a backgrounded subagent reconstructing a 16-requirement seed spec (~3 min) and two external-CLI reviews run in parallel. |
| Placement (§19) | Split was already clean — `CLAUDE.md` was overwhelmingly process; one product guarantee (scoring weights) moved to the spec with a pointer left behind. The real work was reconstructing product truth from `.planning/` into `specs/`, not carving CLAUDE.md. |
| `archive ≠ ship` | Confirmed — `openspec archive` folded the delta and moved the change dir with **no** git commit; ship was the separate git step. |

**Friction recorded** (fed into §16/§18): the installed OpenSpec CLI is a
newer `spec-driven` schema than the original prompt assumed (§16 makes the
CLI authoritative); a `PreToolUse` hook cannot gate its own installing
session (§18 requires demonstrability by direct invocation + live
enforcement for a fresh session); `codex exec` hangs on stdin without
`</dev/null` (§18 SHOULD wrap reviewer CLIs with a timeout).

### DP-2 — first production adoption (pending)

The first non-sandbox adoption — the cParX app repo applying
`docs/recipes/0001-planning-to-openspec.md` for real — will add the next
data point: migration cost on a full `.planning/` tree, whether the
merge-not-mirror capability reconstruction holds at scale, and whether the
gate blocks anything real in day-to-day work.

## Verdict so far

One end-to-end data point, positive on all four questions. Enough to
adopt on trial (ADR-0021, Accepted); not yet enough to call the trial
concluded. Keep adding data points.
