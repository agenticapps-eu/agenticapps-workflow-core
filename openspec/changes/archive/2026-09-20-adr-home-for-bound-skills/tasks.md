# Tasks

## 1. The rule, where every host reads it

- [x] 1.1 Add `## Decisions and domain language` to
      `skills/agentic-apps-workflow/SKILL.md`: the instruction file's named home
      wins; bound skills' defaults redirected; one home among `docs/decisions/`,
      `docs/adr/`, `adrs/`; numbering by the home's scheme; locked = hard to
      reverse + real trade-off (surprise is guidance); Small/Tiny exempt;
      rejected alternative required; `CONTEXT.md` distinct from the retired
      per-phase file; no configurator; `.scratch/` via `.git/info/exclude`.
- [x] 1.2 Bump the skill `version` 4.0.0 → 4.1.0 (additive).
- [x] 1.3 `spec/00-overview.md` ADR definition points at the decision home.

## 2. The fact, where every turn reads it — tests first

- [x] 2.1 RED: `tools/init-project.test.sh` section M1–M6.
- [x] 2.2 Implement in `init-project.sh`; `SECTION_VERSION` 1.0.0 → 1.1.0,
      `init-project-version` 2.1.0 → 2.2.0.
- [x] 2.3 GREEN, twice: 127/127.
- [x] 2.4 Round-1 review fixes, RED first: M7 README is not a record, M8 `adrs/`
      is a home, M9 irregular names still count. 2 RED (M9 already green), then
      130/130 GREEN twice.
- [x] 2.5 Core's own section re-rendered by the new initializer: names `adrs/`.

Neighbours unchanged: `agents-md-conformance.test.sh` 79/79, `install.test.sh`
57/57, `openspec validate --all` green.

## 3. Record

- [x] 3.1 `CHANGELOG.md` `[Unreleased]` entry.
- [x] 3.2 `design.md` for this change; ADR-0031 for its locked decision.

## 4. Evidence — before archive

- [x] 4.1 Plan-review round 1 (codex, opencode: REQUEST-CHANGES ×2; gemini
      exit 1, claude excluded as implementing host). Findings and dispositions
      in `design.md`.
- [x] 4.2 Plan-review round 2 (codex REQUEST-CHANGES; gemini, opencode exit 1).
      Four findings fixed in the skill, one rejected — see `design.md`.
- [x] 4.3 Scratch repo `docs/decisions/0001-one.md`, initializer run (section
      1.1.0), a locked decision recorded on **two hosts**: claude wrote
      `0002-postgres-for-idempotency-keys.md`, codex wrote
      `0003-single-worker-outbox-polling.md`. No `docs/adr/`, no `docs/agents/`,
      both instruction files byte-identical. Claude's own account names the
      mechanism: *"the skill defaults to `docs/adr/`, but this repo's CLAUDE.md
      says decision records live in `docs/decisions/` and nowhere else, so that
      wins"* — the instruction file decided it, not the workflow skill, which is
      the bare-session case this task exists for.
- [x] 4.4 Scratch repo seeded with `ADR-2026-05-13-performance-history-naming.md`;
      codex wrote `ADR-2026-09-20-exponential-backoff-with-jitter.md` — the
      home's own scheme, not `NNNN-`.
- [x] 4.5 cparx probe: asked where records live, how many, which directory a
      deepening survey reads first, and whether `docs/adr/` would ever be
      created. Answers: `docs/decisions/` citing the instruction file, 44
      numbered records plus two unnumbered, `docs/decisions/` read first
      *"every ADR carries an Alternatives Rejected section"*, and `docs/adr/`
      would not be created.
- [x] 4.6 Shipped in PR #117 and published on both machines: laptop and Mac
      mini both report `init-project` 2.2.0 and skill 4.1.0 across claude,
      codex, opencode and pi.

## 5. Fleet — one branch and commit per repository

- [x] 5.1 Re-rendered with the 2.2.0 initializer on branch
      `workflow-section-1-1` from `origin/main` in callbot, cparx, fbc-platform,
      fx-signal-agent: every hunk inside the markers, twins byte-identical, all
      name `docs/decisions/`. Staged.
- [x] 5.2 Merged: callbot #115, cparx #244, fbc-platform #416,
      fx-signal-agent #238. Each carries section 1.1.0 naming `docs/decisions/`,
      twin files byte-identical. cparx's setup output was reverted in #243.
