## 1. Decisions taken — carry these, do not re-litigate

- [x] 1.1 A host identifier inside the host-neutral section WARNS, it does not fail. The per-agent links are exempt, since they are host-specific by design
- [x] 1.2 A link per installed agent is the ONLY host-specific content permitted in `AGENTS.md`. The subdirectory-separation question was redirected rather than answered, so the existing decision stands: tool-owned state is reported, not deleted
- [x] 1.3 The host-neutral section is NOT removed when the last agent leaves. Only the departing agent's link goes

## 2. Fix the source material before codifying it

- [ ] 2.1 Draft the host-neutral section body from the two cparx blocks, taking the union of what they agree on and dropping every host name
- [ ] 2.2 Remove the GSD references — both blocks cite a system deleted fleet-wide on 2026-07-28, so neither copy can be the basis for a new canonical text
- [ ] 2.3 Resolve the drifted step names (`gsd-execute-plan` versus `gsd-execute-phase`) against what the workflow actually does today, not against either copy
- [ ] 2.4 List the values that are genuinely host-specific and confirm the count against the four identified (binding repo, config path, skill invocation, prompt invocation)
- [ ] 2.5 Settle the link's shape — markdown link under a fixed heading, marker-delimited link block, or frontmatter list — choosing on how cheaply exactly one entry can be added and removed without reflowing its neighbours
- [ ] 2.6 Draft the per-host file that each link points at, using the four values from 2.4 as its whole content

## 3. Spec §12 — the single-section and host-directory requirements

- [ ] 3.1 Add the single-section requirement to `spec/12-authoring-conventions.md`, including that it holds regardless of agent count
- [ ] 3.2 Add the requirement that host-specific detail lives in the host's own directory, naming the four-value surface as the expected scope
- [ ] 3.3 Add the requirement that a per-agent link is the only host-specific content permitted in the shared file, in the shape settled by 2.5
- [ ] 3.4 State that the host-neutral section is written at first-agent and never removed
- [ ] 3.5 Add the marker requirement: the section is locatable and removable by markers alone, with no dependence on heading text or ordering
- [ ] 3.6 State explicitly that `CLAUDE.md` is out of scope and that its lack of markers is not a violation
- [ ] 3.7 Choose the host-neutral marker name and record the legacy names it must recognise for detection
- [ ] 3.8 Bump the §12 `spec_version` and add the `CHANGELOG.md` entry

## 4. Conformance harness

- [ ] 4.1 Create `tools/agents-md-conformance.sh` following the existing `tools/*-conformance.sh` shape — one target, abort on an unusable target, never exit 0 having scored nothing
- [ ] 4.2 Score the single-section rule: exactly one workflow section present
- [ ] 4.3 Score duplicate detection against the legacy marker names, reporting every block found with its line range and never collapsing them
- [ ] 4.4 Score marker-only locatability: the section is found without reading any heading text
- [ ] 4.5 Score that removing the section leaves every byte outside the markers unchanged
- [ ] 4.6 Score the host-identifier check inside the section at WARNING severity, and assert it does not fail the run
- [ ] 4.7 Assert the per-agent links are exempt from 4.6 — a link containing a host name must produce no warning, or the check fires on the one thing the spec permits
- [ ] 4.8 Score that a per-agent link is the only host-specific content in the file, and that any other host-specific content is a violation
- [ ] 4.9 Confirm `CLAUDE.md` is never scored by any row

## 5. Agent lifecycle rows

- [ ] 5.1 Score add-idempotency: provisioning twice produces one provision and one no-op, with all files byte-identical after the second
- [ ] 5.2 Score that adding a second agent adds ONLY its link — the host-neutral section byte-identical, the first agent's link untouched
- [ ] 5.3 Score that removing one of several agents deletes only that agent's directory and only that agent's link, leaving the section and every other link unchanged
- [ ] 5.4 Score removal of an absent agent: reports not-present, changes nothing
- [ ] 5.5 Score partial presence using the two real cparx shapes — a config with no skills, and a directory never committed — asserting removal reports what was missing rather than failing
- [ ] 5.6 Score that tool-owned state (`package.json`, `node_modules`) is reported and left in place, not deleted
- [ ] 5.7 Score the first-agent boundary: the section and the agent's link are both added
- [ ] 5.8 Score the last-agent boundary: the link is removed and the host-neutral section SURVIVES, per 1.3
- [ ] 5.9 Score re-adding an agent to a repo that has the section but no agents: only the link is added, section byte-identical

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
