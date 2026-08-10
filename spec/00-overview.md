---
id: 00-overview
section_type: framing
spec_version: 2.1.0
---

# 00 — Overview

**Section type**: framing. This file is context for the reader. It is not
normative. Host implementations do not need to satisfy anything in this
file directly; the requirements live in the canonical-prose and
declarative-contract sections that follow.

Sections typed `core-tooling-contract` (§20) are the exception to that
sentence in the other direction: they are normative, but they bind the
tooling shipped in *this* repository rather than any host. A host does not
satisfy them and does not cite them. They are versioned with the spec
because the tools they govern are the ones that decide whether a host
conforms at all.

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
- Sections 02, 06, 07, 08, 10, 12, 14, 16, 17, 18, 19, 21 are
  **declarative contracts** — host implementations satisfy the listed
  MUST / SHOULD / MAY requirements in whatever idiom is natural for the
  host runtime. (Sections 13 and 15 were on this list until they were
  retired, at v2.0.0 and v1.2.0 respectively; see below.)
- Sections 16–19 are the **OpenSpec front end** (spec v1.0.0). A host
  citing 1.0.0 or later implements them; §02 and §07 are remapped onto
  the OpenSpec lifecycle for those hosts and remain as written for hosts
  citing a 0.x version.

Section 10 (observability) was introduced at spec v0.2.0, amended at
v0.2.1 (cparx-pilot patches), extended at v0.3.0 with the conformance
enforcement primitives in §10.9, and clarified at v0.3.2 with the §10.5
Flush-primitive obligation. Section 11 (coding discipline), section 12
(authoring conventions), and section 13 (TS declare-first skill) were
added at v0.4.0 as additive minor sections; section 13 was retired at v2.0.0. Section 02 (hook taxonomy)
gained the `plan-review` pre-execution gate at v0.5.0, specifying the
robust phase-resolution order and grandfather rule. Section 14
(prompt-injection defense) was added at v0.6.0 as an additive minor
section, conditional on the host shipping an LLM prompt-building surface
(ADR-0016). **Spec 2.0.0 (2026-08-09)** removes core's bindings for the
`database-security`, `db-pre-launch-audit` and design gates. The gates remain
defined in §02 with their triggers and evidence intact — §02's binding guidance
becomes MAY, and §17 records that each fires only where a host has bound a
skill. `database-sentinel` was removed from every host; `impeccable` stays
installed and is invoked on demand rather than automatically (ADR-0030,
superseding ADR-0011 and ADR-0012). This is breaking: two gates stop firing for
every consumer, and prior-major conformance claims become obsolete per §09.
**Section 13 (TS declare-first) is RETIRED at v2.0.0.** The number stays vacant
and nothing is renumbered, exactly as §15's retirement established — closing the
gap would invalidate every §14–§21 cross-reference in the fleet.

**Spec 2.1.0 (2026-08-10)** narrows §18's escape-hatch MUST. That clause requires
a documented hatch for whatever a host blocks on, and it had been vacuous since
gate 2.0.0 because a red `validate` was the only blocking condition and a hatch
could release nothing. Gate 2.1.0 adds a second — the two instruction-file names
must be readable, regular and byte-identical — which made the clause live again
and would have demanded a hatch for precisely the check whose whole value is that
it has none. §18 now names both conditions and states that neither takes one.
Minor rather than major: it removes an obligation and adds none, so a host
conformant at 2.0.0 stays conformant. It does **not** require hosts to implement
the pair check; where the two names live and what must be true of them is an
instruction-file requirement, and the gate script is only where the pre-commit
surface happens to be.

Three earlier attempts to retire §13 failed, and the reason is worth keeping: each
argued from **local machine state** — a skills directory, a deleted symlink,
`install.sh`'s `ARCHIVED` variable — about a section that leaves its implementing
skill's name to the host's discretion. Local absence never evidenced anything
about it. `reference-implementations/README.md` records three hosts binding it,
and those hosts are real: measured 2026-08-09 all four had live remotes and
commits four days old.

What makes the retirement legitimate is not that nobody implements it. It is that
**this release is already major on independent grounds** — the gate bindings
removed above obsolete every prior-major conformance claim under §09. Those three
hosts must re-assert against 2.0.0 regardless, so retiring §13 in the same release
adds no conformance cost that the release does not already impose. It is an
accepted break, made once, rather than a second break imposed later.

Section 15 (knowledge capture) was added at v0.7.0 (ADR-0017) and
**REMOVED at v1.2.0**. Its purpose — retaining what was learned across
sessions — is served by the OpenSpec archive: `openspec/changes/archive/`
retains each change's proposal, design, delta and review evidence
permanently, which §15's distilled note duplicated at lower fidelity.
**Section 15 is retired, not reused.** The number stays vacant so that
every §16–§19 reference in the fleet keeps resolving; renumbering to close
the gap would invalidate cross-references in four hosts. Section 04 (red flags) gained explicit composition rules for
host-specific additions at v0.8.0: additions are appended after the
canonical 13, and the heading's leading count is not normative —
resolving a contradiction that had left the section's own "adding is
permitted" allowance unusable. Section 08 (migration format) was amended
at v0.9.0 to make the *end state* of the setup flow normative rather than
the mechanism: setup MUST produce an end state equivalent to a full
`0000`→latest replay, reached either by replaying or by installing a
prebuilt snapshot assembled from the same sources behind a CI drift guard
(ADR-0018, superseding ADR-0013's assumption that every chain is
shell-replayable). Section 12 (authoring conventions) gained an
"Instruction-surface economy" convention at v0.10.0: the always-loaded
instruction file SHOULD carry the §11 block plus a pointer to the trigger
skill, with gate tables, routing, ritual tails, and gate-procedure prose
moved into the lazily-loaded skill — extending §12's existing placement
advisory from *ordering* to *membership* (ADR-0020). Spec **v1.0.0** is
the first major: it replaces the GSD-engine front end with the
**OpenSpec + Superpowers** front end. Sections 16–19 were added — the
OpenSpec spec slot (§16), the propose→validate→execute→archive lifecycle
and the §02 gate-mapping table (§17), the retargeted `PreToolUse`
change-gate (§18), and the spec-vs-process placement rule with loose
Linear coupling (§19). §02 and §07 are remapped for 1.0.0 hosts (the two
review gates collapse into `validate`; execution gates are retained) and
remain normative for 0.x hosts. The change is grounded in a measured
cParX pilot (`PILOT-REPORT.md`, `MEASUREMENT.md`) and recorded in
ADR-0021. Spec **v1.5.0** amends §18 and §17: the change-gate's review
clause becomes **reported rather than enforced**, leaving `openspec
validate --all` (or an unavailable `openspec` CLI) as the only condition
that blocks a code edit. The reviewer floor of one and the preference of
two survive as reported thresholds and every counting rule is retained
unchanged — what is withdrawn is the consequence, not the arithmetic. It
is a minor rather than a major because §18 simultaneously grants the
stricter posture as a declared §09 host extension, so a host that still
blocks on review state becomes a *declaring* host rather than a
non-conformant one. The grounds are measured and recorded in the
CHANGELOG's gate 2.0.0 entry: blocking cost three rollbacks and a
six-repository outage on 2026-07-30, and prevented nothing identifiable,
because third-party reviewer CLIs failed for reasons unrelated to change
quality. Spec **v1.6.0** adds section 21 (installer prerequisites and
consent) as an additive minor section. Four host installers had two
incompatible answers to "may this install software on my machine" — two
run `npm i -g` unprompted, two only instruct — and none of them offers.
§21 states the one answer: an installer declares its prerequisites,
reports what is missing, and obtains explicit acceptance before any write
that could change software the operator did not install by running it.
The boundary is **ownership, not location**, which is what keeps the
contract aimed at the two genuinely unconsented installs rather than at
all four hosts' `~/.agenticapps/bin/` write. Offering is SHOULD, so a
detect-and-instruct installer stays conformant; installing without asking
is what the section forbids. Hosts may claim
conformance against any
of those versions; the version the host claims is the version the host's
`implements_spec` field names.

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

**Phase** — the 0.x unit of work in the GSD (Get Stuff Done) discipline.
A phase has a CONTEXT.md (decisions and alternatives), a PLAN.md (task
breakdown), an executed series of atomic commits, a VERIFICATION.md
(evidence of `must_have` satisfaction), and a REVIEW.md (Stage 1 and
Stage 2 review findings). Under the 1.0.0 OpenSpec front end the unit of
work is a **change** instead (see below); phases remain the unit for
hosts citing a 0.x version.

**Change** — the 1.0.0 unit of product work: an OpenSpec change under
`openspec/changes/<slug>/` holding a proposal, a design note, a spec
delta, and a task list. It moves propose → validate → Superpowers-execute
→ archive (§17), and when done is folded into `openspec/specs/` and moved
to `changes/archive/`. See §16 and §17.

**Plan** — a single executable unit inside a phase, owned by one
executor. A plan has tasks, optional `tdd="true"` markers, and an
expected outcome verifiable against the phase's `must_have` list.

**Verification** — the act of producing on-disk evidence (test output,
grep result, screenshot path, curl response) that demonstrates a
`must_have` is satisfied. Section 06 specifies the evidence rules.

**ADR** — Architecture Decision Record at `docs/decisions/NNNN-slug.md`.
Captures non-trivial technology / architecture / UX decisions with
rationale and rejected alternatives. The ADRs in `adrs/` are
host-agnostic decisions that apply across implementations.
