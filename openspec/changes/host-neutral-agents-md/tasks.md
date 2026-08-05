## 1. Decisions taken — carry these, do not re-litigate

- [x] 1.1 A host identifier inside the host-neutral section WARNS, it does not fail. The per-agent links are exempt, since they are host-specific by design
- [x] 1.2 A link per installed agent is the ONLY host-specific content permitted in `AGENTS.md`. The subdirectory-separation question was redirected rather than answered, so the existing decision stands: tool-owned state is reported, not deleted
- [x] 1.3 The host-neutral section is NOT removed when the last agent leaves. Only the departing agent's link goes

## 2. Fix the source material before codifying it

- [x] 2.1 Draft the host-neutral section body from the two cparx blocks, taking the union of what they agree on and dropping every host name — drafted in `drafts.md` from the three *live* templates instead, since the cparx blocks were deleted by cparx PR #125 and the templates are what a fresh install lays down today
- [x] 2.2 Remove the GSD references — both blocks cite a system deleted fleet-wide on 2026-07-28, so neither copy can be the basis for a new canonical text — done; only codex still cites GSD, and a *second* stale claim was found in pi (the gate "enforces" ≥2 reviewers; false since gate 2.0.0)
- [x] 2.3 Resolve the drifted step names (`gsd-execute-plan` versus `gsd-execute-phase`) against what the workflow actually does today, not against either copy — neither survives; the step is now `apply`, and its invocation is host-specific by 2.4
- [x] 2.4 List the values that are genuinely host-specific and confirm the count against the four identified (binding repo, config path, skill invocation, prompt invocation) — count holds at four, membership does not: host directory, binding repo, invocation syntax, trigger-skill install root
- [x] 2.5 Settle the link's shape — markdown link under a fixed heading, marker-delimited link block, or frontmatter list — choosing on how cheaply exactly one entry can be added and removed without reflowing its neighbours — **frontmatter list (Donald)**, entries carrying paths not bare ids, so the entry stays a pointer rather than becoming a manifest
- [x] 2.6 Draft the per-host file that each link points at, using the four values from 2.4 as its whole content — drafted; six values written out, four of them load-bearing for the contract

## 3. Spec §12 — the single-section and host-directory requirements

- [x] 3.1 Add the single-section requirement to `spec/12-authoring-conventions.md`, including that it holds regardless of agent count
- [x] 3.2 Add the requirement that host-specific detail lives in the host's own directory, naming the four-value surface as the expected scope
- [x] 3.3 Add the requirement that a per-agent link is the only host-specific content permitted in the shared file, in the shape settled by 2.5
- [x] 3.4 State that the host-neutral section is written at first-agent and never removed
- [x] 3.5 Add the marker requirement: the section is locatable and removable by markers alone, with no dependence on heading text or ordering
- [x] 3.6 State explicitly that `CLAUDE.md` is out of scope and that its lack of markers is not a violation
- [x] 3.7 Choose the host-neutral marker name and record the legacy names it must recognise for detection — **no rename**: all three live templates already write `agentic-apps-workflow sections`, and the legacy project-file list is empty. `BEGIN: opencode-workflow sections` was a design-doc artefact, not a real marker. The requirement became behavioural — check before appending — since a shared name is the cause, not the cure
- [x] 3.8 Bump the §12 `spec_version` and add the `CHANGELOG.md` entry — 0.10.0 → 0.11.0

## 4. Conformance harness

- [x] 4.1 Create `tools/agents-md-conformance.sh` following the existing `tools/*-conformance.sh` shape — one target, abort on an unusable target, never exit 0 having scored nothing
- [x] 4.2 Score the single-section rule: exactly one workflow section present
- [x] 4.3 Score duplicate detection against the legacy marker names, reporting every block found with its line range and never collapsing them — the legacy project-file list is empty (see 3.7); the recognised-but-foreign global-file markers are scored as a distinct finding instead
- [x] 4.4 Score marker-only locatability: the section is found without reading any heading text — asserted by re-locating in a copy with every heading blanked
- [x] 4.5 Score that removing the section leaves every byte outside the markers unchanged
- [x] 4.6 Score the host-identifier check inside the section at WARNING severity, and assert it does not fail the run — the attribution row must isolate warnings from legitimate path failures; comparing the raw fail count made it fire on the case it exists to exonerate
- [x] 4.7 Assert the per-agent links are exempt from 4.6 — a link containing a host name must produce no warning, or the check fires on the one thing the spec permits — holds structurally: frontmatter and the marker-delimited body are disjoint, a consequence of 2.5's frontmatter choice
- [x] 4.8 Score that a per-agent link is the only host-specific content in the file, and that any other host-specific content is a violation — split by evidence strength: a host *name* warns (heuristic), a host *path* fails (structural)
- [x] 4.9 Confirm `CLAUDE.md` is never scored by any row — the harness refuses a `CLAUDE.md` target outright, and the suite asserts no scored row was emitted

## 5. Agent lifecycle rows

All nine are implemented and score for real when a host supplies
`AGENTS_MD_ADD_CMD` / `AGENTS_MD_REMOVE_CMD`. Without them they report
INCONCLUSIVE — named and excluded from the scored total per §20, not skipped
silently — because core cannot provision an agent into a repo it does not own.

- [x] 5.1 Score add-idempotency: provisioning twice produces one provision and one no-op, with all files byte-identical after the second
- [x] 5.2 Score that adding a second agent adds ONLY its link — the host-neutral section byte-identical, the first agent's link untouched — **plus a section-count row**: the byte-identical comparison reads first-BEGIN to first-END, so an appended duplicate leaves it equal and the cparx bug scored green until a fixture caught it
- [x] 5.3 Score that removing one of several agents deletes only that agent's directory and only that agent's link, leaving the section and every other link unchanged
- [x] 5.4 Score removal of an absent agent: reports not-present, changes nothing
- [x] 5.5 Score partial presence using the two real cparx shapes — a config with no skills, and a directory never committed — asserting removal reports what was missing rather than failing
- [x] 5.6 Score that tool-owned state (`package.json`, `node_modules`) is reported and left in place, not deleted
- [x] 5.7 Score the first-agent boundary: the section and the agent's link are both added
- [x] 5.8 Score the last-agent boundary: the link is removed and the host-neutral section SURVIVES, per 1.3
- [x] 5.9 Score re-adding an agent to a repo that has the section but no agents: only the link is added, section byte-identical

## 6. Tests and verification

- [x] 6.1 Write `tools/agents-md-conformance.test.sh` with a fixture per scored row, both directions pinned — a rule that rejects a valid layout is as bad as one that misses an invalid one — 58 assertions, including a conformant reference host and a defective one carrying the three forbidden defects
- [x] 6.2 Build a fixture reproducing the cparx duplicate state from the two real blocks, and assert the harness reports both without collapsing — both line ranges reported, no collapse, and the harness asserted not to modify the file it scores
- [x] 6.3 Run the suite under bash 3.2 with BSD sed and under bash 5 with GNU sed in a container, and record both totals — **58/58 on bash 3.2.57 + BSD sed**, **58/58 on bash 5.2.15 + GNU sed 4.9** (debian bookworm)
- [x] 6.4 Run `shellcheck -S warning` over every new script and reach zero findings — clean on both new scripts (shellcheck 0.11.0)
- [x] 6.5 Wire the harness into `.github/workflows/openspec-gate.yml` and confirm it runs against core itself — **wired; "against core itself" is not satisfiable as written.** Core has no `AGENTS.md`, and its `CLAUDE.md` is out of scope by the very requirement being added, so substituting it would enforce a rule the spec says does not apply. CI runs the fixture suite in both directions every push, plus a step that scores core's `AGENTS.md` the day it gains one and prints a NOTE until then

## 7. Close out

- [x] 7.1 Run `openspec validate --all` green
- [x] 7.2 Confirm no host repo was edited by this change — `codex-workflow`, `opencode-workflow` and `pi-agentic-apps-workflow` are all clean; the three live templates were read, never written. `claude-workflow` carries one untracked `openspec/` dir predating this work
- [ ] 7.3 Record the installer prerequisite requirement (detect missing prerequisites, offer to install, user accepts first) in the Part-2 installer change so it is not lost with this one — **BLOCKED: the Part-2 change does not exist.** There is nothing to write into, and creating a change is a propose action rather than part of this apply. The requirement is currently recorded in this change's `proposal.md` and `design.md`, which move to `openspec/changes/archive/` on archive — findable, but no longer in front of anyone. Needs a decision: open the Part-2 change now, or park the requirement in a durable core doc
- [ ] 7.4 Open the PR and archive the change
