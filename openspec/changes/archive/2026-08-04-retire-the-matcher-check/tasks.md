## 1. Move the declaration before deleting it

- [x] 1.1 Confirm `MATCHERS` has no reader: the axis that read it went with the
      conformance tool, and nothing writes registrations from it either
- [x] 1.2 Copy the three declared sets into the requirement as a table, verbatim
      in hook, event and matcher

## 2. Withdraw the mandate

- [x] 2.1 Remove the `Check` property, and state in its place what is no longer
      detected — including the five-repository `MultiEdit` defect as the evidence
      that the cost is real
- [x] 2.2 Reword the five scenarios that describe what a check reports into what
      is true of the project. Drop none of them: a scenario is a statement about
      the world, and losing one because its tool went away is how a capability
      quietly shrinks
- [x] 2.3 Place the condition on reinstatement — a check, inside an existing
      script, never a capability of its own

## 3. Close

- [x] 3.1 Delete `reference-implementations/project-hooks/MATCHERS`
- [x] 3.2 `openspec validate --all` green
- [x] 3.3 Both remaining suites pass, and `check-shims.sh` still exits 0
- [x] 3.4 Archive, and push onto the open PR rather than opening a second one
