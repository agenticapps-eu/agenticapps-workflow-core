# Reference Implementations

Host repos that adopt (or will adopt) the AgenticApps workflow spec.

**Current spec version:** 0.9.1 (released 2026-07-15). See `CHANGELOG.md`
in the spec root for the host-implementer actions required to move a
host row from a prior version to 0.9.0. Host rows below move via the
host's own adoption PR, not via this file.

| Host repo | Type | Spec version implemented | Conformance level | Notes |
|---|---|---|---|---|
| [claude-workflow](https://github.com/agenticapps-eu/claude-workflow) | Workflow scaffolder for Claude Code | 0.9.0 | `full` | Source of canonical prose. Audited 2026-07-14 (host ADR-0040); `skill/SKILL.md` carries `implements_spec: 0.9.0`. §10 observability and §14 prompt-injection **delegated** to the standalone [`agenticapps-observability`](https://github.com/agenticapps-eu/agenticapps-observability) skill (0.13.0) and its `injection-guard` sub-skill — *satisfied* MUSTs per §09, not deltas; migrations `0022`/`0023` fail closed if the skill is absent. The `add-observability` skill this row previously credited was removed from this host at its 2.0.0 (`217baec`) and now lives in that standalone repo. §15 knowledge capture wired at all three ritual triggers, config-routed (no hardcoded vault path), guarded by `check-snapshot-parity.sh`. Setup installs via **snapshot, not replay** (host ADR-0036) — conformant under §08 **as amended at 0.9.0** (ADR-0018), with end-state equivalence guarded by `migrations/check-snapshot-parity.sh` in CI. Spec deltas listed in the host's `skill/SKILL.md`: §13's implicit GSD trigger is unwired (§13's Conformance is SHOULD/MAY and the host is not a TS project); a divergent §04 copy ships in the host's vendored CLAUDE.md payload (the canonical block is byte-identical in the host's own instruction file, so §09 item 1 holds). |
| [pi-agentic-apps-workflow](https://github.com/agenticapps-eu/pi-agentic-apps-workflow) | Workflow scaffolder for pi.dev | 0.1.0 (target — adoption pending) | TBD | Pi runtime extension is a host-specific extension beyond the spec. |
| [codex-workflow](https://github.com/agenticapps-eu/codex-workflow) | Workflow scaffolder for OpenAI Codex CLI | [0.4.0](https://github.com/agenticapps-eu/codex-workflow/releases/tag/v0.2.1) | `full` | Native Codex skill re-author of the gate stack (1 trigger + 14 gate + 5 GSD entry-points + 2 lifecycle = 22 skills). v0.2.0 absorbs the 0.2.0→0.4.0 deltas: §11 Coding Discipline (verbatim in `AGENTS.md` behind a provenance anchor), §13 declare-first TS (`codex-ts-declare-first`, strengthens the `tdd` gate), §12 surgical Mermaid, and §10 observability **delegated** to the standalone `agenticapps-observability` skill (consumed via its Codex install surface — a *satisfied* §10 MUST per §09, not a delta; migration `0003`). Migration chain `0000`–`0004`. 8 spec/02 gates remain documented Spec Deltas in `docs/ENFORCEMENT-PLAN.md` (triggers cannot occur in a UI-less/DB-less scaffolder) — full conformance preserved per spec/09. |
| [opencode-workflow](https://github.com/agenticapps-eu/opencode-workflow) | Workflow scaffolder for opencode | 0.4.0 | `full` | Forked from `codex-workflow`, then **rebound to upstream rather than re-ported**: GSD and Superpowers are consumed as upstream skills instead of re-authored as `opencode-*` copies, so the stack is 11 skills (1 trigger + 8 gate + 2 lifecycle) against codex's 22, and gates bind `superpowers:*` directly. §11 Coding Discipline verbatim in `AGENTS.md` behind a provenance anchor; §13 declare-first TS (`opencode-ts-declare-first`, strengthens the `tdd` gate); §10 observability **delegated** to the standalone `agenticapps-observability` skill (a *satisfied* §10 MUST per §09, not a delta; migration `0003`, ADR-0005). Installs from a **snapshot, not a migration replay** (ADR-0007) — `check-snapshot-parity.sh` keeps snapshot ≡ chain end-state. Migration chain `0000`–`0006`. Spec deltas documented in `docs/ENFORCEMENT-PLAN.md` — full conformance preserved per spec/09. **§15 knowledge capture is implemented** (v0.3.0, migration `0005`, ADR-0008) ahead of the claim: `implements_spec` tracks the last full audit (0.4.0), not incremental wiring, so the row stays 0.4.0 until §05 `plan-review` and §14 are wired. |
| [agenticapps-dashboard](https://github.com/agenticapps-eu/agenticapps-dashboard) | Workflow artifact viewer | 0.1.0 (target — adoption pending) | TBD (consumer) | Reads workflow artifacts produced by hosts; does not author them. |

## Conformance levels

See section 09 of the spec for the normative definitions.

- **`full`** — every canonical-prose block reproduced verbatim, every
  declarative-contract MUST satisfied.
- **`partial`** — most requirements satisfied; deltas listed in the
  host's own instruction file.
- **`consumer-only`** — reads workflow artifacts; does not author them.

## Adopting the spec

Each host opens its own PR titled "Adopt agenticapps-workflow-core
spec v0.1.0" with its own GSD phase plan. The follow-up issues filed
when v0.1.0 ships are the prompt for that work; this repo does not
do the adoption.

When a host completes adoption, the corresponding row above moves
from "TBD" to `full`, `partial`, or `consumer-only`.
