---
id: 06-evidence-rules
section_type: declarative-contract
spec_version: 0.1.0
---

# 06 — Evidence Rules (Verification Before Completion)

**Section type**: declarative contract. Host implementations MUST
satisfy the requirements below. Prose, formatting, file paths, and
artifact locations are at the host's discretion. The keywords MUST,
MUST NOT, SHOULD, SHOULD NOT, and MAY are used per [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Concept

Verification before completion is the spec's enforcement against the
single most common LLM failure mode in agentic workflows: claiming a
task is done without producing evidence that it is. The evidence
contract makes "done" provable from on-disk artifacts.

This contract pairs with the `verification` gate in section 02.

## Requirements

### Evidence per `must_have`

- **MUST** verify each `must_have` row in VERIFICATION.md (or
  host-equivalent verification document) with at least one piece of
  on-disk evidence before marking the corresponding task complete.
- **MUST NOT** mark a task complete on the basis of unaudited
  assertions, including but not limited to: "manually verified",
  "tested locally", "should work", "trust me", "looks good".
- **SHOULD** record the evidence inline in the verification document
  (file path, command output snippet, line numbers) rather than as
  a free-text claim.

### Permitted evidence shapes

The following evidence shapes satisfy the contract:

| Shape | Required content |
|---|---|
| **Test output** | The command run (e.g. `pytest tests/test_auth.py`), the test name(s), and the RED/GREEN status. For TDD tasks, both the RED commit hash and the GREEN commit hash MUST be linked. |
| **Grep result** | The grep command (with file path scope) and the matching line(s) with line numbers. |
| **Curl response** | The full curl command (URL, method, headers minus secrets) and the HTTP status + relevant response body fields. |
| **Screenshot path** | The screenshot file path, the browser used, the URL navigated to, and a one-line description of what the screenshot demonstrates. |
| **File existence** | A `test -f`, `ls`, or equivalent command output proving the artifact at the asserted path. |
| **Diff snippet** | A `git diff` or equivalent output showing the asserted code change, with file paths and line numbers. |

Hosts MAY define additional shapes for host-specific evidence types
(e.g. database query output for SQL-touching tasks). New shapes MUST
specify the required content fields.

### Forbidden patterns

The following are non-conformant when used as the sole evidence for a
`must_have`:

- "Manually verified."
- "Tested locally."
- "Should work."
- "Looks good."
- "Trust me."
- "I checked."
- An assertion of completion without any of the permitted shapes
  above.

A host implementation that allows a task to be marked complete on the
sole basis of a forbidden pattern is non-conformant.

### Evidence-to-`must_have` correspondence

- **MUST** maintain 1:1 (or 1:N) correspondence: every `must_have`
  row has at least one Evidence subrow. A `must_have` with zero
  evidence rows is a verification failure.
- **MUST NOT** consolidate evidence across multiple `must_have` rows
  into a single "all verified" assertion at the bottom of the
  document. Each `must_have` is verified separately.
- **MAY** reference the same evidence artifact from multiple
  `must_have` rows when a single artifact genuinely satisfies more
  than one (e.g. one screenshot demonstrates two distinct UI
  behaviors).

### Forbidden anti-patterns

- "Tests will be added later." — non-conformant. If the spec required
  TDD for the task (see section 02 `tdd` gate), the absence of the
  RED → GREEN commit pair is an automatic verification failure.
- "Verification skipped because the task was trivial." —
  non-conformant. Trivial tasks have trivial evidence (a one-line
  grep result), not zero evidence.
- "Verification deferred to phase review." — non-conformant.
  Per-task verification fires per task. Phase review is a separate
  control point.

## Conformance

A host implementation:

- **MUST** require at least one piece of permitted-shape evidence
  before any task transitions to a "complete" state.
- **MUST** maintain a verification document (e.g. VERIFICATION.md)
  per phase that lists `must_have` rows and their evidence rows.
- **SHOULD** wire the `verification` gate to a runtime mechanism
  (subagent, hook, plugin) that refuses task completion when
  evidence is absent.
- **MAY** require additional evidence shapes for host-specific
  concerns (e.g. accessibility audit output for UI-shipping hosts).
