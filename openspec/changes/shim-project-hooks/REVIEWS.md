## Reviewer: gemini
_generated 2026-07-29T13:02:32Z · timeout 600s_

VERDICT: REQUEST-CHANGES
- The new spec delta rightly requires that shims carry a version marker for the contract they implement. This change, which revises the shim contract, should be the first to adopt this rule by adding a version marker (e.g., `SHIM_CONTRACT_VERSION=2`) to the three shims it modifies.
- The spec requires that publishing multiple implementations "SHALL be atomic". The migration plan should briefly state how this atomicity will be achieved by the installer, or acknowledge it as a modification to be made to the `install-shared-artifact.sh` script.
- The spec requires the installer to record a content digest for provenance checking. This is a critical security mitigation. The migration plan should explicitly include adding this functionality to the installer as part of step 2.

## Reviewer: codex
_generated 2026-07-29T13:05:13Z · timeout 600s_

VERDICT: REQUEST-CHANGES

- The deletion proof contradicts the delta: the proposal infers `design-shotgun-gate` is not enforcement solely because its sentinel is not §02 evidence, while the new requirement explicitly says that fact is insufficient. Complete the enforcement audit before approving deletion, not in implementation task 5.0a.
- Provenance is underspecified. A digest of “what was published” does not prove correspondence to maintained source, and a manifest beside the user-writable executable can be altered with it. Define the hash contract, trust location, source comparison, check trigger, and atomic file/manifest update—or limit the claim to accidental drift detection.
- The contract governs every fleet-shared hook but derives fail-open behavior from `PreToolUse`. `normalize-claude-md` is `PostToolUse`; future `SessionStart`/`Stop` hooks have different semantics. Scope the requirement or specify and test each supported event class.
- An invalid environment override deliberately bypasses a healthy shared installation. This new kill switch is missing from the documented security boundary; restrict overrides to an explicit test mode or document and test the bypass, including whether project-controlled configuration can set it.
- “Always take the superset of protection” is an unsafe fleet-wide rule. Broader variants can introduce false positives, incompatible project policy, or reachable-but-obsolete checks. Require deliberate compatibility review and documented opt-outs, not an unconditional union.
- A machine-global, unpinned implementation makes older branches and projects non-hermetic. The delta has no compatibility/version negotiation or rollback scenario when different project revisions require different hook behavior.
- Artifacts remain inconsistent: the proposal both includes `claude-workflow` among nine touched repos and calls it untouched; task 4.3 permits omitting the unregistered normalize shim, while task 5.3 requires every project to carry exactly three hooks.

## Reviewer: opencode
_generated 2026-07-29T13:06:07Z · timeout 600s_

I'll review this change adversarially. Let me first check the session handoff and then verify key claims against the actual repo.

