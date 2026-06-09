# Reference Implementations

Host repos that adopt (or will adopt) the AgenticApps workflow spec.

**Current spec version:** 0.4.0 (released 2026-05-20). See `CHANGELOG.md`
in the spec root for the host-implementer actions required to move a
host row from a prior version to 0.4.0. Host rows below move via the
host's own adoption PR, not via this file.

| Host repo | Type | Spec version implemented | Conformance level | Notes |
|---|---|---|---|---|
| [claude-workflow](https://github.com/agenticapps-eu/claude-workflow) | Workflow scaffolder for Claude Code | 0.3.0 | `full` | Source of canonical prose. `add-observability` skill at v0.3.1 ships `implements_spec: 0.3.0`: §10.7 init flow (wrapper + middleware + per-stack policy + CLAUDE.md metadata, 5 stacks), §10.8 metadata schema, §10.9 MUSTs (`scan --since-commit`, `--update-baseline`, `.observability/{baseline,delta}.json`). §10.9.3 CI workflow shipped as opt-in reference (`observability.yml.example`); migration `0011` installs local-only enforcement (Option-4 stance documented in CLAUDE.md). |
| [pi-agentic-apps-workflow](https://github.com/agenticapps-eu/pi-agentic-apps-workflow) | Workflow scaffolder for pi.dev | 0.1.0 (target — adoption pending) | TBD | Pi runtime extension is a host-specific extension beyond the spec. |
| [codex-workflow](https://github.com/agenticapps-eu/codex-workflow) | Workflow scaffolder for OpenAI Codex CLI | [0.4.0](https://github.com/agenticapps-eu/codex-workflow/releases/tag/v0.2.1) | `full` | Native Codex skill re-author of the gate stack (1 trigger + 14 gate + 5 GSD entry-points + 2 lifecycle = 22 skills). v0.2.0 absorbs the 0.2.0→0.4.0 deltas: §11 Coding Discipline (verbatim in `AGENTS.md` behind a provenance anchor), §13 declare-first TS (`codex-ts-declare-first`, strengthens the `tdd` gate), §12 surgical Mermaid, and §10 observability **delegated** to the standalone `agenticapps-observability` skill (consumed via its Codex install surface — a *satisfied* §10 MUST per §09, not a delta; migration `0003`). Migration chain `0000`–`0004`. 8 spec/02 gates remain documented Spec Deltas in `docs/ENFORCEMENT-PLAN.md` (triggers cannot occur in a UI-less/DB-less scaffolder) — full conformance preserved per spec/09. |
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
