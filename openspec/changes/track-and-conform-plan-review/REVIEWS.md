## Reviewer: gemini
_generated 2026-07-29T07:30:40Z · timeout 600s_

VERDICT: REQUEST-CHANGES

- **The definition of a "review" is incomplete.** The proposal hinges on counting sections with a "parseable verdict", but never defines what format is considered parseable. This is a new, critical requirement for the gate and should be specified exactly (e.g., case-insensitive `^VERDICT:\s*(APPROVE|REQUEST-CHANGES)$`). Without this, the rule is ambiguous.

- **The self-exclusion mechanism is not specified.** The proposal correctly states that relying on `OPENSPEC_GATE_SELF` is fragile and opts to exclude the host's vendor "by rule". It does not, however, specify what that rule is or how the host vendor is determined, which is a critical detail for an independence guarantee.

- **The change increases data exfiltration risk without mitigation.** By lowering the success threshold to one reviewer, the tool will now send prompts to third-party vendors more often, including in cases where it previously would have failed and sent nothing. While deferring a full secret-scanner is reasonable, the proposal should acknowledge this increased risk and clarify that invocation implies consent for *all requested vendors*, not just those that succeed.

- **The rollback plan is incomplete.** It covers restoring the script, but omits reverting the corresponding breaking changes to spec §18, which would leave the spec and the (rolled-back) tool in a contradictory state.

## Reviewer: codex
_generated 2026-07-29T07:33:06Z · timeout 600s_

VERDICT: REQUEST-CHANGES

- The OpenSpec delta contains only the new producer capability; the normative §18 changes exist only as proposal prose/tasks. Add an actual modified-capability delta or exact normative patch so validation and reviewers can assess the changed contract.
- The gate still counts reviewer headings without requiring verdicts, while tasks harden only the producer. Hand-written, stale, or older-producer evidence can therefore pass. Update and version the gate, conformance harness, README, and host publication path.
- “Determine the running host by rule” is undefined and impossible for one shared host-agnostic binary to infer reliably. Specify an authoritative identity input and fail closed when it is absent or invalid.
- Task 7.3 does not fix process-table exposure: the producer already passes a file to `reviewer-cli.sh`, which reads it and passes the full prompt as a vendor CLI argument. The wrapper and its tests/version must change.
- Reviews are not bound to the reviewed artifact revision. An amended change can retain an old `REVIEWS.md`, and a failed rerun deliberately leaves it untouched. Record content hashes and have the gate verify them, or define reliable invalidation.
- The egress contract overstates its boundary: agentic vendor CLIs may inspect files beyond the prompt, and “invocation is consent” removes the existing explicit vendor×file confirmation. Document actual tool access, require affirmative consent, and address the untrusted third-party output ingress; deferring secret/PII screening does not make those guarantees true.

## Reviewer: opencode
_generated 2026-07-29T07:35:02Z · timeout 600s_

I'll verify the change's claims against the actual repo and installed files before issuing a verdict.
Session handoff read (modified today). Line counts and version markers check out. Now verifying the §18 spec claims:
The contradiction claim is verified (truth table says ≥1, lines ~146/174 say ≥2). Now checking the producer code, the change's own REVIEWS.md, and the resolver/installer claims:

