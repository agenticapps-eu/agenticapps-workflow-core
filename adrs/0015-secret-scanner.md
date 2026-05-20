# ADR-0015: Default secret-scanner CI gate for AgenticApps workflows

**Status:** Proposed
**Date:** 2026-05-20
**Linear:** —
**Decision:** **TBD — pending evaluation in `claude-workflow`'s `feat/v1.14.0-workflow-additions` branch.** This ADR ships at spec v0.4.0 as a placeholder so the ADR number is reserved and downstream evaluations have a stable target file to amend. Ratification, including the populated Decision block and Consequences, happens via the claude-workflow evaluation phase that benchmarks the candidates on a known repo and updates this file in place. The keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Context

AgenticApps workflows recommend a secret-scanner as a CI gate against committed credentials. Today the recommendation across reference implementations is `gitleaks` — mature, widely adopted, well-tuned against false positives, integrated into many existing CI templates. The recommendation is not currently codified in a spec section; it lives in host-specific CI templates and the `add-observability` skill's CI fragments.

A newer Apache/MIT-licensed alternative, `betterleaks` (Aikido Security; authored by ex-Gitleaks maintainers), claims a strict superset of gitleaks' capabilities while remaining configuration-compatible:

- **Gitleaks-compatible config.** Accepts `gitleaks.toml`, `.gitleaksignore`, and inline `gitleaks:allow` comments. Migration from gitleaks is a binary swap.
- **Parallel git scanning.** Walks history in parallel rather than sequentially.
- **Recursive encoded-text decoding.** Detects secrets nested inside base64, hex, percent-encoding, and unicode escapes.
- **Token-efficiency filtering.** Uses BPE / `cl100k_base` to distinguish high-entropy random strings (likely secrets) from English text that happens to look high-entropy.
- **Regex-engine switching.** Selectable between `regex` crate and PCRE for performance vs feature trade-offs.
- **Archive scanning.** Looks inside zip / tarball / nested archives committed to the repo.
- **Composite rules with proximity matching.** Defines a rule as "pattern A within N lines of pattern B," which is harder to express in gitleaks' rule grammar.

The claim is a configuration-compatible upgrade path. The risk is that the additional features change the false-positive surface in ways that existing baselines do not predict.

Two motivations argue for picking a default explicitly rather than leaving the choice to each host:

1. **Cross-host consistency.** Host implementations of §10 (Observability) and the upcoming §11–§13 sections converge on a small set of CI gates. The secret-scanner gate is one of them. A specced default reduces drift between hosts and gives reviewers a known shape to assert against.
2. **Compounding cost of changing later.** Each host that ships a CI template with a scanner choice creates a baseline tied to that scanner's detection surface. Switching scanners later means re-baselining every project. Picking the default once, with deliberation, avoids the re-baseline cost.

A first-principles evaluation (2026-05-20) deferred the decision to a benchmark on a known repo with documented true-positive secrets, because the choice depends on false-positive behavior in practice — a question prose alone cannot answer.

## Decision

**TBD — pending evaluation in claude-workflow's `feat/v1.14.0-workflow-additions` branch.** The evaluation will benchmark the candidate scanners on a known repo (the current candidate fixtures are `factiv/cparx`'s historical `pilot-cparx-2026-05-10` baseline or `factiv/fx-signal-agent`'s scanner-gated branch — whichever has the cleanest documented mix of true-positive secrets and known-acceptable false-positive signal) and update this ADR's Decision block, Consequences, and References with the result.

The evaluation criteria the populated Decision block MUST address are:

1. **True-positive recall** on the benchmark repo. The scanner MUST detect every known secret without exception.
2. **False-positive rate** at the default rule set. The scanner SHOULD produce zero or near-zero false positives on a repo with a tuned `gitleaks.toml`.
3. **Migration cost** for existing AgenticApps projects on gitleaks baselines. The chosen scanner SHOULD accept the existing baseline without re-tuning.
4. **CI runtime** on a representative repo. The chosen scanner SHOULD complete within the host's CI budget for the gate.

The Decision block populated by the evaluation MUST be one of:

- **gitleaks** — default remains gitleaks; betterleaks is mentioned as an option for new repos.
- **betterleaks** — default switches to betterleaks; gitleaks projects MAY migrate at their convenience and MUST satisfy a documented migration recipe before claiming spec v0.4.0+ conformance.
- **both, with baseline mode** — betterleaks for new repos; gitleaks retained where a tuned baseline already exists. Higher maintenance burden but lower migration risk for tuned repos.

## Alternatives Rejected

The Alternatives section is preliminary; the populated ADR will move whichever candidate the evaluation selects into the Decision section and document why the others were rejected on the benchmark evidence.

- **Stay on gitleaks.** Defensible — mature, well-tuned, fewer surprises in production by track record. Risk: missed detections that the newer encoded-text and archive features would catch.
- **Switch to betterleaks.** Defensible — strictly more features, config-compatible migration path, same authorship lineage so the rule-tuning experience transfers. Risk: false-positive surface differs from gitleaks in ways tuned baselines do not yet capture.
- **Run both, baseline mode.** Defensible — preserves existing tuned baselines while enabling the new detections in new repos. Risk: two scanners to maintain, two CI surfaces, more rule-conflict resolution work over time.
- **Build a host-agnostic wrapper that routes to whichever scanner is installed.** Rejected up-front — recreates the destination-independence indirection §10 uses for observability, but for a gate where the wrapper would do nothing the scanner CLIs don't already do. The evaluation expects one default with a migration recipe, not a wrapper layer.
- **Defer the recommendation indefinitely; let each host choose.** Rejected up-front — perpetuates the current cross-host drift this ADR exists to close.

## Consequences

To be populated by the evaluation. The shape the populated Consequences MUST cover:

- **Positive consequences** of the chosen scanner — which detection capabilities improve, which CI gates tighten, which existing baselines remain valid.
- **Negative consequences** — migration burden for hosts not yet on the chosen scanner, false-positive surface changes, CI runtime changes, license / supply-chain implications.
- **Follow-ups** — whether to fold the secret-scanner recommendation into a spec section (e.g. a future §14 covering supply-chain gates), or to leave it as an ADR-level recommendation that hosts pick up via CI templates.

## References

- Spec section 0.4.0 trajectory: this ADR ships as Proposed at spec v0.4.0; ratification happens via claude-workflow's v1.14.0 evaluation phase.
- ADR-0014: Observability architecture — precedent for the "host-agnostic recommendation with per-host generator skill" shape this ADR may follow if the evaluation argues for it.
- gitleaks (status quo): https://github.com/gitleaks/gitleaks
- betterleaks (candidate): https://github.com/aikidosec/betterleaks
- RFC 2119: https://www.rfc-editor.org/rfc/rfc2119

---

*This ADR documents a host-agnostic decision. The Decision block is intentionally TBD at spec v0.4.0; it will be populated by the claude-workflow v1.14.0 evaluation phase that benchmarks the candidates and updates this file in place. Until that ratification, host implementations SHOULD continue using gitleaks as the de facto default and SHOULD NOT switch defaults based on this ADR's Proposed status alone.*
