---
id: 18-retargeted-change-gate
section_type: declarative-contract
spec_version: 1.5.0
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

**Amended at spec v1.5.0.** Review state is **reported, never enforced**:
the gate blocks on a red `openspec validate --all` (or an unavailable
`openspec` CLI) and on nothing else. The reviewer floor of one and the
preference of two survive as reported thresholds, every counting rule is
retained unchanged, and a host that wants to block on review state
declares it as a documented §09 extension. Minor rather than major
because of that extension: a host still blocking becomes a declaring
host, not a non-conformant one.

## Concept

The **change-gate** is a `PreToolUse` hook (or host-equivalent
interposition point) that inspects each file-mutating tool call and
blocks it until the active change validates. It reuses the *mechanism*
proven by the 0.x plan-review gate — a shell script invoked with a
tool-call payload on stdin, signalling block via exit code — and changes
only *what it looks for*.

**The gate blocks on validation, and reports on review.** Those are two
different kinds of fact, and 1.5.0 stopped treating them as one. A spec
delta that does not parse is an **error**: wrong on its own terms,
answerable locally, instantly and deterministically, with no network and
no third-party CLI in the path. A missing review is an **absence** — the
change is not more broken for it, and the person best placed to judge
whether that matters is the one being interrupted.

Stage 2 of the lifecycle (§17) is therefore enforced in one half and
reported in the other. Review state — absent, short of the preference,
unverifiable, stale, or carrying an objection — is surfaced on every
invocation where the gate applies, and none of it stops an edit.

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
| Active change, `validate` green, **no** `REVIEWS.md` (zero reviewers) | **allow + report** | `0` |
| Active change, `validate` **fails** | **block** | `2` |
| Active change, the `openspec` CLI is unavailable, so `validate` cannot be answered | **block** | `2` |
| Active change, `validate` green **and** `REVIEWS.md` ≥ 1 counted reviewer | **allow** | `0` |
| …with exactly 1 counted reviewer (below the preferred 2) | **allow + report** | `0` |
| Reviewer section with no verdict line | **not counted** | — |
| Reviewer section with a verdict but no body | **not counted** | — |
| Reviewer section with two conflicting verdicts | **not counted (malformed)** | — |
| Section naming the declared implementing host | **not counted (excluded)** | — |
| `REVIEWS.md` with no trailer, or a malformed one | **allow + report (zero counted)** | `0` |
| Trailer digest no longer matches the change artifacts | **allow + report (stale)** | `0` |
| Counted reviewer(s) present, some carrying REQUEST-CHANGES | **allow + report** | `0` |
| Documented escape hatch env var set (e.g. `GSD_SKIP_REVIEWS=1`) | **suppresses the review reports; does not affect the `validate` block** | — |
| Malformed / unparseable stdin | **allow (fail-open)** | `0` |

- **MUST** block a code edit under an active change on exactly one
  condition: `openspec validate --all` does not pass — including the case
  where the `openspec` CLI is unavailable, so the question cannot be
  answered. **MUST NOT** block on the state of `REVIEWS.md` in any of its
  forms: absent, below the floor, below the preference, untrailered,
  malformed, stale, or carrying an unresolved objection.

  **Why the enforcement was withdrawn (spec 1.5.0).** Measured on the core
  repository, blocking on review state cost three rollbacks, a
  six-repository outage on 2026-07-30, and a migration whose stated
  precondition was announcing that outage in advance. What it prevented is
  not identifiable. Reviewers are third-party CLIs that are variously slow,
  rate-limited and prone to returning nothing, so the floor went unmet
  routinely for reasons bearing no relationship to the quality of the
  change — the block landed almost exclusively on the wrong cases.

  What is removed is the **consequence**, not the arithmetic. Every counting
  rule below is retained verbatim and becomes a reporting obligation: a gate
  that reports must count as accurately as one that blocked, because "0
  reviewers" printed over two real reviews is just as wrong when it is
  advisory.

- A host **MAY** block on review state as a **declared, documented
  extension** (§09), and **MUST** document it where the host's other gate
  behaviour is documented if it does. This is the same permitted-extension
  shape as the stricter "no code edits outside a change at all" posture
  below. The default is reporting; a host that wants the old floor back
  states so rather than diverging silently.

- **MUST** count a reviewer section only when it carries **a verdict and a
  body**. The verdict vocabulary is closed — `APPROVE` | `REQUEST-CHANGES` —
  matched case-insensitively and anchored at both ends of the line after
  markdown emphasis is normalised away; fenced code blocks are skipped, so a
  document quoting the convention does not satisfy it. A section runs from its
  `## Reviewer:` heading to the **next `## Reviewer:` heading**, or to end of
  file; no other heading closes it at any level, so neither a vendor's own
  `### Findings` subheading nor the `## Summary` an LLM commonly writes above
  its verdict truncates the section.

  A verdict alone is not a review, and a body alone is not a verdict. Both
  halves were observed counting in production: a bare `VERDICT: APPROVE` with
  no body on 2026-07-29T07:52:54Z, and a verdictless preamble in the same
  week's reviews.

  **This term is why a gate may act on verdicts at all.** The reference gate's
  own source records that "§18's truth table has no verdict term, so a gate
  that blocked on this would be non-conformant" — correct against the text as
  it stood before the term was added. The spec moves first; the gate follows.

  Acting on a verdict now means **naming it**, not refusing on it. The table
  above allows an edit over an unresolved REQUEST-CHANGES and requires the
  objection be reported; promoting a verdict to blocking would need a
  re-review trigger, a staleness rule for an edited proposal, and an override
  path, none of which this section defines.

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
- **MUST NOT** block on the count at any point on it — not between the floor
  and the preference, and not below the floor. A single reviewer is a
  reportable condition; since 1.5.0 so is none. The floor of one is what the
  gate counts and reports **against**, not a threshold it withholds work on.

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
  large, certain cost against a small, uncertain one.

  1.1.0 moved the floor and kept it enforced; **1.5.0 stopped enforcing the
  count altogether**, for the same argument carried one step further. If
  blocking on the *second* opinion cost more than it caught, blocking on the
  *first* did too — measured on the same repository, by the same reviewers,
  failing for the same reasons. Both the floor and the preference are now
  carried by reporting rather than by refusal, and the paragraphs above stand
  as the reason the floor is worth *reporting against* accurately.
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
  open on a red `validate` is non-conformant.

  Before 1.5.0 this clause read "failing open on *policy* (missing review) is
  non-conformant." Allowing on a missing review is now the policy, so the
  clause names the one condition that must still fail closed.
- **MUST** provide a documented escape hatch (an env var) for whatever the
  host blocks on; an undocumented bypass is non-conformant. Where the only
  blocking condition is a red `validate`, a host **MAY** retain a
  review-oriented hatch as a no-op accepted for compatibility — the reference
  gate keeps `GSD_SKIP_REVIEWS` for exactly that reason, where it now
  suppresses the review reports and nothing else. A hatch **MUST NOT** be
  documented as bypassing validation when it does not, and a host that adopts
  the MAY-extension above **MUST** state which hatch releases it.

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

#### Scenario: report before review

- **GIVEN** an active change with `openspec validate --all` green and no
  `REVIEWS.md`
- **WHEN** the gate receives an `Edit classify.go` payload on stdin
- **THEN** it exits `0` (allow) and reports that no plan review has been
  run, naming the missing `REVIEWS.md`.

  Through spec 1.4.0 this scenario was titled "block before review" and
  required exit `2`. It is the row 1.5.0 inverted.

#### Scenario: block on a red validate

- **GIVEN** an active change whose `openspec validate --all` fails,
  whatever its review state
- **WHEN** the gate receives the same `Edit classify.go` payload
- **THEN** it exits `2` (block), naming the validation failure.

#### Scenario: allow after review

- **GIVEN** the same change now carrying `REVIEWS.md` with two
  independent reviewers and still validating green
- **WHEN** the gate receives the same `Edit classify.go` payload
- **THEN** it exits `0` (allow), with no review report to make.

#### Scenario: a stale review is distinguished from no review

- **GIVEN** an active change whose artifacts have changed since
  `REVIEWS.md` was written
- **WHEN** the gate receives the same `Edit classify.go` payload
- **THEN** it exits `0` (allow) and reports the review as no longer
  describing the current text — distinguishably from a change that was
  never reviewed. Both allowed, and not the same fact.

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
  the exit-code truth table above: enforcing validate-green for edits
  under an active change, and **counting and reporting** `REVIEWS.md`
  state without blocking on it.
- **MUST** exempt OpenSpec-artifact writes, provide a documented escape
  hatch, and fail open on malformed input.
- **MUST** declare and document a block-on-review-state posture if it
  adopts one. Blocking without declaring it is the divergence this
  section exists to prevent, in whichever direction it runs.
- **MUST** be demonstrable by direct script invocation with simulated
  payloads, and wire the gate so a fresh session enforces it live.
- **SHOULD** wrap reviewer-CLI invocations against stdin-hang and add a
  timeout.
- **MAY** log the decision (`ALLOW` / `BLOCK`) alongside the tool name
  so one log line becomes end-to-end evidence (a standing follow-up from
  the fleet's HOOK-01 work).
