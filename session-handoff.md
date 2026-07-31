# Session Handoff — 2026-07-31 (late evening)

## Accomplished

**Core PR #49 open** — `fix/conformance-harness-false-green`. Fixes open item
#1 from the previous handoff: two of five conformance harnesses exited 0 having
scored nothing. Ships spec 1.4.0 / §20 and ADR-0026.

- All five harnesses in `tools/` now score absence instead of skipping it, and
  report `UNSCOREABLE <label> — <reason>` over four conditions with fixed
  precedence (not-found, not-a-regular-file, empty, unreadable).
- `--family` declares `scored N of M` on every run, names what it skipped and
  why, uses stable logical labels throughout, and reports pin-and-resolve hosts
  as *resolvable, not attempted* rather than absent.
- New opt-in `--family --resolve` scores **6 of 6** — and shows that
  claude-workflow and codex-workflow resolve to gate 2.0.0 and score 71/71
  each. The old harness filtered them out and printed success, so it could
  never show this.
- `tools/conformance-harness-reporting.test.sh` — 45 rows, all green.
- Core gate scores 71/71 before and after; no conformance verdict moved.

**Also verified, unchanged from before:** claude-workflow #110 is all-green and
mergeable; dashboard #84 had CI in flight. Neither was touched this session.

## Decisions

- **Named absence fails, roster absence reports** — a named target is a caller
  assertion; a roster entry is the harness's own guess. Failing on the latter
  would have gone red the moment claude-workflow correctly stopped vendoring.
- **Two harness shapes, one rule** — multi-target counts and continues,
  single-target aborts. An earlier draft made the mechanism uniform and thereby
  declared two already-correct tools non-conformant; a reviewer caught it
  before code existed.
- **`--resolve` is opt-in, never default** — resolution reaches a remote commit
  and fails closed; a conformance tool that cannot run offline is a weaker tool.
- **No expected-absence allowlist**, and the rejection is written into §20
  rather than left to judgement, because it is the attractive wrong answer. It
  would already have been stale twice in one week.
- **New section type `core-tooling-contract`** — §20 binds this repo's tooling
  and no host. Filing it as `declarative-contract` would have made §00's "the
  requirements live in the canonical-prose and declarative-contract sections"
  false. §00 and §09 amended.
- **Stale line citations in design.md left as-is** — they describe the code as
  it stood when the defect was found, which is what that section is for.

## Files modified

- `tools/{change-gate,run-plan-review,reviewer-cli,resolve-core-artifact,shared-install}-conformance.sh`
  — absence screening, reasons, backstop; roster coverage on the two that have it
- `tools/conformance-harness-reporting.test.sh` — new
- `spec/20-conformance-harness-reporting.md` — new; `spec/00-overview.md`,
  `spec/09-conformance.md` — amended; `spec_version` 1.3.0 → 1.4.0
- `adrs/0026-a-harness-that-scored-nothing-is-not-green.md` — new
- `CHANGELOG.md`, `openspec/changes/fix-conformance-harness-false-green/`

## Next session: start here

**PR #49 is open and unmerged; the change is NOT archived.** Two things are
deliberately outstanding, in order: (1) an independent Stage-2 code review per
§07 — `openspec validate` is a spec check and does not discharge it, and I
could not self-dispatch a subagent in this session; (2) `/opsx:archive` once
that review is addressed. Start by running the code review against the diff on
`fix/conformance-harness-false-green`, then archive, then merge. After that the
opencode and pi ports remain the largest untouched work — the recipe in the
previous handoff still stands, and its method note (survey the host's
installer, tests, AND every `.github/workflows/` file first) is the lesson that
cost three round trips in codex.

## Open questions

- **Host CIs will go red where they were green because a target was missing.**
  Intended. `codex-workflow` must materialise its gitignored `bin/` before
  invoking the harness. The `test -s` / `--check` workarounds in host CIs are
  now redundant and should be removed — separate change per host.
- **§07 code review says MUST throughout, and nothing enforces any of it.**
  Recorded at the user's request. There is no code-review producer (only
  `run-plan-review.sh`, which is for plan review), and the §18 gate has zero
  references to `REVIEW.md` — it reads `REVIEWS.md` only. So today, zero
  external agents available blocks nothing. That is an *unimplemented* property,
  not a decided one. If a code-review gate is ever built it must be report-only
  from day one, per gate 2.0.0's reasoning: block on facts (tests, lint,
  validate), report on opinions. The hazard to design against is silence being
  read as approval — the producer's `requested / counted / excluded / failed`
  accounting is the shape that already solves it. Note §07 requires *context*
  independence, not *vendor* independence, so code review degrades to
  one-agent-available far more gracefully than plan review can.
- Remaining open items from the previous handoff are untouched: core does not
  gate itself (no `.claude/hooks/`, no CI gate workflow); `shim-project-hooks`
  is on main as an unimplemented proposal; migration 0032 installs the producer
  without version arbitration; `track-and-conform-plan-review` still wants
  archiving.
