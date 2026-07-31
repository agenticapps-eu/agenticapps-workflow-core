---
id: 18-retargeted-change-gate
section_type: declarative-contract
spec_version: 1.0.0
---

# 18 — Retargeted Change-Gate

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. The concrete hook mechanism, script
language, and file paths are at the host's discretion. The keywords
MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used per
[RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

**Introduced at spec v1.0.0.** This section retargets the 0.x
`PreToolUse` plan-review gate (the `multi-ai-review-gate.sh` mechanism,
host ADR-0018) from "a `*-PLAN.md` without a `*-REVIEWS.md`" to "an
active OpenSpec change without validation + review." A host citing
1.0.0 or later implements this gate. See ADR-0021.

## Concept

Stage 2 of the lifecycle (§17) is only real if something enforces it.
The **change-gate** is a `PreToolUse` hook (or host-equivalent
interposition point) that inspects each file-mutating tool call and
blocks it until the active change has both validated and been reviewed.
The gate reuses the *mechanism* proven by the 0.x plan-review gate — a
shell script invoked with a tool-call payload on stdin, signalling
block via exit code — and changes only *what it looks for*.

The contract below fixes the gate's **inputs and exit codes** so every
host implements identical behavior. It was validated end-to-end by the
2026-07-24 cParX pilot via direct invocation with simulated payloads.

## Requirements

### Interposition point

- **MUST** run at a `PreToolUse` interposition point (or host
  equivalent) that fires *before* a file-mutating tool call
  (edit / write / patch) is applied.
- The host's native runtime determines whether the gate can intercept
  the **running session's own** calls or only a subsequent session's.
  A `PreToolUse` hook cannot gate the session that installs it — the
  harness loads hooks at session start (an inherent property, not a
  defect). A host **MUST** wire the gate so a *fresh* session enforces
  it live, and **MUST** be able to demonstrate the gate by direct
  invocation with a simulated payload.

### Inputs

- **MUST** read the tool-call payload from stdin (the tool name and the
  target file path, in the host runtime's payload shape).
- **MUST** determine the **active change** — the open change directory
  under `changes/` (excluding `archive/`) that the edit belongs to.
- **MUST** resolve two facts about the active change: whether
  `openspec validate --all` passes, and how many independent reviewers
  the change's `REVIEWS.md` carries (counted, per the pilot, as
  `## Reviewer:` headings or host-equivalent reviewer markers).

### Decision (exit codes)

The gate signals its decision through the process exit code. `0` =
allow; `2` = block (host-equivalent non-zero "deny" code). The complete
truth table is normative:

| Situation | Decision | Exit |
|---|---|---|
| No active change (edit outside any open change) | **allow** | `0` |
| The edit targets an OpenSpec artifact (`openspec/**` — proposal, design, delta, tasks) | **allow (exempt)** | `0` |
| Active change, `validate` green, **no** `REVIEWS.md` (zero reviewers) | **block** | `2` |
| Active change, `validate` **fails** | **block** | `2` |
| Active change, `validate` green **and** `REVIEWS.md` ≥ 1 counted reviewer | **allow** | `0` |
| …with exactly 1 counted reviewer (below the preferred 2) | **allow + report** | `0` |
| Reviewer section with no verdict line | **not counted** | — |
| Reviewer section with a verdict but no body | **not counted** | — |
| Reviewer section with two conflicting verdicts | **not counted (malformed)** | — |
| Section naming the declared implementing host | **not counted (excluded)** | — |
| `REVIEWS.md` with no trailer, or a malformed one | **block (zero counted)** | `2` |
| Trailer digest no longer matches the change artifacts | **block (stale)** | `2` |
| Counted reviewer(s) present, some carrying REQUEST-CHANGES | **allow + report** | `0` |
| Documented escape hatch env var set (e.g. `GSD_SKIP_REVIEWS=1`) | **allow (override)** | `0` |
| Malformed / unparseable stdin | **allow (fail-open)** | `0` |

- **MUST** enforce **both** clauses to allow a code edit under an active
  change: `openspec validate --all` passes **and** `REVIEWS.md` carries
  **at least one counted** independent reviewer. Either alone is a block.

- **MUST** count a reviewer section only when it carries **a verdict and a
  body**. The verdict vocabulary is closed — `APPROVE` | `REQUEST-CHANGES` —
  matched case-insensitively and anchored at both ends of the line after
  markdown emphasis is normalised away; fenced code blocks are skipped, so a
  document quoting the convention does not satisfy it. A section runs from its
  `## Reviewer:` heading to the next heading of **level 1 or 2**, so a vendor's
  own `### Findings` subheading does not truncate it.

  A verdict alone is not a review, and a body alone is not a verdict. Both
  halves were observed counting in production: a bare `VERDICT: APPROVE` with
  no body on 2026-07-29T07:52:54Z, and a verdictless preamble in the same
  week's reviews.

  **This term is why a gate may act on verdicts at all.** The reference gate's
  own source records that "§18's truth table has no verdict term, so a gate
  that blocked on this would be non-conformant" — correct against the previous
  text. The spec moves first; the gate follows.

- **MUST** record the implementing host in `REVIEWS.md` and exclude that
  host's own sections from the count. The identity is read from the artifact,
  not from the evaluating process's environment: CI, a pre-commit hook, or a
  different agent routinely evaluates evidence some other host produced, so an
  environment-derived identity describes the wrong party. A missing or
  unrecognised identity counts **zero** reviewers.

  Independence here means **a different CLI, not a different model**. A client
  may route to the same provider and model as the implementing host, in which
  case two counted reviewers are one model answering twice. Hosts and reviewer
  vendors are also different sets — a host may have no reviewer arm — so the
  recorded identity is drawn from the union of both.

- **MUST** bind a review to the artifacts reviewed, by a digest recorded in
  `REVIEWS.md`, and **MUST NOT** count a review whose digest no longer matches.
  Without this, amending a change after review silently retains evidence for
  text nobody read.

  The digest is **drift detection, not authenticity**: it is computable by
  anyone holding the same artifacts, so it does not resist a forged
  `REVIEWS.md`, and no requirement here may be read as claiming it does.
- **SHOULD** carry **two or more** independent reviewers. Two remains the
  target, and a host **MUST** report when a change is proceeding on one —
  the difference between "reviewed by one" and "reviewed by two" must not
  be invisible at the moment it is being relied on.
- **MUST NOT** block on the count between the floor and the preference. A
  single reviewer is a reportable condition, not a failure.

  **Why the floor moved from two to one (spec 1.1.0).** The original ≥2 came
  from ADR-0018's independence property, and the evidence for it is real:
  across three reviewed changes in the 2026-07-28 fleet migration, the single
  most consequential finding was *unique to one vendor every time* and not
  predictable in advance — on one change the three reviewers' top findings had
  zero overlap, and the one that mattered (a factually false premise, verified
  against git history) came from the reviewer a smaller quorum might not have
  run.

  That argues two reviewers are **better**, which is why it stays a SHOULD. It
  does not argue that one reviewer is worse than *none*, which is what a hard
  ≥2 floor effectively enforced whenever a vendor was slow, rate-limited or
  down. Blocking all work because the second of two opinions timed out trades a
  large, certain cost against a small, uncertain one. The floor now sits where
  the guarantee is real — no code without at least one independent opinion —
  and the preference is carried by reporting rather than by refusal.
- **MUST** exempt writes to the OpenSpec artifacts themselves — the
  agent has to be able to *author* the change (proposal, design, delta,
  tasks) and its `REVIEWS.md` while the gate is engaged.
- **MUST** adopt the "no active change → allow" posture: the gate
  engages only once a change is open, mirroring §02's out-of-phase
  permissiveness. A stricter "no code edits outside a change at all"
  posture is a permitted host extension (§09) but is not required and
  was judged too aggressive for a prototype.
- **MUST** **fail open** on malformed input: a gate that crashes on
  garbage stdin MUST exit `0`, never silently disabling itself by
  erroring in a way the runtime treats as a block or a pass-through it
  did not intend. Failing open on *parse error* is deliberate; failing
  open on *policy* (missing review) is non-conformant.
- **MUST** provide a documented escape hatch (an env var) so a
  deliberate, logged override is possible; an undocumented bypass is
  non-conformant.

### Reviewer-CLI robustness

- **SHOULD** invoke external reviewer CLIs defensively. The pilot found
  `codex exec "<prompt>"` reads stdin and hangs without `</dev/null`
  (a 4-minute timeout on first attempt); a reviewer CLI that hangs must
  not be able to stall an edit indefinitely. Wrap reviewer invocations
  with a stdin redirect and a timeout.

### Enforcement surface

- **MUST** make the host-agnostic **shell script** the real enforcement
  surface — it is directly testable with simulated payloads. Any
  host-runtime wiring (a Claude `settings.json` block, a
  `.codex/hooks.json`) is the mechanism that *invokes* the script; where
  a host's hooks-file schema is unverified, the host flags it and relies
  on the script as the source of truth.

## Scenarios

#### Scenario: block before review

- **GIVEN** an active change with `openspec validate --all` green and no
  `REVIEWS.md`
- **WHEN** the gate receives an `Edit classify.go` payload on stdin
- **THEN** it exits `2` (block) with a message naming the missing
  REVIEWS.md and the one-reviewer floor.

#### Scenario: allow after review

- **GIVEN** the same change now carrying `REVIEWS.md` with two
  independent reviewers and still validating green
- **WHEN** the gate receives the same `Edit classify.go` payload
- **THEN** it exits `0` (allow).

#### Scenario: author the change while gated

- **GIVEN** an active change with no `REVIEWS.md` yet
- **WHEN** the gate receives a `Write openspec/changes/<slug>/proposal.md`
  payload
- **THEN** it exits `0` (exempt) so the agent can author the change.

#### Scenario: fail open on garbage

- **GIVEN** the gate receives unparseable stdin
- **WHEN** it cannot extract a tool name or path
- **THEN** it exits `0` (fail-open) rather than crashing into a block.

## Conformance

A host implementation:

- **MUST** ship a `PreToolUse` (or equivalent) change-gate implementing
  the exit-code truth table above, enforcing validate-green **and**
  `REVIEWS.md` ≥ 1 counted reviewer for edits under an active change.
- **MUST** exempt OpenSpec-artifact writes, provide a documented escape
  hatch, and fail open on malformed input.
- **MUST** be demonstrable by direct script invocation with simulated
  payloads, and wire the gate so a fresh session enforces it live.
- **SHOULD** wrap reviewer-CLI invocations against stdin-hang and add a
  timeout.
- **MAY** log the decision (`ALLOW` / `BLOCK`) alongside the tool name
  so one log line becomes end-to-end evidence (a standing follow-up from
  the fleet's HOOK-01 work).
