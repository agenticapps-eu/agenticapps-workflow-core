# Switching cPARX from GSD to OpenSpec — how the workflow actually changes

Grounded in the real cParx `.planning/` (30+ phases, 4 milestones) and your
multi-host, bind-upstream setup. Superpowers and the gstack gates stay; only the
plan/spec slot GSD holds is replaced. This is my reasoned take, trade-offs included.

## 1. The loop today (GSD + Superpowers)

The unit of work is a **phase** — a slice of effort in time.

```
/gsd-new-milestone   → grill scope → REQUIREMENTS.md (flat per-milestone list)
                                   + ROADMAP.md (phases) + STATE.md (position)
/gsd-plan-phase N    → decompose into plan-parts NN-01..NN-k, gather CONTEXT/RESEARCH
[execute each part]  → Superpowers: brainstorm → writing-plans → TDD → verification
[per-phase artifacts]→ CONTEXT·RESEARCH·PLAN·SUMMARY·REVIEW·VALIDATION·VERIFICATION
                       ·SECURITY·UAT·PATTERNS·DISCUSSION-LOG   (10+ files per phase)
[gates]              → /review · /cso · /gsd-verify-work · ADRs
/gsd-audit-milestone → point-in-time REQ→phase traceability table
[done]               → milestone archived to .planning/milestones/
```

Where the current truth lives: **nowhere, as one artifact.** `REQUIREMENTS.md` is
a per-milestone wishlist that goes stale (the live one is about the v0.4.0.0 ERM,
not the extraction pipeline you shipped in v1.0). To answer *"what does the
extraction pipeline do today?"* you must read phases 03 + 03.5 + 03.6 and reconcile
them — which is exactly the supervised work this dry run had to do by hand. That is
the tell: **the truth was never maintained as truth.**

## 2. The loop with OpenSpec (+ Superpowers, unchanged)

The unit of work is a **change** — a delta to a living spec.

```
/opsx:propose <change> → proposal.md (why/what/impact) + a SPEC DELTA
                         (ADDED / MODIFIED / REMOVED requirements vs specs/)
/opsx:refine · validate→ tighten; `openspec validate --strict` gates it
                         (every requirement MUST carry a scenario)
[execute]              → Superpowers: brainstorm → writing-plans → TDD → verification
                         — IDENTICAL to today
/opsx:archive <change> → the delta is FOLDED INTO specs/ (specs/ is now current
                         truth) and the change moves to changes/archive/
```

Where the current truth lives: **`specs/<capability>/spec.md`** — one file per
capability, always current, machine-validated. *"What does the extraction pipeline
do?"* → read `specs/analysis-pipeline/spec.md`. Done.

## 3. What changes day-to-day

| Recurring operation | GSD today | OpenSpec |
|---|---|---|
| Start a piece of work | `/gsd-plan-phase` — decompose a *phase* | `/opsx:propose` — write the *spec delta* first |
| "What is true right now?" | read N phases + milestone audit, reconcile | read `specs/<cap>/spec.md` (current, one file) |
| Requirement tracking | flat `REQUIREMENTS.md` per milestone + traceability table | living `specs/` + per-change deltas |
| Inserting unplanned work | new fractional phase (`03.5`, `03.6`, `04.7 INSERTED`, `09.1`) | just another change; no renumbering |
| Definition of done | phase `VERIFICATION.md` exists | tasks done **and** delta folded into `specs/` **and** `openspec validate` green |
| Context you feed the agent | `.planning/phases/NN/*` (effort history, 10+ files, ~100s KB) | `specs/` (compact current truth) + the one change |
| Cross-milestone memory | archived milestones — reconstruct to reuse | `specs/` carries forward automatically; `archive/` holds deltas |
| Canonical artifact | ~10 files per phase, none authoritative | proposal + spec-delta + tasks (+ optional design) |

Superpowers' discipline artifacts (brainstorm, plans, TDD, verification) still get
produced — but they become *supporting* evidence for a change, not the canonical
record. The canonical record is the spec.

## 4. Why it's a better FIT for *your* situation

Three reasons that are specific to you, not generic:

1. **Multi-host is native, so your biggest maintenance tax drops.** Your GSD spine
   forced per-host forks — `gsd-opencode`, `get-shit-done-multi` for codex — and a
   `.planning/config.<host>.json` collision you had to namespace. OpenSpec generates
   per-host slash commands + `AGENTS.md` from one upstream bind (25+ tools
   supported). One bind, four hosts. That is your bind-upstream doctrine applied to
   the plan slot with *less* work than GSD costs you now.

2. **It matches how you already think.** You built `agenticapps-workflow-core` as a
   spec repo with `implements_spec:` frontmatter and declarative-contract vs
   canonical-prose typing. OpenSpec's `specs/` + `changes/` (deltas) is *isomorphic*
   to that. Today your meta-architecture is spec-first but your runtime workflow is
   effort-first — an impedance mismatch. OpenSpec makes the two rhyme.

3. **The spec becomes the host-neutral portable artifact.** A claude session and a
   codex session on the same repo both read the same `specs/` — one source of truth
   across hosts. Today a `.planning/` grown by claude and one grown by codex can
   drift (hence the config collision). `specs/` is host-agnostic truth by
   construction.

## 5. Why it gives better RESULTS — my view

1. **The agent gets a precise, current input — the whole ballgame.** The article's
   thesis is "the context we give the AI isn't precise enough." To change scoring
   today, the agent must read three phases and reconcile the "clean deal scores 100"
   regression to learn the *current* rule — or it reads a stale `REQUIREMENTS.md`.
   With `specs/analysis-pipeline/spec.md` it reads one validated statement of truth.
   Better input → better output, mechanically.

2. **Drift is caught by the tool, not by an audit months later.** `openspec
   validate --strict` fails a requirement with no scenario; `archive` forces the
   spec to be updated or the change can't close. GSD has no "the spec must stay
   current" gate — which is why your own v1.0 milestone audit records *"code and
   documentation inconsistent,"* missing `VERIFICATION.md`, and accepted gaps.
   OpenSpec turns the spec into a build artifact that rots loudly instead of
   silently.

3. **"Change" fits reality; "phase" fights it.** Look at your own phase numbers:
   `03.5`, `03.6`, `04.7 INSERTED`, `09.1`, `90/91/92`. Those fractional/INSERTED
   phases are the model straining — real work arrives as deltas, and the phase
   scheme has to be bent to absorb them. OpenSpec's change-as-delta absorbs the same
   work with no renumbering and no "INSERTED 2026-04-20" scars.

4. **Regressions get a chance to be caught at propose-time.** The 03→03.5 bug
   shipped because nothing forced the *specification* of "what a score means" to
   exist before the code. A propose step whose delta says *"Requirement: score
   reflects investment quality"* invites the question "does the subtractive scorer
   actually do that?" before 100 ships. Spec-first is bug-prevention, not
   bookkeeping.

5. **Reviews get a smaller, sharper target.** Your gstack gates (`/review`, `/cso`)
   review a delta of a few requirements instead of a 60 KB `PLAN.md`. Tighter diffs,
   better reviews.

## 6. Honest counter — where OpenSpec is worse or costs you

- **It does not orchestrate effort.** GSD's roadmap/milestone/velocity machinery
  (STATE.md position, 7-phase sequencing, "what's next across the milestone") has no
  OpenSpec equivalent. OpenSpec assumes you already know which change to make next.
  For multi-week efforts you'll want to keep a lightweight roadmap alongside — likely
  a thin GSD-roadmap or Linear layer *feeding* OpenSpec changes.
- **It is thinner on open-ended research.** Your `RESEARCH.md` / `PATTERNS.md` /
  `DISCUSSION-LOG.md` depth is a genuine GSD strength for hard, unknown problems.
  OpenSpec's proposal/design is lighter; it shines on *known* changes, less on
  exploration. The v0.2/v0.3 design-exploration milestones would have fit GSD better
  than OpenSpec.
- **"Specs must be maintained" is a new tax.** If the team skips folding the delta
  into `specs/` at archive-time, you get the worst of both — stale specs *and* lost
  phase history. The discipline has to hold.
- **Maturity.** GSD+Superpowers is a stack you've hardened over many milestones;
  OpenSpec is younger. Migration itself is real work (see the dry run's Tier-2
  caveats).

## 7. My recommendation in one line

Adopt OpenSpec for the **spec/plan slot**, keep **Superpowers + gstack** for
execution and gates, and keep a **thin roadmap layer** (GSD-roadmap or Linear) for
effort-sequencing — then pilot it on the opencode host with the next real cParx
change and measure whether reading `specs/` beats reconciling phases. The dry run
already shows the reconstructed truth is cleaner and machine-validatable; the open
question is only whether your team keeps it current, and a one-host pilot answers
that cheaply.
