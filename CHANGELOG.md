# Changelog

All notable changes to the AgenticApps workflow specification are documented
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Versioning policy

Spec versions follow semver:

- **Patch** (0.1.x) — typo fixes, clarification rewordings, no conformance impact.
- **Minor** (0.x.0) — additive: new declarative requirement, new optional gate.
  Hosts already at the prior version remain conformant.
- **Major** (X.0.0) — breaking: canonical block reworded, gate removed,
  evidence rules tightened. Hosts MUST update their implementations.

Each entry below names the conformance impact for host implementers.

## [Unreleased]

## [0.4.0] — 2026-05-20

Additive minor release. Three new spec sections and one host-agnostic
ADR placeholder. Hosts at v0.3.2 remain conformant for v0.3.2 claims;
hosts wishing to claim v0.4.0 satisfy the new sections per the
host-implementer actions block below.

### Added

- **`spec/11-coding-discipline.md`** — canonical-prose section with
  four short rules (Think Before Coding, Simplicity First, Surgical
  Changes, Goal-Driven Execution), each followed by 5–6 anti-pattern
  bullets the rule prevents. Provenance: distilled from public
  discussion of recurring failure modes in coding-agent output
  (Karpathy, 2025-2026), as gathered in the community skill
  collection `multica-ai/andrej-karpathy-skills`. Hosts updating to
  v0.4.0 MUST reproduce the canonical block verbatim in their
  primary project-instruction file (CLAUDE.md, AGENTS.md, or
  equivalent).
- **`spec/12-authoring-conventions.md`** — declarative contract for
  authoring host SKILL.md, AGENTS.md, and contract spec files. Three
  SHOULD/MAY-level requirements: SHOULD render branchy workflows as
  Mermaid `flowchart` diagrams with explicit cycle/fallback paths
  and a REPORT terminal; SHOULD keep judgment-heavy passages in
  prose; MAY combine both within a single section. Plus an advisory
  on placement of behavior-critical prose given known
  long-context-attention drop-off. Cites Xiao et al., *FlowBench*
  (EMNLP 2024 Findings, arXiv:2406.14884) and Liu et al., *Lost in
  the Middle* (arXiv:2307.03172, TACL 2024).
- **`spec/13-ts-declare-first.md`** — declarative contract for a
  host-provided `ts-declare-first` skill (host-named equivalents
  permitted). SHOULD-level for hosts that target TypeScript
  projects. Defines a three-phase discipline: Phase 1 produces a
  `declare`-only type-surface file with zero implementation bodies;
  Phase 2 produces tests that import and exercise the declared
  surface and fail in the expected way; Phase 3 produces the
  implementation whose exported signatures match the declarations
  exactly. Piggy-backs on §06 for evidence shapes; integrates with
  the §02 `verification` gate; MUST NOT collapse Phase 1 and Phase 3
  into a single commit.
- **`adrs/0015-secret-scanner.md`** — placeholder ADR. Status:
  Proposed; Decision: **TBD pending evaluation in claude-workflow's
  `feat/v1.14.0-workflow-additions` branch**. Reserves the ADR
  number and gives the downstream evaluation a stable target file to
  populate with the benchmark outcome. Context captures the
  candidates (`gitleaks` vs `betterleaks`) and the four evaluation
  criteria the populated Decision must address (true-positive
  recall, false-positive rate, migration cost, CI runtime).

### Changed

- **`spec/00-overview.md`** — section-list updated to include §11 as
  canonical prose and §12, §13 as declarative contracts. Explanatory
  paragraph extended to cover the v0.4.0 additions. Frontmatter
  `spec_version` bumped to 0.4.0.
- **`spec/09-conformance.md`** — §11 added to the canonical-prose
  list (item 1 under `full`); §12 and §13 added to the declarative-
  MUST list (item 2 under `full`), with §13 noted as
  TypeScript-target-only. `implements_spec` citation-format example
  bumped from `0.3.0` to `0.4.0`. Header prose updated from "at
  version 0.3.0" to "at version 0.4.0". Frontmatter `spec_version`
  bumped to 0.4.0.
- **`reference-implementations/README.md`** — current-spec version
  noted as 0.4.0. Host conformance rows unchanged; hosts move to
  v0.4.0 via their own adoption PRs.

### Host implementer actions

- **All hosts.** Reproduce the §11 canonical block verbatim in
  CLAUDE.md / AGENTS.md / equivalent at the host's next minor
  release. Bump `implements_spec` to `0.4.0` after the block is in
  place and any other applicable sections (§12, §13) are satisfied.
- **All hosts.** Audit existing SKILL.md / AGENTS.md / contract spec
  files against §12 at next significant rewrite. Convert branchy
  workflows to Mermaid `flowchart` diagrams with explicit
  cycle/fallback paths. Bulk conversion is not required; the
  obligation is SHOULD-level and applies to newly authored sections
  at or after v0.4.0 adoption.
- **TS-targeting hosts (`claude-workflow`, `codex-workflow`).** Ship
  a `ts-declare-first` skill (or host-named equivalent) satisfying
  §13's Phase 1 / Phase 2 / Phase 3 contract and integrating with
  the §02 `verification` gate. Non-TS-targeting hosts MAY omit the
  skill and SHOULD record the omission as a spec delta per §09.
- **`pi-agentic-apps-workflow`, `agenticapps-dashboard`.** Adoption
  pending at v0.1.0; absorb v0.2.0 → v0.4.0 additions at adoption
  time. Dashboard is consumer-only and not affected by §11, §12, or
  §13 directly.
- **`claude-workflow`** specifically additionally drives the
  benchmark that populates ADR-0015's Decision block. Until that
  benchmark lands, ADR-0015 ships as Proposed; hosts SHOULD continue
  using `gitleaks` as the de facto default and SHOULD NOT switch
  defaults based on the Proposed status alone.

## [0.3.2] — 2026-05-18

Patch release: §10.5 Flush-primitive obligation codified. Most existing
hosts already satisfy it implicitly via host-runtime await
(`ts-cloudflare-worker`, `ts-cloudflare-pages`, `ts-supabase-edge`,
`ts-react-vite`); the change moves the obligation from "implicit
best-practice" to "explicit MUST" so generators in languages without
runtime-await for short-lived processes (Go today; future Rust/Python/
Node-on-bare-V8) cannot ship without addressing it.

### Documentation

- **§10.5 Flush primitive** — added MUST-level bullet between the
  existing "Non-blocking emission" and "Fail-safe behavior" bullets.
  Wrappers MUST expose a `Flush(timeout)` (or idiomatic equivalent)
  that drains in-flight emission goroutines/microtasks INTO the
  destination SDK's transport BEFORE draining the SDK's own buffer.
  Short-lived processes MUST call it before exit; long-running services
  need not. Implementations MUST report success when the destination
  SDK was never configured (no DSN), since the emission-layer drain is
  the only contract `Flush` has in that mode. Witness: factiv/cparx
  2026-05-18 Sentry adoption verification — wrapper-routed events were
  silently dropped from CLI smoke tests because `sentry.Flush` raced
  against fire-and-forget emission goroutines.

### Conformance impact for host implementers

- **`claude-workflow`** (current `implements_spec: 0.3.0`) — `ts-*`
  templates satisfy the new obligation implicitly via host-runtime
  await. `go-fly-http` template needs an explicit `Flush(timeout)`
  addition; PR #36 ships the fix at `add-observability` v0.3.3.
  After PR #36 merges, claude-workflow can bump `implements_spec`
  0.3.0 → 0.3.2.
- **`codex-workflow`** — no observability templates today; not affected.
- **`pi-agentic-apps-workflow`** — adoption pending; absorbs the
  obligation at adoption time.
- **`agenticapps-dashboard`** — consumer-only; not affected.

## [0.3.1] — 2026-05-15

Patch release: ADR-0011 addendum documenting the upstream
`pbakaus/impeccable` CLI rename. No conformance impact — addendum
clarifies the existing decision.

### Documentation

- **ADR-0011 addendum** documenting the upstream `pbakaus/impeccable`
  CLI rename (`critique` subcommand removed in v1.0.1; v1.x
  unpublished from npm; v2.x emits a finding-list shape under
  `npx impeccable detect`). Skill hook syntax
  (`impeccable:critique`, `impeccable:audit`) is unchanged and
  continues to satisfy the gate-point contract. Hosts with
  CLI-based CI gates have two response options (migrate to `detect`
  or adopt per-phase artifacts); both satisfy the ADR.

### Conformance impact for host implementers

- None. Addendum clarifies the existing ADR-0011 decision; hosts
  at v0.1.0 / v0.2.0 / v0.2.1 / v0.3.0 remain conformant. Hosts
  with standalone CLI-based CI gates that called
  `npx impeccable critique` directly need to migrate, but the
  skill-based hook syntax (the canonical reference path) is
  unchanged.

## [0.3.0] — 2026-05-15

Conformance enforcement layer for §10 observability. Additive minor —
hosts already at v0.2.1 remain conformant for v0.2.1 claims.

### Added

- **`spec/10-observability.md` §10.9 Conformance enforcement** — new
  sub-section. Defines three primitives generators MUST support
  (delta scan via `--since-commit`, baseline file at
  `.observability/baseline.json`, CI-integration guidance) plus an
  optional pre-commit hook (§10.9.4). Baseline JSON schema includes a
  per-checklist breakdown of high-confidence gaps so dashboards can
  surface richer state; baseline updates happen on successful
  `scan-apply` or via explicit `scan --update-baseline`, never
  silently on read-only scans.
- **`spec/10-observability.md` §10.7 fifth bullet** — generators MUST
  support delta scan and maintain the §10.9 baseline. The baseline
  file is the source of truth for "what conformance level is this
  project currently at?"
- **`spec/10-observability.md` §10.8 `enforcement:` sub-block** —
  OPTIONAL field in the project metadata block declaring baseline /
  CI workflow / pre-commit paths. Projects that omit it default to
  the canonical baseline path and no CI gate; projects that declare
  it MUST satisfy the per-field §10.9 contract.
- **`adrs/0014-observability-architecture.md` v0.3.0 follow-up
  subsection** — documents what shipped in v0.3.0 (closes deferred
  gap G7 from the cparx 2026-05-10 pilot rollout plan), what's
  deferred to v0.4.0 (handler-entry vs background-work split per
  cparx gap G3; medium-confidence gate threshold pending data from
  first host CI deployment).

### Changed

- **`spec/00-overview.md`** — section-list updated to include §10 as
  a declarative contract; explanatory paragraph added about §10's
  v0.2.0 → v0.2.1 → v0.3.0 trajectory and how hosts choose which
  version to claim. Frontmatter `spec_version` bumped to 0.3.0.
- **`spec/09-conformance.md`** — §10 added to the declarative-MUSTs
  list (item 2 under `full` conformance). `implements_spec`
  citation-format example bumped from `0.1.0` to `0.3.0`. Header
  prose updated from "at version 0.1.0" to "at version 0.3.0".
  Frontmatter `spec_version` bumped to 0.3.0.

### Conformance impact for host implementers

- Hosts at v0.2.1 remain conformant for v0.2.1 claims (additive
  minor).
- Hosts wishing to claim v0.3.0 MUST update their generator skill
  to satisfy §10.9.1–§10.9.3 (delta scan, baseline maintenance,
  CI-integration reference workflow). §10.9.4 (pre-commit hook) is
  MAY.
- Projects claiming v0.3.0 conformance SHOULD prevent regression
  per §10.9; the MUST inside §10.9.3 is that opt-out (deleting or
  emptying the baseline) MUST NOT be silent — the CI workflow logs
  it visibly so reviewers see enforcement is disabled.

## [0.2.1] — 2026-05-13

Patch release: §10 amendments from the cparx 2026-05-10 pilot.

### Changed

- **`spec/10-observability.md` §10.5** — added a note on host
  recoverer interaction. When a project already uses a
  framework-level panic/error recoverer (Chi's `chimw.Recoverer`,
  Express's error handler, Fastify's `setErrorHandler`), the
  observability wrapper's middleware SHOULD be mounted inside the
  recoverer so error capture sees the original exception, not the
  recovered response. Recommendation, not a MUST. Source: cparx
  pilot 2026-05-10, gap G4.
- **`spec/10-observability.md` §10.7.1** — added explicit
  module-root path resolution rule. Generators MUST resolve target
  paths against the language module root (the directory containing
  `go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`,
  `deno.json`), not the project root. Multi-language monorepos run
  the generator independently for each detected stack. Source:
  cparx pilot 2026-05-10, gap G1.

### Conformance impact for host implementers

- Hosts at v0.2.0 remain conformant for v0.2.0 claims (clarifications,
  not new requirements).
- Hosts wishing to claim v0.2.1 SHOULD update their templates to
  apply the recoverer recommendation and MUST update their generator
  to resolve target paths against module roots if their stack
  templates ship anywhere other than the repo root.

## [0.2.0] — 2026-05-10

First observability spec section. Introduces the contract for
event emission, trace context propagation, mandatory instrumentation
points, and the generator obligation.

### Added

- **`spec/10-observability.md`** — declarative contract for
  observability. Defines the wrapper interface (`logEvent`,
  `captureError`, `startSpan`), the seven-field event envelope, W3C
  `traceparent` as the cross-service correlation primitive, four
  mandatory instrumentation points (handler entry, outbound calls,
  caught errors, business events), operational requirements
  (non-blocking emission, fail-safe behavior, PII discipline,
  sampling), destination independence, the generator obligation, and
  the project metadata block. Host-agnostic and vendor-agnostic.
- **`adrs/0014-observability-architecture.md`** — two-layer
  architecture decision: normative contract in the core spec +
  per-host generator skill that produces conformant code for each
  tech stack. Documents nine rejected alternatives (vendor-direct
  installs, OTel-direct, single-service logo-wall vendors,
  one-vendor-per-concern, internal package distribution, spec-only,
  generator-only, auto-apply, defer-until-first-incident).

### Conformance impact for host implementers

- Hosts at v0.1.0 remain conformant for v0.1.0 claims (additive
  minor).
- Hosts wishing to claim v0.2.0 MUST provide an observability
  generator skill satisfying §10.7 and MUST produce projects that
  satisfy §10.1–§10.6 + §10.8.

## [0.1.0] — 2026-05-09

First public release. Establishes the canonical specification baseline.

### Added

**Spec (10 files):**
- `spec/00-overview.md` — workflow elevator pitch, four pillars, and
  glossary of six terms (gate, hook, phase, plan, verification, ADR).
- `spec/01-commitment-ritual.md` — canonical Step 0 commitment block.
  Reproduction required verbatim by host implementations; substitution
  permitted inside `{{...}}` placeholders.
- `spec/02-hook-taxonomy.md` — declarative contract enumerating 15
  named gates (brainstorm-ui, brainstorm-architecture, design-shotgun,
  design-critique, tdd, ui-preview, verification, spec-review,
  code-review, security, database-security, qa, impeccable-audit,
  db-pre-launch-audit, branch-close) with trigger conditions, required
  evidence artifacts, and binding guidance.
- `spec/03-rationalization.md` — canonical 7-row rationalization table.
- `spec/04-red-flags.md` — canonical 13 red flags.
- `spec/05-pressure-test.md` — canonical 3-question pressure test.
- `spec/06-evidence-rules.md` — declarative verification-before-completion
  contract. Permitted evidence shapes (test output, grep result, curl
  response, screenshot path, file existence, diff snippet); forbidden
  patterns (manually verified, trust me); 1:1 evidence-to-`must_have`
  correspondence requirement.
- `spec/07-two-stage-review.md` — declarative two-stage review contract.
  Stage 1 (spec compliance) before Stage 2 (code quality); independent
  reviewer agent required for Stage 2; forbidden collapses enumerated.
- `spec/08-migration-format.md` — declarative migration file format.
  Filename convention, frontmatter fields, four-section step structure,
  idempotency contract, atomicity contract, dry-run mode requirement.
- `spec/09-conformance.md` — full / partial / consumer-only conformance
  levels, citation format (`implements_spec: 0.1.0` in host frontmatter),
  allowed extensions, drift policy.

**ADRs (4 files):**
- `adrs/0010-backend-language-routing-go.md` — per-language Stage 2
  review skill packs.
- `adrs/0011-impeccable-design-quality-gate.md` — pre-phase critique +
  finishing audit via `pbakaus/impeccable`.
- `adrs/0012-database-sentinel-rls-audit-gate.md` — RLS sub-gate via
  `Farenhytee/database-sentinel`; CVE-2025-48757, MongoBleed, pgBouncer
  references.
- `adrs/0013-migration-framework.md` — versioned migration framework
  rationale; cross-references spec section 08 for the format spec.

**Reference implementations:**
- `reference-implementations/README.md` — adoption table for
  `claude-workflow`, `pi-agentic-apps-workflow`, `codex-workflow`, and
  `agenticapps-dashboard`. All rows currently TBD pending each host's
  own adoption PR.

**Tools:**
- `tools/drift-report.sh` — advisory health check (read-only, exit 0
  always). Greps each host clone for canonical phrases. NOT a CI gate
  at v0.1.0.

### Conformance impact for host implementers

This is the first release. Hosts targeting v0.1.0 MUST:

1. Reproduce the four canonical-prose blocks (sections 01, 03, 04, 05)
   verbatim in their host-instruction file.
2. Satisfy the four declarative contracts (sections 02, 06, 07, 08)
   in the host's idiom.
3. Document host-specific bindings for every gate whose trigger
   condition can occur in the host's project type.
4. Add `implements_spec: 0.1.0` to the host's primary instruction-file
   frontmatter.

Hosts that previously authored their own gate-mapping prose should
plan an adoption PR titled "Adopt agenticapps-workflow-core spec
v0.1.0" with its own GSD phase plan. Adoption is honor-system at
this version; the drift-report tool is advisory only.
