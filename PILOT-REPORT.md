# OpenSpec + Superpowers Workflow — Pilot Report

**Sandbox:** `cparx-openspec-sandbox` on branch `openspec-pilot` (throwaway worktree of HEAD `7c28a66f`).
**Date:** 2026-07-24. **Wall-clock in sandbox:** ~30 minutes.
**Guardrails held:** worked only in the sandbox; `.planning/` read-only (never moved/deleted); no push, no PR, `main` untouched.

---

## TL;DR

The workflow works end-to-end. A real cParX tech-debt task (OBS-04) went cleanly through
**propose → validate → multi-AI review → TDD (RED→GREEN) → archive → ship**, and the
retargeted review gate demonstrably **blocked a code edit before review and permitted it
after**. The single highest-value moment: the multi-AI review caught a **real semantic
defect in the spec before any code was written** (Codex REQUEST-CHANGES), which was then
resolved. The main friction is that the installed OpenSpec is a **newer, CLI-driven schema**
than the prompt assumed, and a PreToolUse hook **cannot live-intercept the running session's
own tool calls** (so the gate was proven by direct invocation, and is wired to fire for any
*future* session in the sandbox).

---

## 1. Did the workflow trigger cleanly?

Yes, with adaptation. Each stage produced its artifact and validated:

| Stage | Command / artifact | Result |
|---|---|---|
| Init | `openspec init --tools claude,codex` | ✓ scaffolded `openspec/{specs,changes,changes/archive}` + config, wired Claude + Codex |
| Seed spec | `openspec/specs/analysis-pipeline/spec.md` (16 requirements, reconstructed from phase 03/03.5/03.6) | ✓ `validate --all` green |
| Propose | `openspec new change add-model-to-classifier-log` → proposal.md, design.md, spec delta, tasks.md | ✓ 4/4 artifacts, `validate --all` green (2/2) |
| Review | `REVIEWS.md` — 2 independent external-vendor CLIs | ✓ Gemini APPROVE, Codex REQUEST-CHANGES→resolved |
| TDD | RED (2 failing tests asserting `model`) → GREEN (`classify.go`) | ✓ `go test ./internal/pipeline/...` green, no regressions |
| Archive | `openspec archive … -y` | ✓ delta folded into main spec; change moved to `changes/archive/2026-07-24-…` |
| Ship | 2 conventional commits + CHANGELOG `[Unreleased]` entry | ✓ committed on `openspec-pilot` (no PR/tag, per sandbox) |

**`archive ≠ ship` confirmed:** `archive` folded the spec and moved the change dir but produced
**no git commit**; `ship` was the separate git step. Two distinct operations, as intended.

## 2. Did the gate block pre-review and permit post-review?

Yes — reproducibly, via direct invocation of `.claude/hooks/openspec-change-gate.sh` with
simulated PreToolUse payloads:

| Situation | Payload | Exit | Meaning |
|---|---|---|---|
| No active change | Edit `classify.go` | `0` | allow (out-of-change, mirrors existing gate) |
| OpenSpec artifact | Write `openspec/…/proposal.md` | `0` | exempt (must be able to author the change) |
| **Active change, validate OK, NO REVIEWS.md** | Edit `classify.go` | **`2`** | **BLOCK** — "missing REVIEWS.md (>= 2 reviewers)" |
| **Active change, validate OK, REVIEWS.md ≥2 reviewers** | Edit `classify.go` | **`0`** | **ALLOW** |
| Escape hatch | Edit `x.go` w/ `GSD_SKIP_REVIEWS=1` | `0` | documented override |
| Malformed stdin | garbage | `0` | fail-open (never silently disables the gate by crashing) |

The gate enforces **both** clauses: `openspec validate --all` must pass **and** every active
change must carry `REVIEWS.md` with ≥2 `## Reviewer:` headings. It mirrors the mechanism of the
existing `multi-ai-review-gate.sh` (ADR-0018), retargeted from “`*-PLAN.md` without `*-REVIEWS.md`”
to “active OpenSpec change without validation+review”.

### The review earned its keep (real value, not theatre)

Two genuine, independent, other-vendor CLIs reviewed the change **before code existed** — no
escape hatch was needed:

- **Gemini (google):** APPROVE — delta minimal/correct, code plan robust, no PII concern.
- **Codex (openai, codex-cli 0.144.6):** **REQUEST-CHANGES** — flagged that describing the
  logged model as *“the model that **produced** the classification”* is wrong on the tolerant
  **fallback** paths (LLM error / bad JSON / unknown enum), where the fallback rule produced
  `general`, not the model. **Valid.** Resolved by retargeting the field's meaning to the
  *attempted* model (a genuinely useful observability signal), tightening the requirement text
  and adding an explicit fallback scenario + fallback test. Re-validated green.

This is the strongest evidence the gate adds value: an adversarial reviewer changed the spec for
the better before implementation.

## 3. CLAUDE.md — what was spec vs process?

CLAUDE.md is **overwhelmingly process/discipline** (coding rituals, workflow hooks, stack,
conventions, Supabase runbook). Almost **no analysis-pipeline product prose lives there** — the
product truth was in `.planning/` (now reconstructed into the capability spec). Concretely:

- **Moved (product → pointer):** the "Mock scoring" constraint line that enumerated the dimension
  weights (Financial 25% / Legal 20% / ESG 20% / Market 20% / Technical 15%). The weight *values*
  are now a requirement in the spec; the line points to
  `openspec/specs/analysis-pipeline/spec.md` and keeps only the prototype-scope framing.
- **Left as process/record (judgment call):** the “Key Architecture Decisions” table rows for
  ADR-0008 (“LLM never produces numerical scores”) and ADR-0009 (risk≠quality). These are a
  *decision ledger* (the canonical decisions are the `docs/decisions/00NN` files); the product
  invariants they reference are now normatively specified in the spec, which the moved line points
  to. Gutting a navigational decision index would not have been surgical.
- Everything else scanned (single-tenant, 5-users-max, budget, no-external-APIs, Supabase/auth
  runbook, workflow hooks) is process/scope and was left untouched.

**Finding:** for this repo, the spec-vs-process split is clean because the two concerns were
already well separated — CLAUDE.md held process; product behaviour lived in phase artifacts.
The migration's real work is reconstructing product truth from `.planning/` into specs, not
carving it out of CLAUDE.md.

## 4. Time taken

~30 minutes wall-clock in the sandbox, including a backgrounded subagent that reconstructed the
16-requirement seed spec (~3 min) and two external-CLI reviews run in parallel.

## 5. Friction (honest)

1. **OpenSpec has moved on from the prompt's model.** The installed CLI is the newer
   **`spec-driven` schema**: changes are scaffolded with `openspec new change` (per-change
   `.openspec.yaml`), artifacts are `proposal.md` + `design.md` + spec delta + `tasks.md`, project
   context lives in `openspec/config.yaml` `context:` (not `project.md`), and `spec …` subcommands
   are deprecated in favour of verb-first `validate`/`show`. **Adaptation:** used the real CLI where
   it exists; wrote **both** `project.md` (prompt compliance) and a `config.yaml context:` block
   (so the tool actually surfaces context); the file layout (`specs/<cap>/spec.md`, delta folded by
   `archive`) still matches the prompt's intent, so the migration concept holds.
2. **A PreToolUse hook can't gate the session that installs it.** The harness loaded hooks at
   session start from the *main* repo's `.claude/settings.json`; a hook written into the sandbox is
   not live for *this* session's own Edit/Write calls. So the gate was demonstrated by **direct
   script invocation** (reproducible, honest) rather than by the harness refusing my edits. The
   wiring is real: a *fresh* Claude or Codex session started in the sandbox would enforce it live.
   This is inherent to hook loading, not a defect in the gate.
3. **Codex CLI invocation friction.** `codex exec "<prompt>"` also reads stdin and **hung** until
   given `</dev/null`; the first attempt timed out at 4 min. Gemini (`gemini -p`) worked first try.
   Worth a wrapper in the real gate so a slow/hanging reviewer CLI can't stall an edit.
4. **Gate design choice — “no active change → allow.”** The gate engages only once a change is
   open (mirrors the existing phase gate's out-of-phase permissiveness) rather than blocking *all*
   code edits without a change. This avoids bricking incidental edits; a stricter “no code edits
   outside a change” posture is possible but was judged too aggressive for a prototype.
5. **`.codex/hooks.json` schema is unverified.** No existing Codex hooks file in-repo to mirror; I
   wrote a plausible one and flagged it. The host-agnostic **shell script** is the real enforcement
   surface and is directly testable; the Claude settings block is verified wiring.
6. **Commit attribution imperfection.** The single `analysis-pipeline/spec.md` file carries both the
   pilot seed (commit A) and the OBS-04 fold; it was committed in A, with the delta recorded under
   `changes/archive/` in B. A real repo would have the seed pre-existing, so a change's ship commit
   would be just code + fold + changelog.
7. **Seed spec deliberately excludes chat/SSE and observability.** The subagent (correctly) left out
   chat/RAG/SSE (not built in phases 03/03.5/03.6) and OBS-01..04 logging (operational, not product).
   Consequence: OBS-04's delta had to **MODIFY** the classification requirement rather than a
   pre-existing “log fields” requirement — which worked out well, since that requirement already
   asserted the logged fields.

## Isolation note

The main tree advanced independently during the pilot (unrelated `docs(19)` Phase-19 planning
commits from concurrent work). The main tree contains **0** `openspec/` files — pilot isolation
held; nothing from the sandbox leaked, and `.planning/` was only ever read.

---

## Acceptance criteria

- [x] `openspec validate --all` green for the seeded capability **and** the new change.
- [x] The gate demonstrably **blocked** an edit before review/validate and **allowed** it after.
- [x] OBS-04 shipped via **propose → validate → TDD → archive**; `specs/analysis-pipeline/spec.md`
      now reflects the `model` field as current truth.
- [x] `.planning/` untouched; only product-spec (the weights line) left CLAUDE.md — process stayed.
- [x] This report exists and is honest about friction.

## Teardown (human runs after review)

```bash
cd ~/Sourcecode/factiv/cparx
git worktree remove ../cparx-openspec-sandbox --force
git branch -D openspec-pilot
```
`.planning/` and the real tree are untouched — only the sandbox is removed.
