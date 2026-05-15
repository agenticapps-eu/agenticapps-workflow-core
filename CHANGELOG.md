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
