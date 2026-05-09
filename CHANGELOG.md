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
