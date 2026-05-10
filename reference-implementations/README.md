# Reference Implementations

Host repos that adopt (or will adopt) the AgenticApps workflow spec.

| Host repo | Type | Spec version implemented | Conformance level | Notes |
|---|---|---|---|---|
| [claude-workflow](https://github.com/agenticapps-eu/claude-workflow) | Workflow scaffolder for Claude Code | 0.1.0 (target — adoption pending) | TBD | Source of canonical prose; first to adopt the spec. |
| [pi-agentic-apps-workflow](https://github.com/agenticapps-eu/pi-agentic-apps-workflow) | Workflow scaffolder for pi.dev | 0.1.0 (target — adoption pending) | TBD | Pi runtime extension is a host-specific extension beyond the spec. |
| [codex-workflow](https://github.com/agenticapps-eu/codex-workflow) | Workflow scaffolder for OpenAI Codex CLI | [0.1.0](https://github.com/agenticapps-eu/codex-workflow/releases/tag/v0.1.0) | `full` | First reference implementation to ship. Full re-author of the gate stack as native Codex skills (1 trigger + 13 gate + 5 GSD entry-points + 2 lifecycle = 21 skills). 8 spec/02 gates documented as Spec Deltas in `docs/ENFORCEMENT-PLAN.md` because their triggers cannot occur in the scaffolder's project type (no UI, no DB, no dev server) — full conformance preserved per spec/09. |
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
