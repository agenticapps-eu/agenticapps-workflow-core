---
id: 00-overview
section_type: framing
spec_version: 0.7.0
---

# 00 — Overview

**Section type**: framing. This file is context for the reader. It is not
normative. Host implementations do not need to satisfy anything in this
file directly; the requirements live in the canonical-prose and
declarative-contract sections that follow.

## What this workflow is

A spec-first development discipline for AgenticApps projects. It
combines four pillars:

1. **Commitment ritual** — the agent emits a public, written
   commitment listing every skill it will invoke before touching any
   code (canonical block in section 01). Cialdini's commitment principle
   keeps it consistent with what it said.
2. **Hook taxonomy** — a fixed set of named gates fire at known points
   in the phase lifecycle (section 02). Each host binds a concrete skill
   to each gate; the gate names themselves are spec-canonical.
3. **Evidence rules** — every task completion produces on-disk evidence
   (test output, grep result, screenshot path, curl response) before
   the agent claims completion (section 06). Manual assertions don't
   count.
4. **Two-stage review** — spec-compliance review (Stage 1) and
   code-quality review (Stage 2) are separate review passes by separate
   reviewer agents (section 07). Collapsing them defeats both.

The workflow is deliberately verbose. It exists because LLM agents
under deadline pressure rationalize their way out of unloved steps —
TDD becomes "we'll add tests later", verification becomes "manually
verified", reviews collapse into one. The commitment ritual + 13 red
flags + rationalization table are designed to make that rationalization
visible to the agent itself.

## Why this spec exists

Until v0.1.0, the canonical text for the discipline lived only in
`claude-workflow`, the Claude Code reference implementation. As the
pi.dev port and the codex.dev port (planned) consumed parts of it,
prose drift emerged: missing red flags, half-ported tables, slightly
reworded ritual blocks. Without a canonical spec, every new host
either re-derives the discipline or copies a snapshot of one host's
prose, and the implementations slowly fork.

This repo is the source of truth. Host repos cite a spec version,
reproduce canonical-prose blocks verbatim, and satisfy declarative
contracts in their own idiom.

## How to read this spec

- Sections 00 and 09 are **framing** — read them to orient.
- Sections 01, 03, 04, 05, 11 are **canonical prose** — host
  implementations reproduce these blocks verbatim. Substitution is
  permitted only inside `{{...}}` placeholders.
- Sections 02, 06, 07, 08, 10, 12, 13, 14, 15 are **declarative
  contracts** — host implementations satisfy the listed MUST / SHOULD
  / MAY requirements in whatever idiom is natural for the host runtime.

Section 10 (observability) was introduced at spec v0.2.0, amended at
v0.2.1 (cparx-pilot patches), extended at v0.3.0 with the conformance
enforcement primitives in §10.9, and clarified at v0.3.2 with the §10.5
Flush-primitive obligation. Section 11 (coding discipline), section 12
(authoring conventions), and section 13 (TS declare-first skill) were
added at v0.4.0 as additive minor sections. Section 02 (hook taxonomy)
gained the `plan-review` pre-execution gate at v0.5.0, specifying the
robust phase-resolution order and grandfather rule. Section 14
(prompt-injection defense) was added at v0.6.0 as an additive minor
section, conditional on the host shipping an LLM prompt-building surface
(ADR-0016). Section 15 (knowledge capture) was added at v0.7.0 as an
additive minor section — wired per host, activated per repo via an
opt-in `knowledge_capture` block in `.planning/config.json`
(ADR-0017). Hosts may claim conformance against any of those versions;
the version the host claims is the version the host's `implements_spec`
field names.

Every file's frontmatter declares its `section_type`. Every declarative
file cites RFC 2119 for keyword semantics.

## Glossary

The six terms used most across this spec.

**Gate** — a named control point in the workflow lifecycle (e.g.
`brainstorm-ui`, `verification`, `code-review`). Each gate has a
trigger condition and a required evidence artifact. Hosts bind a
concrete skill or tool invocation to each gate. The complete list is
in section 02.

**Hook** — a host-runtime mechanism that fires a gate's bound skill
when the trigger condition is met. Hooks may be declarative (a config
file the host reads) or runtime (a process that observes events and
fires the bound skill). The spec is silent on hook implementation;
hosts choose.

**Phase** — a unit of work in the GSD (Get Stuff Done) discipline.
A phase has a CONTEXT.md (decisions and alternatives), a PLAN.md (task
breakdown), an executed series of atomic commits, a VERIFICATION.md
(evidence of `must_have` satisfaction), and a REVIEW.md (Stage 1 and
Stage 2 review findings).

**Plan** — a single executable unit inside a phase, owned by one
executor. A plan has tasks, optional `tdd="true"` markers, and an
expected outcome verifiable against the phase's `must_have` list.

**Verification** — the act of producing on-disk evidence (test output,
grep result, screenshot path, curl response) that demonstrates a
`must_have` is satisfied. Section 06 specifies the evidence rules.

**ADR** — Architecture Decision Record at `docs/decisions/NNNN-slug.md`.
Captures non-trivial technology / architecture / UX decisions with
rationale and rejected alternatives. The four ADRs in `adrs/` are
host-agnostic decisions that apply across implementations.
