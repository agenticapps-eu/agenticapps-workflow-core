---
id: 09-conformance
section_type: framing
spec_version: 0.10.0
---

# 09 — Conformance

**Section type**: framing. This section describes how a host
implementation claims conformance with the AgenticApps workflow spec
at version 0.10.0. The keywords MUST, MUST NOT, SHOULD, SHOULD NOT, and
MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Conformance levels

A host claims one of three levels in
`reference-implementations/README.md`:

- **`full`** — every canonical-prose block is reproduced verbatim,
  every declarative-contract MUST is satisfied, and host-specific
  bindings exist for every gate whose trigger condition can occur in
  the host's project type.
- **`partial`** — most requirements are satisfied; deltas are listed
  in the host's own host-instruction file under a "Spec deltas"
  section that names each unsatisfied requirement and the rationale
  (e.g. "the `database-security` gate has no binding because pi
  projects ship without a database in the default scaffold").
- **`consumer-only`** — the host reads workflow artifacts produced
  by another host but does not author them itself. Consumer-only
  hosts (e.g. an artifact viewer or dashboard) satisfy a reduced
  contract: they MUST understand the artifact shapes (CONTEXT.md,
  PLAN.md, VERIFICATION.md, REVIEW.md, SECURITY.md) at the
  semantic level needed for their use case. They MAY ignore gates
  and authoring requirements.

## Required behaviors per level

### `full`

A host claiming `full` conformance MUST:

1. **Reproduce canonical-prose blocks verbatim.** Sections 01, 03,
   04, 05, 11 each define a canonical block. The block, including
   its heading, MUST appear in the host's instruction file (e.g.
   `SKILL.md` or equivalent) with the listed wording. Substitution
   inside `{{...}}` placeholders is permitted; alteration of the
   surrounding prose is non-conformant.
2. **Satisfy every declarative MUST.** Sections 02, 06, 07, 08, 10,
   12, 13, 14, 15 list declarative requirements. Each is honored by
   some host mechanism — a skill binding, a runtime extension, a CI
   job, a reviewer agent. The mechanism is at the host's discretion;
   the honoring is required. Section 13 applies only to hosts
   targeting TypeScript projects; non-TS-targeting hosts MAY omit it
   with a spec delta per the rules below. Section 14 applies only to
   hosts whose projects build LLM prompts from non-self-authored
   values; a host with no LLM prompt-building surface is trivially
   conformant and says so with a spec delta. Section 15 is wired per
   host but activated per repo: the host MUST ship the trigger wiring
   and skip behavior; a repo without the §15.2 config block is
   skipped silently and remains conformant, no delta required.
3. **Bind every applicable gate.** Section 02 enumerates 16 gates.
   For each gate whose trigger condition can occur in the host's
   project type, the host MUST document the bound skill (or
   plugin, or tool) in a single host-side hook-bindings table.
4. **Cite the spec version.** The host's primary instruction file
   MUST include the line `implements_spec: <version>` in its
   frontmatter (or host-equivalent metadata block), where
   `<version>` is the spec version the host claims (e.g. `0.1.0`,
   `0.2.0`, `0.3.0`, `0.4.0`, `0.5.0`, `0.6.0`, `0.7.0`, `0.8.0`,
   `0.9.0`, `0.9.1`, `0.10.0`).
5. **Maintain artifact shapes.** Phases produce CONTEXT.md, PLAN.md,
   VERIFICATION.md, REVIEW.md (with Stage 1 and Stage 2 sections),
   and SECURITY.md when applicable. The artifacts are
   machine-discoverable by name and well-formed.

### `partial`

A host claiming `partial` conformance MUST:

1. Satisfy items 1, 4, and 5 from the `full` list above.
2. Document every unsatisfied declarative MUST and every unbound
   applicable gate in a "Spec deltas" section of the host's
   instruction file.
3. Not silently drop a canonical-prose block. If a block cannot
   appear verbatim for host-specific reasons, the host's "Spec
   deltas" section MUST name the block and the rationale.

### `consumer-only`

A host claiming `consumer-only` conformance MUST:

1. Cite the spec version of the artifacts it consumes.
2. Document the artifact shapes its UX or behavior depends on.
3. Not assert authorship of any of the gates from section 02.
   (A consumer that authors gates is no longer consumer-only.)

## Knowledge-capture checks (§15)

A conformance review of a host claiming 0.7.0 applies three checks
for §15; a consumer-only host has no ritual surface and skips all
three.

1. **Trigger wiring present in the host's ritual instructions.** The
   host's SKILL.md (or equivalent) names the knowledge-capture write
   as the final step of each of the three §15.1 rituals — session
   handoff, plan completion, phase completion — after the ritual's
   own artifact is committed.
2. **Config block honored, path not hardcoded.** Repos opting in
   carry the `knowledge_capture` block in `.planning/config.json` per
   §15.2, and the host resolves the note path exclusively from that
   block. A vault path literal inside host skill logic (checkable by
   grep over the host repo) is non-conformant.
3. **Graceful-skip behavior.** With the block absent, `enabled:
   false`, or the note's parent folder missing, each ritual completes
   normally with at most one informational line — no error, no
   created folders, no empty note.

## Allowed extensions

A host MAY:

- Define additional gates beyond the 16 in section 02 (host-specific
  concerns).
- Add rows to the rationalization table (section 03) and red-flag
  list (section 04) for host-specific failure modes.
- Layer a runtime enforcement mechanism (subagent, plugin, hook
  daemon) over the canonical text. This is encouraged for hosts
  that can support it; it does not replace the canonical text.
- Ship additional review stages beyond the canonical Stage 1 / Stage
  2 (section 07) so long as the canonical pair remains distinct
  and independent.

## Citation format

A host implementation cites its spec version in the frontmatter of
its primary instruction file:

```yaml
---
name: <host-workflow-skill-name>
version: <host-version>
implements_spec: 0.10.0
description: |
  ...
---
```

The `implements_spec` field is the contract. A host that ships an
instruction file without this field is unversioned and cannot claim
any conformance level.

## Drift

`tools/drift-report.sh` in this repo is an advisory check that
compares canonical-block presence across known host clones. It does
not gate conformance at v0.1.0. Stricter enforcement (per-host CI
that fetches the spec at the cited version and asserts canonical
presence) is reserved for a later spec version.

## Updating between versions

When this spec ships a new version, each host implementation reviews
the CHANGELOG entry. The entry names the conformance impact:

- **Patch** (0.1.x) — typo or clarification rewording. Hosts at the
  prior patch level remain conformant; updating is optional.
- **Minor** (0.x.0) — additive: new declarative requirement, new
  optional gate. Hosts at the prior minor remain conformant for the
  prior minor's claims; updating to claim the new minor requires
  satisfying the additive requirement.
- **Major** (X.0.0) — breaking: canonical block reworded, gate
  removed, evidence rules tightened. Hosts MUST update their
  implementations to claim the new major; prior major's
  conformance claim becomes obsolete.

The host's `implements_spec` field always names the version against
which the host's claim is asserted.
