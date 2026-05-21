# ADR-0015: Default secret-scanner CI gate for AgenticApps workflows

**Status:** Accepted
**Date:** 2026-05-20 (Proposed) → 2026-05-21 (Accepted via ratification PR from `claude-workflow` Phase 20 P4)
**Linear:** —
**Decision:** **STAY on gitleaks.** Ratified by benchmark in `claude-workflow`'s `feat/v1.14.0-workflow-additions` Phase 20 P4. See the Decision section below for the scorecard and the locked rule that fired. The keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

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

**STAY on gitleaks.** The AgenticApps default secret-scanner CI gate remains `gitleaks`. New AgenticApps projects SHOULD adopt gitleaks; existing projects on gitleaks SHOULD NOT migrate based on this ADR. Hosts MAY evaluate betterleaks locally; this ADR does not foreclose that, but does not recommend the switch.

### How the ratification was performed

The benchmark was authored in `claude-workflow`'s Phase 20 P4 against a fixture, with all criteria and the decision rule LOCKED in `RESEARCH.md` BEFORE any scanner ran. Locked methodology, no post-hoc threshold tuning. Full artifacts (raw JSON / SARIF outputs, timing logs, per-criterion notes) live outside the cross-repo PR scope; the local `claude-workflow` ADR-0024 references them by path.

- **Versions benchmarked:** `gitleaks 8.30.1`, `betterleaks 1.3.0` (both from homebrew-core on darwin/arm64, both MIT).
- **Fixture:** `vercel-labs/deepsec/fixtures/vulnerable-app/` at commit `74549bbd8bef45d16c4efd5bbe8ba2c8076cab83`. Five seeded secrets in `src/config.ts` annotated `// VULN: secrets-exposure`. The first-choice fixture (cparx) had no documented seeded-secret catalog, so the benchmark fell back to the pre-declared alternative.
- **Locked decision rule:** SWAP = criteria 1, 2, 5, 6 ALL met AND at least one of {3, 4, 7} met. STAY = gitleaks ties or wins on criterion 1 OR 2. REVISIT = anything else.

### Scorecard

| # | Criterion | gitleaks 8.30.1 | betterleaks 1.3.0 | Threshold to swap | Met? |
|---|-----------|------------------|---------------------|--------------------|------|
| 1 | TP recall on documented seeded secrets | 1 of 5  | 1 of 5  | `≥ gitleaks (equal → tie)` | **TIE** — STAY |
| 2 | FP count (in-scope)                    | 0       | 0       | `≤ gitleaks`              | **TIE** — STAY |
| 3 | Wall-clock median (3 runs, full history) | 0.53s   | 0.40s   | `≤ 0.5× gitleaks`         | NOT MET (0.75×) |
| 4 | Base64-encoded secret detection        | **YES** | **NO**  | `betterleaks detects AND gitleaks doesn't` | NOT MET — **INVERTED** |
| 5 | Honors `.gitleaksignore`               | yes     | yes     | `TP suppressed`           | MET |
| 6 | Honors `gitleaks:allow` inline         | yes     | yes     | `TP suppressed`           | MET |
| 7 | SARIF output equivalence               | identical | identical | `JSON-comparable rule_id / location` | MET |

### Which rule fired

**STAY** — triggered by ties on BOTH criterion 1 AND criterion 2. Either alone would have been sufficient.

The most informative non-deciding signal: **criterion 4 inverted vs the prediction in claude-workflow's RESEARCH.md A1.** RESEARCH.md A1 named "recursive encoded decoding" as a betterleaks differentiator. In practice on this fixture, gitleaks 8.30.1 decodes inline base64 to find an embedded AWS-shape access key by default; betterleaks 1.3.0 does not surface the same encoding with default flags, `--max-decode-depth 10`, or any of five tried `--experiments` values. This is a credibility-positive secondary signal for keeping the incumbent.

### Why the original "Decision MUST be one of" enumeration doesn't fit

The Proposed ADR enumerated three candidate outcomes (gitleaks / betterleaks / both, with baseline mode). The ratified outcome is the first — *gitleaks — default remains gitleaks; betterleaks is mentioned as an option for new repos* — with the addendum that the benchmark also surfaced a structural reason (criterion 4 inversion) beyond the strict tie-on-1/2 rule. The "both, with baseline mode" option is not pursued because no AgenticApps host currently ships a gitleaks-invoking CI template through the claude-workflow scaffolder (verified count = 0 at Phase 0 of the 1.14.0 PR); there is no tuned baseline to preserve.

## Alternatives Rejected

The Alternatives section is preliminary; the populated ADR will move whichever candidate the evaluation selects into the Decision section and document why the others were rejected on the benchmark evidence.

- **Stay on gitleaks.** Defensible — mature, well-tuned, fewer surprises in production by track record. Risk: missed detections that the newer encoded-text and archive features would catch.
- **Switch to betterleaks.** Defensible — strictly more features, config-compatible migration path, same authorship lineage so the rule-tuning experience transfers. Risk: false-positive surface differs from gitleaks in ways tuned baselines do not yet capture.
- **Run both, baseline mode.** Defensible — preserves existing tuned baselines while enabling the new detections in new repos. Risk: two scanners to maintain, two CI surfaces, more rule-conflict resolution work over time.
- **Build a host-agnostic wrapper that routes to whichever scanner is installed.** Rejected up-front — recreates the destination-independence indirection §10 uses for observability, but for a gate where the wrapper would do nothing the scanner CLIs don't already do. The evaluation expects one default with a migration recipe, not a wrapper layer.
- **Defer the recommendation indefinitely; let each host choose.** Rejected up-front — perpetuates the current cross-host drift this ADR exists to close.

## Consequences

**Positive:**

- AgenticApps default CI gate is unchanged. Zero migration cost for hosts already recommending gitleaks. No re-baselining of any tuned `gitleaks.toml` is required.
- Spec v0.4.0's outstanding ratification obligation is closed; downstream tooling (e.g. coverage matrices, conformance audits) can now treat ADR-0015 as Accepted rather than Proposed.
- gitleaks's built-in base64 decoding (verified in benchmark criterion 4) provides defense-in-depth against encoded-credential leaks that the original spec discussion attributed to betterleaks. No additional opt-in flag is required.
- The benchmark methodology itself — pre-declared 7-criterion scorecard with a locked SWAP/STAY/REVISIT decision rule — is a reusable artifact for the 12-month re-evaluation and for any future scanner candidate.

**Negative:**

- The "parallel git scanning" and "regex-engine switching" features named in this ADR's Context section are NOT being adopted. Hosts that would benefit from a 25% scan-time speedup (the observed delta on the benchmark fixture) MAY adopt betterleaks locally, but that's a per-host choice, not a recommendation.
- gitleaks's base64 detection is a defensible behavior on the benchmarked version but is not a stable contract — a future gitleaks release could regress it. A guarantee would require either a different fixture strategy or a contract test embedded in claude-workflow.
- The locked-threshold methodology is conservative by design: incremental improvements in betterleaks (e.g. another 25% speedup without crossing 2×) don't accumulate toward a switch decision. By intent; flagged as a trade-off.

**Follow-ups:**

- **12-month re-evaluation reminder (calendar 2027-05-21).** Re-run the same 7-criterion benchmark on the then-current betterleaks release. Re-evaluate sooner if betterleaks ships an obvious inline-decoder opt-in or a published 2× speedup claim on a representative corpus.
- **Fixture extension.** The single-fixture risk named in claude-workflow RESEARCH.md A6 still applies; a future re-evaluation SHOULD add at least one larger Go-or-TS repo with a hand-curated TP catalogue authored ahead of time. cparx is a natural candidate.
- **Fold into a spec section?** Defer. ADR-level recommendation remains adequate while only one scanner is recommended and the recommendation is unchanged from the de facto status quo. Revisit if a future ratification splits hosts.
- **Downstream pickup.** `claude-workflow` Phase 20 P6 skips adding a `secret-scan.yml.example` to `add-observability/enforcement/` because STAY preserves the zero-template status quo. The `pi-agentic-apps-workflow` and `codex-workflow` mirror-PRs (tracked in claude-workflow Phase 20 P6) inherit the STAY outcome without code changes; they only need to record the ratification in their changelogs.

## References

- Spec section 0.4.0 trajectory: shipped Proposed at spec v0.4.0 (2026-05-20); ratified Accepted at 2026-05-21 via this PR from `claude-workflow` Phase 20 P4.
- ADR-0014: Observability architecture — precedent for the "host-agnostic recommendation with per-host generator skill" shape. Not followed here: STAY does not produce a generator skill change.
- claude-workflow ADR-0024 (`docs/decisions/0024-secret-scanner-choice.md` in `claude-workflow`): the local mirror ADR that captures the STAY outcome with the same scorecard and links to the full benchmark artifacts.
- gitleaks (chosen): https://github.com/gitleaks/gitleaks (benchmarked at v8.30.1)
- betterleaks (evaluated, not chosen): https://github.com/betterleaks/betterleaks (benchmarked at v1.3.0). The original ADR draft pointed at `github.com/aikidosec/betterleaks`; that URL 404s today — the canonical upstream is `github.com/betterleaks/betterleaks` (MIT, active, homebrew-core bottle available). The "Aikido Security" attribution in the Context section above reflects the project's lineage; the canonical project name and repo URL are as listed here.
- RFC 2119: https://www.rfc-editor.org/rfc/rfc2119

---

*This ADR is now Accepted. The Decision block was populated at 2026-05-21 by the `claude-workflow` v1.14.0 evaluation phase (Phase 20 P4) that benchmarked the candidates under a methodology locked before any scan ran. Hosts SHOULD continue using gitleaks as the default secret-scanner CI gate. The next scheduled re-evaluation is calendar 2027-05-21 (12-month half-life named in Consequences §Follow-ups).*
