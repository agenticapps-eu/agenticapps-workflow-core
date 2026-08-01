# The AgenticApps Workflow (v1 — OpenSpec + Superpowers)

*An explainer. This is orientation, not a contract. The normative text is
in `spec/`; decisions are in `adrs/`; this file tells you how the pieces
fit and why.*

## One sentence

Product work moves through an **OpenSpec change** — propose it, validate
and review it *before* writing code, execute it with **Superpowers**
discipline (TDD, evidence, independent review), then fold it into the
durable spec and ship — while a `PreToolUse` gate refuses to let you edit
code until the change has validated, and tells you where its review stands
without stopping you.

## The two layers

The workflow has always had two layers, and v1 keeps one and replaces the
other.

- **Execution discipline — Superpowers (kept).** The commitment ritual,
  the rationalization table, the 13 red flags, the pressure test, the
  coding discipline, TDD, on-disk evidence, and independent code review.
  This is the machinery that stops an agent under deadline pressure from
  rationalizing its way out of tests and reviews. Unchanged from 0.x
  (spec §01, §03, §04, §05, §06, §11).
- **Planning discipline — OpenSpec (new, replacing the GSD engine).**
  Instead of `.planning/` phases that record *how the product was built*,
  an **OpenSpec spec slot** records *what the product guarantees now*, and
  changes are proposed and validated against it.

## The spec slot (§16)

`openspec/` holds three things with three lifespans:

```
openspec/
  specs/                 # durable current truth — one spec.md per capability
    analysis-pipeline/
      spec.md            #   what the pipeline guarantees TODAY
  changes/               # in-flight deltas — proposed, not yet true
    add-model-to-log/
      proposal.md  design.md  <delta>  tasks.md
  changes/archive/       # history — shipped changes, dated
    2026-07-24-add-model-to-log/
```

To learn what the system does, read `specs/`. To see what's being
changed, read `changes/`. To see how a requirement came to be, read
`changes/archive/`. A change is **done** when its delta is folded into
`specs/` **and** `openspec validate --all` is green.

OpenSpec is an upstream tool, generated per host by its CLI — not
re-implemented or copied between repos (the *bind-upstream* rule). Where
the installed CLI's file names differ from any prose here, the CLI wins.

## The lifecycle (§17)

```
   propose ─────▶ validate ─────▶ Superpowers-execute ─────▶ archive
   (open a       (validate green   (TDD, evidence,            (fold delta
    change;       AND ≥2-reviewer   independent code review,   into specs/,
    proposal +    multi-AI review   security/design/db/qa/     openspec
    design +      BEFORE code)      lint gates as triggered)   archive)
    delta +                                                        │
    tasks)                                                         ▼
                                                              ship (git)
```

Two things about this picture matter most:

1. **Review happens before code.** The old `plan-review` and
   `spec-review` gates collapse into the **validate** stage: `openspec
   validate` checks the delta against the spec slot, and independent
   reviewers adversarially review the *proposed change* before a line of
   implementation exists. In the cParX pilot this is exactly where the
   value showed up — a reviewer caught a real defect in the spec itself.
2. **`archive ≠ ship`.** Folding the delta into `specs/` (`openspec
   archive`) is a spec-slot operation and produces no commit. Shipping is
   the separate git step, gated by `branch-close` / the PR.

### What happened to the old gates (§17 mapping)

| Old §02 gate | Now |
|---|---|
| `plan-review`, `spec-review` | **collapse into `validate`** (review before code — `validate` blocks, the review is reported) |
| `code-review` | **retained** — validate doesn't read code |
| `tdd`, `verification` | **retained** — Superpowers execution |
| `security` | **retained, always** on triggering changes |
| design / database / qa | **conditional** — fire on their triggers |
| `ts-declare` (§13) | **→ lint gate** |

## The gate that enforces it (§18)

A `PreToolUse` hook inspects every code-editing tool call and blocks it
until the active change has validated and carries a `REVIEWS.md` with ≥2
independent reviewers. Its decision is an exit code:

- no active change → **allow** (0)
- writing the OpenSpec change itself → **allow, exempt** (0)
- active change, validate green, no/​insufficient review → **block** (2)
- active change, validate fails → **block** (2)
- active change, validate green + ≥2 reviewers → **allow** (0)
- documented escape hatch env var → allow; garbage stdin → allow (fail-open)

It reuses the mechanism the 0.x multi-AI plan-review gate proved, pointed
at OpenSpec changes instead of `*-PLAN.md`. A hook can't gate the session
that installs it (the harness loads hooks at session start), so it's
proven by direct invocation and enforces live for the next session.

## Where prose lives (§19)

Once a spec slot exists, ask of any line: **is this a product guarantee,
or a way of working?**

- **Product guarantee** (a scoring weight, an API field, an access rule) →
  the **spec slot**, as a requirement.
- **Way of working** (use TDD, run the security gate, boot the dev server
  before a screenshot) → the **instruction file** (`CLAUDE.md` /
  `AGENTS.md`), as process.
- **Record of past effort** (the phases that built it) →
  **`docs/legacy-planning/`**, as history — moved, never deleted.

Capabilities are **merged, not mirrored**: three planning phases about one
surface become one capability spec, not three phase-shaped specs.

The roadmap stays in **Linear**, coupled loosely — a change references a
Linear ID for traceability, but nothing syncs and nothing requires it.

## Adopting it

The core repo is spec-only; it defines the standard but does not run it.
A host or app repo adopts v1 by applying
`docs/recipes/0001-planning-to-openspec.md`, which reconstructs `specs/`
from an existing `.planning/` tree (mechanical Tier 1 + supervised Tier 2),
keeps the old planning history under `docs/legacy-planning/` (Tier 0), and
wires the change-gate. No host cites v1.0.0 yet; cParX is the first
adoption target, its pilot recorded in `PILOT-REPORT.md` and
`MEASUREMENT.md`.

## Further reading

- `spec/16`–`spec/19` — the normative contracts.
- `adrs/0021-openspec-superpowers-standard.md` — why, and what it
  supersedes.
- `PILOT-REPORT.md` / `MEASUREMENT.md` — the proven recipe and its data.
- `docs/recipes/0001-planning-to-openspec.md` — how a repo migrates.
