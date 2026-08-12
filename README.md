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

**This repository is the only implementation.** Every host — Claude Code, Codex
CLI, opencode, pi — resolves its behaviour from here: `install.sh` publishes the
executables to `~/.agenticapps/bin/` and symlinks the skills into each host's
directory. There is no per-host copy to keep in step.

That is the outcome the spec was written for rather than the situation it was
written in. Four sibling scaffolders once shared this discipline —
`claude-workflow`, `codex-workflow`, `opencode-workflow` and
`pi-agentic-apps-workflow` — with the canonical text living only in
`claude-workflow`. As the others adopted parts of it, prose drift emerged: small
wording divergences, half-ported sections, missing red flags. A canonical spec
was the answer to four implementations slowly forking; publishing one set of
bytes to every host removed the four. All four were archived on GitHub on
2026-08-05 and their checkouts deleted on 2026-08-12, as was
`agenticapps-dashboard`, the artifact viewer that consumed workflow output
(retired 2026-08-05).

The spec still earns its place: it is what the skills, the gate and the
reference implementations are held to, and what a future host would adopt.

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

## The workflow explained

For a narrative walkthrough of how the pieces fit — the OpenSpec spec
slot, the propose→validate→execute→archive lifecycle, the retargeted
change-gate, and where prose lives — read **[`docs/WORKFLOW.md`](docs/WORKFLOW.md)**.
As of **spec v1.0.0** the workflow's front end is **OpenSpec + Superpowers**
(§16–§19, ADR-0021), replacing the GSD engine; §02/§07 are remapped and the
0.x line stays valid (§09). No host cites 1.0.0 yet — see
`reference-implementations/README.md`.

## Layout

```
spec/                      The workflow specification (00–19)
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
  10-15 …                  observability, coding discipline, authoring,
                           TS declare-first, prompt-injection, knowledge capture
  16-openspec-spec-slot.md         OpenSpec front end (declarative, v1.0.0)
  17-lifecycle-and-gate-mapping.md OpenSpec front end (declarative, v1.0.0)
  18-retargeted-change-gate.md     OpenSpec front end (declarative, v1.0.0)
  19-spec-vs-process-and-linear.md OpenSpec front end (declarative, v1.0.0)

adrs/                      Host-agnostic architecture decisions
  0010 … 0020              (see directory)
  0021-openspec-superpowers-standard.md   The v1.0.0 front-end decision

docs/
  WORKFLOW.md              Reader-facing explainer of the workflow
  recipes/
    0001-planning-to-openspec.md   The planning→OpenSpec migration recipe

reference-implementations/
  README.md                Table of host repos and their conformance state

tools/
  *.test.sh                Test suites for the reference implementations
  *-conformance.sh         Harnesses scoring published artifacts against spec/

PILOT-REPORT.md            cParX OpenSpec pilot (2026-07-24) — the proven recipe
MEASUREMENT.md             Measured-trial evidence for the v1.0.0 adoption
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

Conformance is honor-system. Canonical-prose drift was measured by
`tools/drift-report.sh`, which was advisory rather than a CI gate and
was retired on 2026-08-12 along with the four host repositories that
were its entire subject. Nothing measures it now, and `spec/09` records
why and what would have to be true for a re-scoped check to be worth
building. Stricter enforcement is reserved for a later spec version.

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
