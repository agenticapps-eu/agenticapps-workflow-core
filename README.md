# AgenticApps Workflow Core

The canonical specification for the AgenticApps development workflow —
the **commitment ritual**, **hook taxonomy**, **evidence rules**, and
**two-stage review** discipline that every AgenticApps host repo
implements.

This repo contains *prose specifications*. It is not a library, not a
plugin, and not source code. Host repos read the spec at design time
and implement it independently. Each host cites the spec version it
satisfies.

## Why this exists

Four sibling repos share the same workflow discipline:

- [`claude-workflow`](https://github.com/agenticapps-eu/claude-workflow) —
  scaffolder for Claude Code projects.
- [`pi-agentic-apps-workflow`](https://github.com/agenticapps-eu/pi-agentic-apps-workflow) —
  scaffolder for pi.dev projects.
- `codex-workflow` — scaffolder for OpenAI Codex CLI projects (planned).
- [`agenticapps-dashboard`](https://github.com/agenticapps-eu/agenticapps-dashboard) —
  artifact viewer that consumes workflow output.

Until now, the canonical text for the discipline lived only in
`claude-workflow`. As pi adopted parts of it, prose drift emerged:
small wording divergences, half-ported sections, missing red flags.
Without a canonical spec, every new host either re-derives the
discipline or copies the latest snapshot of one host's prose — and
the four implementations slowly fork.

This repo is the source of truth. Host repos cite a spec version,
reproduce canonical-prose blocks verbatim, and satisfy declarative
contracts in their own idiom.

## How host repos consume this spec

There is no programmatic distribution mechanism. No npm package, no
git submodule, no `@include` directives, no preprocessor. Host repos
adopt the spec by reading it.

A host implementation:

1. Picks a spec version to target (currently `0.1.0`).
2. Records that version in its own SKILL.md / AGENTS.md / equivalent
   project-instruction file: `implements_spec: 0.1.0`.
3. For every **canonical-prose** section, reproduces the block
   verbatim in the appropriate location in the host's instruction
   files. Substitution is permitted only inside `{{...}}` placeholders.
4. For every **declarative-contract** section, satisfies the listed
   MUST / SHOULD / MAY requirements in whatever idiom is natural for
   the host runtime.
5. Optionally claims a conformance level (`full`, `partial`, or
   `consumer-only`) in `reference-implementations/README.md` here.

The implementer's job is to *read this spec* and *write their host's
artifacts* accordingly. The spec does not generate code.

## Layout

```
spec/                      Ten files: the workflow specification
  00-overview.md           Elevator pitch + glossary (framing)
  01-commitment-ritual.md  Canonical block (verbatim reproduction required)
  02-hook-taxonomy.md      Gate definitions (declarative contract)
  03-rationalization.md    Canonical 7-row table (verbatim)
  04-red-flags.md          Canonical 13 red flags (verbatim)
  05-pressure-test.md      Canonical pressure-test block (verbatim)
  06-evidence-rules.md     Verification-before-completion (declarative)
  07-two-stage-review.md   Independent-reviewer requirement (declarative)
  08-migration-format.md   Migration file format (declarative)
  09-conformance.md        Per-host MUST / SHOULD / MAY (framing)

adrs/                      Host-agnostic architecture decisions
  0010-backend-language-routing-go.md
  0011-impeccable-design-quality-gate.md
  0012-database-sentinel-rls-audit-gate.md
  0013-migration-framework.md

reference-implementations/
  README.md                Table of host repos and their conformance state

tools/
  drift-report.sh          Advisory health check (not CI)

CHANGELOG.md               Per-version conformance impact for hosts
LICENSE                    MIT
```

## Section types

Every spec/ file declares its `section_type` in frontmatter:

- **`canonical-prose`** — the block must be reproduced verbatim by host
  implementations. Substitution only inside `{{...}}` placeholders.
  Sections 01, 03, 04, 05.
- **`declarative-contract`** — host implementations must satisfy the
  listed MUST / SHOULD / MAY requirements but are free to phrase them
  idiomatically. Sections 02, 06, 07, 08.
- **`framing`** — context for the reader. Not normative. Sections 00, 09.

Declarative sections cite [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119)
for keyword semantics.

## Conformance

A host claims conformance at one of three levels:

- **`full`** — every canonical block reproduced, every declarative
  requirement satisfied.
- **`partial`** — most requirements satisfied; deltas listed in the
  host's own SKILL.md.
- **`consumer-only`** — the host reads workflow artifacts produced
  by another host but does not author them itself (e.g. the dashboard).

Conformance is honor-system at v0.1.0. `tools/drift-report.sh` is
advisory, not a CI gate. Stricter enforcement is reserved for a later
spec version.

## Versioning

Semver. See `CHANGELOG.md` for the per-version conformance impact for
host implementers.

## Contributing

This spec is maintained by AgenticApps EU. Proposals for changes:

1. Open an issue describing the proposed change and which section it
   touches.
2. Indicate whether the change is patch / minor / major.
3. For canonical-prose changes, propose the literal new block side-by-
   side with the existing one — diff-readability matters.
4. PRs must update CHANGELOG.md with the conformance impact.

## License

MIT. See `LICENSE`.
