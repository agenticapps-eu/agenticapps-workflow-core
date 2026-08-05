## 1. Settle the three open questions before writing anything

- [ ] 1.1 Decide whether a host identifier found inside the host-neutral section fails or warns, and record the reasoning in design.md
- [ ] 1.2 Decide whether the contract requires workflow files and tool-owned state to be separated inside a host directory, or whether reporting unrecognised state is sufficient
- [ ] 1.3 Decide whether the last agent leaving removes the shared section or leaves it in place; the specs currently say remove, so update them if that flips

## 2. Fix the source material before codifying it

- [ ] 2.1 Draft the host-neutral section body from the two cparx blocks, taking the union of what they agree on and dropping every host name
- [ ] 2.2 Remove the GSD references — both blocks cite a system deleted fleet-wide on 2026-07-28, so neither copy can be the basis for a new canonical text
- [ ] 2.3 Resolve the drifted step names (`gsd-execute-plan` versus `gsd-execute-phase`) against what the workflow actually does today, not against either copy
- [ ] 2.4 List the values that are genuinely host-specific and confirm the count against the four identified (binding repo, config path, skill invocation, prompt invocation)

## 3. Spec §12 — the single-section and host-directory requirements

- [ ] 3.1 Add the single-section requirement to `spec/12-authoring-conventions.md`, including that it holds regardless of agent count
- [ ] 3.2 Add the requirement that host-specific detail lives in the host's own directory, naming the four-value surface as the expected scope
- [ ] 3.3 Add the marker requirement: the section is locatable and removable by markers alone, with no dependence on heading text or ordering
- [ ] 3.4 State explicitly that `CLAUDE.md` is out of scope and that its lack of markers is not a violation
- [ ] 3.5 Choose the host-neutral marker name and record the legacy names it must recognise for detection
- [ ] 3.6 Bump the §12 `spec_version` and add the `CHANGELOG.md` entry

## 4. Conformance harness

- [ ] 4.1 Create `tools/agents-md-conformance.sh` following the existing `tools/*-conformance.sh` shape — one target, abort on an unusable target, never exit 0 having scored nothing
- [ ] 4.2 Score the single-section rule: exactly one workflow section present
- [ ] 4.3 Score duplicate detection against the legacy marker names, reporting every block found with its line range and never collapsing them
- [ ] 4.4 Score marker-only locatability: the section is found without reading any heading text
- [ ] 4.5 Score that removing the section leaves every byte outside the markers unchanged
- [ ] 4.6 Score the host-identifier check inside the section, at the severity decided in 1.1
- [ ] 4.7 Confirm `CLAUDE.md` is never scored by any row

## 5. Agent lifecycle rows

- [ ] 5.1 Score add-idempotency: provisioning twice produces one provision and one no-op, with all files byte-identical after the second
- [ ] 5.2 Score that adding a second agent leaves the shared file byte-identical
- [ ] 5.3 Score that removing one of several agents deletes only that agent's directory and leaves the shared file in place
- [ ] 5.4 Score removal of an absent agent: reports not-present, changes nothing
- [ ] 5.5 Score partial presence using the two real cparx shapes — a config with no skills, and a directory never committed — asserting removal reports what was missing rather than failing
- [ ] 5.6 Score that tool-owned state (`package.json`, `node_modules`) is reported and left in place, not deleted
- [ ] 5.7 Score both boundaries: first agent adds the section, last agent removes it per the 1.3 decision

## 6. Tests and verification

- [ ] 6.1 Write `tools/agents-md-conformance.test.sh` with a fixture per scored row, both directions pinned — a rule that rejects a valid layout is as bad as one that misses an invalid one
- [ ] 6.2 Build a fixture reproducing the cparx duplicate state from the two real blocks, and assert the harness reports both without collapsing
- [ ] 6.3 Run the suite under bash 3.2 with BSD sed and under bash 5 with GNU sed in a container, and record both totals
- [ ] 6.4 Run `shellcheck -S warning` over every new script and reach zero findings
- [ ] 6.5 Wire the harness into `.github/workflows/openspec-gate.yml` and confirm it runs against core itself

## 7. Close out

- [ ] 7.1 Run `openspec validate --all` green
- [ ] 7.2 Confirm no host repo was edited by this change
- [ ] 7.3 Record the installer prerequisite requirement (detect missing prerequisites, offer to install, user accepts first) in the Part-2 installer change so it is not lost with this one
- [ ] 7.4 Open the PR and archive the change
