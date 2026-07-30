# OpenSpec format templates (authoritative for this dry run)

Follow these EXACTLY. OpenSpec's `openspec validate --strict` requires: every
`### Requirement:` has at least one `#### Scenario:`; scenarios use WHEN/THEN
bullets; requirements use SHALL/MUST (RFC 2119).

## A. Consolidated capability spec — `openspec/specs/<capability>/spec.md`

```
# <capability> Specification

## Purpose
<1–2 paragraphs: what this capability is and why it exists. Durable truth only —
what the system DOES now, not how the work was sequenced.>

## Requirements

### Requirement: <Short Name>
The system SHALL <normative behavior>. <Optional clarifying sentence.>

#### Scenario: <short name>
- **WHEN** <triggering condition / input>
- **THEN** <observable expected outcome>
- **AND** <additional outcome, optional>

### Requirement: <next>
...
```

Rules:
- Requirements describe CURRENT capability, phrased normatively (SHALL/MUST).
- Merge across the source phases — one requirement may draw from several phases.
  Do NOT organize the spec by phase.
- Reference the governing ADR inline where one exists, e.g. `(ADR-0008)`.
- If a source phase is superseded/reverted, encode the CURRENT truth, not the history.
- Where the source planning docs don't give enough to state a requirement crisply,
  insert `> [GAP: <what a human must confirm>]` on its own line — do not invent.

## B. Archived change — `openspec/changes/archive/<YYYY-MM-DD>-<phase-slug>/`

Each source phase becomes one archived change folder with THREE files:

### proposal.md
```
# <Change title — imperative, from the phase goal>

## Why
<rationale distilled from the phase CONTEXT — the problem it solved>

## What Changes
- <bullet per material change the phase delivered>

## Impact
- Affected specs: <capability>
- Affected code: <areas/modules named in the SUMMARYs>
- Source phase: `.planning/phases/<dir>/`
- Status: archived (completed <date if known>)
```

### tasks.md
```
# Tasks

## 1. <group>
- [x] 1.1 <task, past-completed, from the phase PLAN/SUMMARY>
- [x] 1.2 <task>

## 2. <group>
- [x] 2.1 <task>
```
All boxes checked `[x]` — these are completed, archived changes.

### spec-delta.md
```
# Spec delta contributed by this change

## ADDED Requirements (capability: <capability>)
- <requirement name> — <one line>

## MODIFIED Requirements
- <name> — <what changed> (or "none")
```
This records which consolidated-spec requirements THIS phase contributed, so the
archive stays traceable to `specs/`.

Naming: `<YYYY-MM-DD>-<phase-dir-name>` e.g. `2026-04-20-03-llm-pipeline-api`.
Use the phase's ship date if the source states one, else its folder mtime date.

## C. Fidelity discipline
- Use ONLY content found in the staged planning files. No invention.
- Quote concrete identifiers (file names, ADR numbers, weights, REQ-IDs) where the
  sources give them — that is what makes the spec verifiable.
- Anything you cannot ground → `> [GAP: ...]`.
