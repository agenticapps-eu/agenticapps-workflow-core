# AgenticApps workflow simplification — target design & migration plan

You asked for a simple-but-effective workflow and to question everything. This is
the design, a decision on each of your points (with pushback where I have it), the
detailed walkthrough of how the new workflow runs, and a phased migration plan.
Nothing here has been applied to any repo — it's a plan for your sign-off. Three
real forks are flagged **[CONFIRM]** and asked at the end.

---

## 1. TL;DR — the simplified stack

**Keep three things, cut the rest:**

| Layer | Tool | Role |
|---|---|---|
| **What is true / what changes** | **OpenSpec** (`specs/` + `changes/`) | durable spec + per-change deltas — the front-end that replaces GSD's `.planning/` |
| **How work gets done** | **Superpowers** (brainstorm · writing-plans · TDD · verification-before-completion) | execution discipline — unchanged |
| **What's next / priority** | **Linear** | roadmap, epics, sequencing — replaces GSD's ROADMAP/STATE/milestone machinery |

**Cut or collapse:** the GSD *engine* as the front-end (its `.planning/` phase/roadmap/velocity system) · gitnexus · the flaky Linear↔GSD sync · redundant review gates (9 → a small always-on core + conditional gates) · spec content living in CLAUDE.md/AGENTS.md.

**One enforcement hook stays** (retargeted): "no code edit until the OpenSpec change is validated" replaces "no code edit until the plan is reviewed."

Everything binds **upstream** (linked, not re-ported) in all four hosts — consistent with your existing doctrine.

---

## 2. The new workflow — detailed walkthrough

A real change to cParx, end to end, on any host (claude/codex/opencode/pi):

**0. Roadmap (Linear, once per cycle).** You keep epics/issues in Linear:
"Sprint 1 · Foundation → ERM core schema". Linear is where priority and sequencing
live. No sync job.

**1. Start a change.** `/opsx:propose add-erm-core-schema`. The agent writes
`changes/add-erm-core-schema/`:
- `proposal.md` — Why / What Changes / Impact, with a `Linear: AGE-403` line (a
  plain reference, not a sync).
- `specs/<capability>/spec.md` **delta** — `## ADDED Requirements` etc. against the
  current `specs/`. This is the plan. Writing the delta *is* the design step.
- `tasks.md` — the implementation checklist.

**2. Tighten + gate.** `/opsx:refine` then `/opsx:validate` (→ `openspec validate
--strict`: every requirement has a scenario). This **replaces the GSD plan-review
and spec-review gates** — the validated delta is the reviewed plan. The `PreToolUse`
hook refuses code edits until a validated change exists.

**3. Execute (Superpowers, unchanged).** brainstorm (only if the change is genuinely
open-ended) → writing-plans → TDD RED/GREEN → verification-before-completion. The
conditional gates fire by project type here: security (cso) always for product
repos; database-sentinel if the change touches SQL/RLS; design/impeccable/qa only if
it touches UI.

**4. Archive.** `/opsx:archive add-erm-core-schema` folds the delta into `specs/`
(now current truth) and moves the change to `changes/archive/`. Close the Linear
issue by hand (or let it auto-close from the commit — your choice).

**Result:** to know what the system does, read `specs/`. To see history, read
`changes/archive/`. To see what's next, look at Linear. Three places, each with one
job — versus today's `.planning/` with 10+ artifact types per phase, a stale
REQUIREMENTS.md, and a sync that breaks.

**What a session reads at start:** `specs/` (current truth, compact) + the active
change + AGENTS.md discipline rules. Not a pile of phase folders.

---

## 3. Decision log — your points, my calls, my pushback

**① Remove gitnexus — AGREE, clean cut.** It's a 30 MB `lbug` binary committed in
`.gitnexus/` plus 6 skills wired into `.claude/skills/gitnexus/`. Code-graph
tooling is nice in theory but you don't reach for it, and a 30 MB blob in every host
repo is real weight. Remove: delete `.gitnexus/`, the `skills/gitnexus/*`, the
`.claude/skills/gitnexus/*` symlinks, and any AGENTS.md/CLAUDE.md references.
Authored as one OpenSpec change (`remove-gitnexus`) so it's traceable.

**② OpenSpec + Linear as roadmap — AGREE.** This is the core move (validated by the
dry run: `specs/` reconstructs cleanly and passes `openspec validate`). On the
Linear coupling I push back on *any* automated bidirectional sync — that's the thing
that's cumbersome and flaky. **[CONFIRM-1]** Recommended: **loose convention** —
Linear holds roadmap/priority; each OpenSpec change names its Linear ID in
`proposal.md`; no sync daemon. Humans move cards. This deletes the sync problem
rather than fixing it.

**③ Core spec first, then downstream — AGREE with a caveat.** Core-first is right for
authoring the standard. But I'd **pilot one capability on cParx first** to de-risk
the *format and the discipline* before stamping it into core and four hosts.
**[CONFIRM-3]** — pilot-first vs core-first vs both.

**④ "Linked upstream in all agents" — AGREE, confirming interpretation.** I read this
as: bind OpenSpec **upstream (linked, not copied)** and let each host generate its
own slash commands / AGENTS.md, exactly like your GSD bind-upstream doctrine (ADR-0007)
— *not* re-porting OpenSpec per host. OpenSpec supports this natively (one npm
package, per-host command generation, 25+ tools). One bind, four hosts. Tell me if
you meant something else by "opencode" specifically.

**⑤ Keep `.planning/` as backup + migrate to specs — AGREE, already designed.** This
is the Tier-0/1/2 model from the dry run: keep `.planning/` (or move to
`docs/legacy-planning/`), mechanically archive each phase as a completed change
(Tier 1), reconstruct `specs/` (Tier 2, supervised). Nothing lost.

**⑥ Open GSD plans → OpenSpec changes — AGREE, concrete method.** Scan each repo's
`.planning/STATE.md`, `ROADMAP.md` (unchecked phases), and `docs/briefs/*` for
not-yet-done work; each open item becomes an **active** `changes/<name>/` (proposal +
spec delta + tasks), not an archived one. For cParx that's the v0.4.0.0 ERM phases
17–23 (all "Pending" in REQUIREMENTS traceability) + open briefs. For codex-workflow
it's the open `docs/briefs/` (e.g. plan-review-gate follow-ups).

**⑦ Migrate spec out of CLAUDE.md/AGENTS.md — AGREE, with the key nuance.** Not
everything in those files is spec. Two kinds of content:
- **Process/discipline** (the 4 "Coding Discipline" rules, workflow instructions,
  session-handoff) → *stays* in AGENTS.md, or better, lives in the workflow **skill**.
  This is how the agent behaves, not what the product is.
- **Product capability** (architecture invariants, data-model rules, "LLM Extracts /
  Rules Score", the D-18 response shape, RLS constraints) → **moves to `specs/`**.
  In cParx's CLAUDE.md this is the real target; in the scaffolder repos there's almost
  none (they have no application code).

So the rule is: *if a sentence describes what the product does or must guarantee, it's
spec; if it describes how you should work, it's process.* Only the former moves.

**⑧ Check the hooks — DONE, there's one.** The only hook is a `PreToolUse` /
`apply_patch` hook running `hook-wrapper-plan-review.sh` (the plan-review gate).
Verdict: **keep the mechanism, retarget it** — from "block edits until GSD plan
reviewed" to "block edits until an OpenSpec change exists and `openspec validate`
passes." Same teeth, new gate. No other hooks exist to prune.

**⑨ The go / quality skills — my honest take.** You have: `impeccable` (24 UI
anti-patterns), `database-sentinel` (27 DB anti-patterns), and the Go skills
(samber/netresearch). Whether they beat the model's baseline is **empirical, and I
won't assert it blind.** My recommendation **[CONFIRM-2]**: **keep
database-sentinel and the security gate** (a missed RLS/SQL-injection is expensive
and asymmetric — cParx already carried storage-RLS tech debt), and **trial
impeccable + the Go skills with a measurement**: run each gate over your last ~10
merged PRs, count findings that were *real and actionable* vs. noise; keep the ones
with signal, drop the rest. Simple, evidence-based, and it directly answers your "do
they actually help" doubt instead of guessing.

**⑩ Question everything / gates simplification.** The biggest simplification beyond
the three cuts: your **9 gate skills collapse** onto the OpenSpec lifecycle:

| Gate today | Fate |
|---|---|
| `spec-review` (structural) | **folds into `/opsx:validate`** (the delta is the spec, validated by the tool) |
| `plan-review` (multi-AI adversarial) | **KEPT, retargeted** — reviews the change (proposal + delta); gate requires validate green AND `REVIEWS.md` ≥2. OpenSpec does not do review. |
| `cso` (security) | keep — always-on for product repos |
| `database-sentinel` | keep — conditional (SQL/RLS touched) |
| `qa` (viewport tests) | keep — conditional (UI touched) |
| `design-shotgun`, `design-critique`, `impeccable` | keep — conditional (UI), and impeccable pending the ⑨ trial |
| `ts-declare-first` | demote to a lint/CI check, not a gate |

Always-on shrinks to **validate + security + tests**. Everything else fires by what
the change actually touches. That's the "simple but effective" core.

---

## 4. Migration plan (phased, dogfooded as OpenSpec changes)

Each step is itself an OpenSpec change so the migration is traceable and reversible.

**Phase A — Core spec repo (`agenticapps-workflow-core`).**
1. `openspec init` in core. Author the **standard** as spec: the OpenSpec-slot
   contract, the Linear-loose-coupling convention, the retargeted hook contract, the
   gate→lifecycle mapping, the CLAUDE.md spec-vs-process rule. This replaces the
   GSD-binding standard (new ADR superseding 0007/0009-plan-review/0003).
2. Write the `planning→openspec` migration recipe (Tier-1 script + Tier-2 supervised
   procedure) in your `migrations/` idempotent format + `run-tests.sh` fixture, so all
   hosts get the identical transform.

**Phase B — One host + one cParx capability (pilot).** Bind OpenSpec upstream in the
pilot host (opencode), run the migration on **one** cParx capability
(`analysis-pipeline` — already reconstructed here), retarget the hook, and run a real
change through the full loop. Measure. This is the go/no-go.

**Phase C — Roll to the four hosts.** claude / codex / opencode / pi each: bind
OpenSpec upstream, remove gitnexus, retarget the hook, collapse gates, run the
`update` migration. Host files (AGENTS.md/CLAUDE.md) keep only process; spec content
moves to `specs/`.

**Phase D — Downstream product repos.** cParx and the other factiv + agenticapps
projects that use the workflow: run the migration (full `.planning/` → `specs/` +
archived changes), extract product-spec out of CLAUDE.md into `specs/`, convert open
GSD phases → active changes, keep `.planning/` as backup.

---

## 5. What I need to execute

This session can only see `codex-workflow` and cParx's `.planning/`. To do the
migration I'll need you to connect (Add folder): **`agenticapps-workflow-core`**, the
**claude / opencode / pi** host repos, and the **cParx repo root** (for CLAUDE.md +
code). Also note: git write-ops on a device-mounted folder from this cloud session
can leave `.lock` files — the clean path for the actual repo edits is to run them
with Cowork **on your computer**, or I stage/prepare everything here and you apply.

Confirm the three forks below and grant access, and I'll start with Phase A (author
the core standard as OpenSpec) and the pilot.
