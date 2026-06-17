# ADR-0016: Prompt-injection defense as a portable spec section

**Status:** Accepted
**Date:** 2026-06-17
**Linear:** —
**Spec trajectory:** v0.6.0 (initial §14)

## Context

Three AgenticApps host repos ship an LLM surface that interpolates externally-derived data into model prompts: `callbot` (TypeScript / Cloudflare Workers), `cparx` (Go), and `fx-signal-agent` (TypeScript). Each of these has, or will have, the same injection surface — a tenant, a caller, or an upstream document can smuggle instructions into a channel the model treats as authoritative.

Of the three, only `fx-signal-agent` had built a defense, and it built it locally: REQ-SEC03 / D-05 introduced `@tenant-untrusted` / `@tenant-trusted` call-site markers enforced by a custom ESLint rule, a `tenant_untrusted_inputs.md` registry, and D-06 added a snapshot attack-matrix regression test with model-drift pinning. That work was effective but trapped in one repo and one stack. Left unspecified, the other two hosts would each re-derive a defense from scratch, diverge on which controls they consider load-bearing, and drift — the exact failure mode §10 (observability) was created to prevent.

Two forces shaped the decision:

1. **Repos must be self-contained.** Per this repo's model, a host never references workflow-core at runtime. So the defense cannot live as a shared library; it must be a contract defined once and mirrored into each host by a `claude-workflow` migration.
2. **The hosts diverge on stack.** A TypeScript ESLint rule has no Go equivalent. The contract therefore has to be expressed as language-neutral requirements with per-language bindings, exactly as §10 expressed the observability wrapper.

A first-principles read of the problem showed that the natural first move — "detect malicious input" — is the weakest possible control. Attackers iterate against heuristic detectors faster than detectors can be tuned, and a detector tuned tight enough to stop real attacks rejects legitimate input. The durable controls are architectural: knowing which values are untrusted, keeping untrusted values out of the instruction channel, validating output shape, and bounding blast radius with least privilege.

## Decision

Generalize the `fx-signal-agent` pattern into **`spec/14-prompt-injection.md`**, a declarative, RFC-2119 contract, and take an explicitly **architecture-first** stance: detection is named as the weakest layer and MUST NOT be the only control; the load-bearing guarantees are trust separation, output validation, and least privilege.

§14 defines seven requirements with per-language bindings:

1. **Trust classification** — every prompt-bound string is classified tenant-untrusted or tenant-trusted at its call site; ambiguous provenance fails closed to untrusted.
2. **Static enforcement** — CI fails the build on untrusted content interpolated without a marker (TypeScript: custom ESLint rule; Go: `go/analysis` analyzer), with the v1 inline-only limitation documented per host.
3. **Untrusted-input registry** — a human-readable, command-refreshable table of every untrusted call site, its origin, and a risk rating.
4. **Runtime trust separation** — a `fenceUntrusted` contract passes untrusted content as fenced user content, never concatenated into the instruction channel, stripping forged delimiters.
5. **Output validation + canary** — shape-validate known-schema output before use; plant a canary and assert it never leaks, promoted to a runtime check where feasible.
6. **Least privilege for tool-calling agents** — allowlist every tool dispatch from model output; require explicit confirmation for irreversible actions. N/A for single-shot surfaces.
7. **Dynamic regression test** — a (registered-input × attack-family × payload) matrix asserting schema validity and no canary leak, with model-drift pinning. Minimum attack families: instruction-override, role-reassign, system-prompt-probe, data-exfiltration, delimiter/structure.

Conformance is wired into §09: §14 is conditional — a host with no LLM prompt-building surface is trivially conformant via a spec delta, and a single-shot host records 14.6 (tool least-privilege) as N/A.

The contract is host-agnostic and vendor-agnostic. It names no model vendor, no prompt library, and no concrete function name. Propagation to host repos — the migration plus the per-stack `add-injection-guard` generator — is out of scope here and lives in `claude-workflow/ADD-INJECTION-GUARD-MIGRATION.md`, which depends on this section existing first.

## Alternatives considered

- **Per-repo defense, no spec section.** Rejected: guarantees divergence across the three hosts and re-derivation cost for every future LLM host, the same problem §10 solved for observability.
- **A shared runtime library hosts import.** Rejected: violates the self-contained-repos rule; hosts must not reference workflow-core at runtime, and the three hosts span TypeScript and Go with no shared runtime.
- **Detection-centric contract** (require an input classifier as the primary gate). Rejected on first principles: heuristic detection is evadable and lossy; mandating it as the load-bearing control would give a false sense of safety. Detection is permitted as defense-in-depth but never counts as one of the guarantees.

## Consequences

- A new minor spec version, **0.6.0**. Hosts at 0.5.0 remain conformant for 0.5.0 claims; claiming 0.6.0 requires satisfying §14 for each LLM-prompt-building stack, or declaring the trivial/single-shot delta.
- Hosts with no LLM surface (e.g. the dashboard) are unaffected — they declare §14 N/A.
- `fx-signal-agent`'s existing defense becomes the reference implementation; the migration (separate brief) will generalize its v1 ESLint rule, including closing the indirect-construction gap behind an option.
- Establishes the precedent that a security control proven in one host can be lifted into a portable, per-language-bound spec section rather than copied between repos.
