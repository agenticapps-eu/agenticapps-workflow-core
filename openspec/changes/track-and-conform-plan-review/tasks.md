Ordered per design Decision 9. Sections 1–3 may proceed in any order; **§8
(publish producer) must complete before §9b (publish gate)**, and §8b
(re-review) must sit between them. Reversing that order blocks every change in
every project.

## 1. Repair and extend §18

- [x] 1.1 Correct `spec/18-retargeted-change-gate.md` line 146 ("the ≥2-reviewer requirement") to the one-reviewer floor
- [x] 1.2 Correct line 174 ("`REVIEWS.md` ≥ 2 reviewers for edits under an active change") to ≥ 1
- [x] 1.3 Add a **verdict term to the truth table** — required before the gate may count on verdicts, since the gate's source records that blocking on a verdict is non-conformant while the table lacks one
- [x] 1.4 Specify the verdict grammar exactly: section-bounded, fence-skipped, case-insensitive, anchored at **both** ends, optional markdown emphasis, closed vocabulary `APPROVE|REQUEST-CHANGES`, conflicting verdicts malformed
- [x] 1.5 Add the substance rule: a counted section carries at least one content line beyond heading, timestamp, trailer and verdict
- [x] 1.6 Add: the implementing host's vendor never counts, duplicates count once, the identity is recorded in `REVIEWS.md` and read from there, and an absent or unrecognised identity counts zero
- [x] 1.7 Add: a review is bound to a digest of the artifacts reviewed; a stale or digest-less review does not count
- [x] 1.8 Correct **every** other site stating a ≥2 floor — not a grep-and-judge, a checklist. `spec/17:129`; `spec/02:100`; `reference-implementations/openspec-change-gate/README.md:44`; `.../openspec-change-gate/hooks/openspec-gate.ci.yml:4,33`; `reference-implementations/reviewer-cli/README.md:34,74,127`; `.../reviewer-cli/reviewer-cli.sh:29,43,59,146`; the producer header (`:22,27,38`)
- [x] 1.9 Re-grep after 1.8 for `≥ *2|>= *2|at least two|two independent|MIN_REVIEWERS` and confirm every survivor is either intentional prose about *preference* or inside `gate/`, which is classified separately
- [x] 1.10 Name, without correcting, the out-of-repo sites that will contradict until re-vendor: the `agentic-apps-workflow` skill and the operator's `CLAUDE.md`
- [x] 1.11 Bump `spec_version` in `spec/00-overview.md:4` from `1.2.0` to `1.3.0` and record the change in `CHANGELOG.md`. Minor: enforcement terms are added and the floor text is corrected to match existing behaviour, so no host conformant to 1.2.0's behaviour becomes non-conformant

## 2. Establish the tracked source

- [x] 2.1 Create `reference-implementations/run-plan-review/` and seed `run-plan-review.sh` byte-identically from `~/.agenticapps/bin/run-plan-review.sh` (227 lines, marker 1.0.0)
- [x] 2.2 Verify byte-identity against the installed copy before any edit, so the baseline is provably the running implementation
- [x] 2.3 Write the README: purpose, install contract, version-marker rule, relationship to `reviewer-cli.sh`, and the egress boundary as Decision 6 states it
- [x] 2.4 Confirm the layout matches the sibling artifacts (`openspec-change-gate/`, `reviewer-cli/`, `shared-install/`)

## 3. Conform the floor

- [x] 3.1 `tdd="true"` — failing test: one reviewer returns, two time out, `REVIEWS.md` must be written with the one review
- [x] 3.2 `tdd="true"` — change the `MIN_REVIEWERS` default from 2 to 1 and make the test pass
- [x] 3.3 `tdd="true"` — failing test: `MIN_REVIEWERS=0` must exit with a usage error and write nothing
- [x] 3.4 `tdd="true"` — reject 0, negatives and non-integers; make the test pass
- [x] 3.5 Test that an explicitly set higher floor is still honoured
- [x] 3.6 Test that zero successful reviewers still writes nothing and exits non-zero

## 4. Count only real reviews

- [x] 4.1 `tdd="true"` — failing test: a vendor returning prose with no verdict must not count, and must be reported as failed with reason "no verdict"
- [x] 4.2 `tdd="true"` — failing test: a vendor returning **only** a verdict line must not count, and must be reported as failed with reason "no substance"
- [x] 4.3 `tdd="true"` — implement the shared verdict-and-substance predicate; make both tests pass
- [x] 4.4 Test that a REQUEST-CHANGES verdict with a body does count toward the floor
- [x] 4.5 Regression-test the exact opencode output from this change's own round-2 review, which counted while carrying no verdict
- [x] 4.6 Regression-test gemini's bare `VERDICT: APPROVE` of 2026-07-29T07:52:54Z on `shim-project-hooks`, which counted while carrying no body
- [x] 4.7 Confirm the producer's predicate and the gate's predicate are the same rule — a section the producer counts must be one the gate counts

## 5. Require the implementing host, never default it

- [x] 5.1 `tdd="true"` — failing test: invoked with no implementing-host identity, the producer exits with a usage error and writes nothing
- [x] 5.2 `tdd="true"` — failing test: an identity outside `claude|codex|gemini|opencode|pi` is a usage error; `pi` MUST be accepted (a host with no reviewer arm)
- [x] 5.3 `tdd="true"` — remove the `AGENT_SELF:-claude` default (`run-plan-review.sh:68`); require the identity explicitly; make both tests pass
- [x] 5.4 `tdd="true"` — failing test: the declared host's own vendor is recorded as excluded, not failed, and does not count
- [x] 5.5 `tdd="true"` — failing test: the same vendor named twice contributes at most one
- [x] 5.6 `tdd="true"` — failing test: two implementing hosts are accepted, recorded, and both excluded from the floor
- [x] 5.7 Confirm no **gate** caller changes are needed — if any host shim must export an identity, Decision 5 has been violated
- [x] 5.8 **Inventory every producer caller** — grep core, the four hosts, the seven projects, `~/.agenticapps/bin/`, and the workflow skill for invocations of `run-plan-review.sh` — and migrate each to pass an identity. Removing the default is a breaking interface change; this is the migration
- [x] 5.9 Confirm an un-migrated caller fails with a usage error naming the missing input, not with a guessed host

## 6. Make REVIEWS.md self-contained

- [x] 6.1 `tdd="true"` — failing test: `REVIEWS.md` records requested, counted, excluded and failed vendors with reasons
- [x] 6.2 `tdd="true"` — failing test: `REVIEWS.md` carries a trailer with the implementing host, the digest, and the producer version
- [x] 6.3 `tdd="true"` — implement the record block and the trailer; make both tests pass
- [x] 6.4 Test that a failure reason distinguishes timeout, non-zero exit, no-verdict and no-substance
- [x] 6.5 Confirm the record and trailer survive the existing stdout sanitiser and do not trip the `## Reviewer:` forge guard
- [x] 6.6 Confirm the trailer is not parsed as a reviewer section, and does not itself satisfy the substance rule for the section above it

## 7. Compute the digest

- [x] 7.1 `tdd="true"` — failing test: the digest covers `proposal.md`, `design.md` and every `specs/**/*.md`, ordered `LC_ALL=C`, and nothing else
- [x] 7.2 `tdd="true"` — **widen the producer's prompt glob from `specs/*/spec.md` to `specs/**/*.md`** so the transmitted set and the digest set are the same set; failing test: a nested spec file reaches the reviewers
- [x] 7.3 `tdd="true"` — implement SHA-256 over the serialisation with **both** path and content length-framed; make the test pass
- [x] 7.4 `tdd="true"` — failing test: a change directory containing a path with an embedded newline produces a distinct digest from the crafted collision the unframed-path form would allow
- [x] 7.5 `tdd="true"` — failing test: a symlink in the artifact set makes the digest uncomputable and the producer refuses to publish
- [x] 7.6 `tdd="true"` — failing test: prompt, digest and published file derive from one snapshot — mutate an artifact between prompt construction and publication and confirm the producer refuses rather than publishing a digest for bytes nobody reviewed
- [x] 7.7 Test that editing `tasks.md` does **not** change the digest, and that ticking a checkbox therefore does not stale a review
- [x] 7.8 Test that deleting a spec file present at review time **does** change it
- [x] 7.9 Test that a CRLF-only difference does not change it, and that a trailing-newline-only difference does not either
- [x] 7.10 Compute the digest independently (a second implementation, or `shasum` by hand) on one real change and confirm the two agree — the contract exists to make this true

## 7b. Specify and implement the trailer

- [x] 7b.1 `tdd="true"` — failing test: the producer writes exactly one trailer, as the file's final content, with all three required fields in the specified grammar
- [x] 7b.2 `tdd="true"` — failing test: the gate parses that trailer and rejects a file with none, with two, with a non-final one, or with a required field missing
- [x] 7b.3 `tdd="true"` — failing test: an unrecognised trailer field is ignored and the review still counts, so a later producer can extend the format
- [x] 7b.4 `tdd="true"` — failing test: the trailer and the generation-timestamp line do not satisfy the substance rule for the section above them — the exclusions that were unimplementable before the grammar existed
- [x] 7b.5 Confirm producer and gate share one trailer grammar, tested by round-tripping a producer-written file through the gate's parser
- [x] 7b.6 `tdd="true"` — failing test: a duplicated required key makes the trailer malformed rather than resolving first-wins or last-wins
- [x] 7b.7 `tdd="true"` — failing test: a vendor response carrying the trailer's opening delimiter **at the start of a line** is rejected and the vendor recorded as failed, so one vendor cannot invalidate the artifact
- [x] 7b.7a `tdd="true"` — failing test: a vendor response mentioning the trailer delimiter or `## Reviewer:` **inside a sentence** is KEPT. Regression-test against round 6 of this change, where opencode's review quoted `openspec-review-trailer` inline and codex's quoted `## Reviewer: codex-2` inline — a substring guard would have destroyed the first. Match the anchoring the shipped forge guard already uses (`^[[:space:]]*…`)
- [x] 7b.8 `tdd="true"` — failing test: an optional `tasks-digest` that no longer matches produces a non-blocking report of implementation-plan drift, and its absence changes nothing
- [x] 7b.9 `tdd="true"` — failing test: a reviewer section containing a `### Findings` subheading keeps its verdict. **Superseded by the round-10 bound:** sections close only at the next `## Reviewer:`, so a `## Summary` subheading keeps its verdict too — the level-≤2 rule this task was written against discarded exactly that case
- [x] 7b.10 `tdd="true"` — failing test: the generation-timestamp line does not satisfy the substance rule, per its specified grammar

## 8. Publish the producer — before the gate

- [x] 8.1 Confirm the sanitiser, forge guard, and 3/4/5 exit-code reporting are unmodified by diffing against the 2.2 baseline
- [x] 8.2 Bump the version marker to 1.1.0 with a header changelog note, following the existing marker convention
- [x] 8.3 Add the `resolve-core-artifact.sh` mapping for `bin/run-plan-review.sh`
- [ ] 8.4 Point the Claude installer at core rather than its vendored 1.0.0 copy, so core is the operational source of truth
- [x] 8.5 Publish to `~/.agenticapps/bin/`; verify it reports 1.1.0 and that the arbiter refuses a simulated older-version overwrite
- [x] 8.6 Reproduce the 2026-07-29 failure end-to-end: three vendors, short timeout, single survivor now yields a written `REVIEWS.md` carrying a trailer

## 8b. Re-review the in-flight changes — between producer and gate

- [x] 8b.1 **Inventory every active change across the fleet** — core, the four hosts, the seven projects — not just this branch. The gate is global; a project discovering the trailer requirement when the new gate blocks it is a flag day announced by an outage
- [x] 8b.2 Re-run the producer over `track-and-conform-plan-review` so it carries a 1.1.0 trailer for its current text
- [x] 8b.3 Re-run it over `shim-project-hooks` likewise, once that change's own revision has settled
- [x] 8b.4 Re-review every other active change the inventory found, or record explicitly which are accepted as blocked and why. **INVENTORY TAKEN 2026-07-30 — ~35 active changes across 6 repos, none carrying a trailer:** `fx-signal-agent` 10, `fbc-platform` 8, `agenticapps-dashboard-add-agent-board` 8, `agenticapps-dashboard` 5, `callbot` 3, `agenticapps-roadmap` 1. This wave is the gate's precondition, not its follow-up.
  **THE TOTAL IS UNVERIFIED AND WAS WRONG.** It was recorded as 37; the per-repo breakdown beside it sums to 35, and the discrepancy went unnoticed through three review rounds and was restated in `proposal.md`, `design.md` and two handoffs by an author who never added it up. Neither figure is trusted here: the breakdown is the more specific claim, but nothing re-derives it, and half these repos are outside this family. **Retake the inventory before acting on any count.** This is the overclaim class the change exists to eliminate, in the change's own evidence — the same fault round 8 caught in `CALLER-INVENTORY.md`, which named sites as corrected that had not been touched.
  **DISCHARGED 2026-07-31 by the second branch — recorded as accepted-blocked, not re-reviewed** (operator's decision). All 37 are accepted as blocked by gate 1.5.0 on publication. The rationale, and the limits of it:
  - **Re-reviewing them here is the wrong shape.** Each change would need its own producer run, its own vendor egress, and its own trailer committed *in its own repo*. That is 37 review runs and 6 repository commits driven from a change whose stated scope is two repos. The work belongs to each repo's next active change, not to this one.
  - **Three of the six repos are outside this family.** `fx-signal-agent`, `fbc-platform` and `callbot` are factiv-family; `~/Sourcecode/CLAUDE.md` makes cross-family work explicit-request-only. This change cannot authorise edits there, so a "re-review the fleet" task written here is unsatisfiable by construction — the same defect class as the round-6 `pi` lockout and the round-8 "every producer caller SHALL be migrated" overclaim.
  - **What being blocked actually costs.** The gate blocks *code edits* while a change is open; it does not touch reads, commits of non-code files, or `GSD_SKIP_REVIEWS=1`. A repo that hits the block runs its own plan review once and is unblocked permanently. The failure is loud, self-describing, and self-serviceable — which is why it is acceptable, and why publishing early on 2026-07-30 was still wrong: it was unannounced, not merely disruptive.
  - **This was a real cost being accepted — and gate 2.0.0 then removed it.** The paragraph above said six repos would each hit a hard block at their next code edit and nobody had been told. That is no longer true: reviews do not block, so those repos get a NOTE recommending a review and continue working. The acceptance recorded here is retained because it was the right call *under the rules as they stood*, and because what it accepted was the cost of an enforcement mechanism that has since been withdrawn.
- [x] 8b.6 **Publish the gate — no longer a fleet event.** Superseded by gate 2.0.0: reviews do not block, so publishing cannot block anyone. The precondition this task carried (clear or announce the fleet's review state first) existed only because an unreviewed change was refused a code edit. Under 2.0.0 those repos get a NOTE telling them a plan review is worth running, and carry on working. 1.5.0's early publication on 2026-07-30 remains the reason 1.6.0 was never published and 2.0.0 supersedes both; see `~/.agenticapps/install.log` for the rollback record.
- [x] 8b.5 Confirm each new `REVIEWS.md` satisfies verdict, substance, identity and digest before the gate that requires them exists
- [x] 8b.7 **Announce the block — DISSOLVED by gate 2.0.0, not completed.** This task existed because publishing would hard-block six repositories at their next code edit, so they had to be warned first. Reviews no longer block, so there is no outage to announce: an affected repo sees a NOTE recommending a plan review and keeps working.
  Recorded rather than deleted, because the shape of it is the lesson. Three tasks (8b.4, 8b.6, 8b.7), a rollback, and a rolled-back publication all existed to manage the blast radius of a *block* — none of them to improve a single review. Removing the enforcement removed all three at once. When a precondition needs its own precondition, the thing to question is the mechanism, not the sequencing.

## 9. Retire the ancestor

- [x] 9.1 Confirm nothing references `gate/run-plan-review.sh` — grep core, the four hosts, and the seven projects
- [x] 9.2 Delete `gate/run-plan-review.sh`
- [x] 9.3 Record in the handoff that `gate/`'s remaining contents are still unclassified, so the open question is not silently closed

## 9b. Harden the gate (openspec-change-gate.sh 1.4.0 → 1.5.0)

- [x] 9b.1 `tdd="true"` — failing test: a `REVIEWS.md` section with a heading and no verdict must not count toward the floor
- [x] 9b.2 `tdd="true"` — failing test: a section with a verdict and no body must not count
- [x] 9b.3 `tdd="true"` — make `reviewer_count()` and `pending_rejections()` share one verdict-and-substance predicate; make both tests pass
- [x] 9b.4 `tdd="true"` — failing tests for each shipped-regex bypass: `REQUEST-CHANGES-LATER` must not match; `verdict: approve` must match; a verdict under a later non-reviewer `##` must not attribute to the reviewer above it
- [x] 9b.5 `tdd="true"` — failing test: two conflicting verdicts in one section make it malformed, uncounted and reported
- [x] 9b.6 Verify both functions still skip fenced blocks, per the existing comments
- [x] 9b.7 `tdd="true"` — failing test: with no implementing-host identity in `REVIEWS.md`, the gate counts zero reviewers and blocks
- [x] 9b.8 `tdd="true"` — read the identity from the artifact's trailer; retire `OPENSPEC_GATE_SELF` as an identity source; make the test pass
- [x] 9b.9 Test that a `REVIEWS.md` produced on one host and evaluated on another excludes the **recorded** host, not the running one
- [x] 9b.10 `tdd="true"` — failing test: a change amended after review is detected as stale and does not count
- [x] 9b.11 `tdd="true"` — implement digest verification against the §7 contract; make the test pass
- [x] 9b.12 `tdd="true"` — failing test: a `REVIEWS.md` with no digest is reported unverifiable and does not count
- [x] 9b.13 `tdd="true"` — failing test: the gate distinguishes and reports "no REVIEWS.md", "trailer absent or malformed", "digest mismatch — stale", and "no section with a verdict and a body" as separate reasons
- [x] 9b.14 `tdd="true"` — failing test: one vendor with two well-formed sections carrying conflicting verdicts contributes one to the count and is reported as REQUEST-CHANGES
- [x] 9b.15 `tdd="true"` — failing tests for the emphasis normalisation: `**VERDICT: REQUEST-CHANGES**`, `VERDICT: **REQUEST-CHANGES**`, `VERDICT:** REQUEST-CHANGES` and `**VERDICT:** REQUEST-CHANGES` all count
- [x] 9b.15a `tdd="true"` — failing tests for the timestamp grammar: `_generated 2026-07-29T12:04:50Z · timeout 600s_` is recognised and excluded from substance; a fractional-second or `+00:00` variant is not recognised as the producer's timestamp line
- [x] 9b.15b `tdd="true"` — failing test: the `·` separator is matched bytewise as `0xC2 0xB7` under `LC_ALL=C`, not via a locale-aware character class. Run the harness under `LC_ALL=C` explicitly
- [x] 9b.15c `tdd="true"` — failing test: a `## Reviewer: codex-2` heading does not count and is reported as an unrecognised reviewer; confirm this closes the exclusion bypass on a `codex`-authored change
- [x] 9b.15d `tdd="true"` — failing tests for malformed trailer values: a `digest` that is not `sha256:` + 64 lowercase hex, a non-semver `producer-version`, and `implementing-host: claude, codex` (space after comma) each count zero reviewers
- [x] 9b.15e `tdd="true"` — failing test: trailing blank lines after `-->` still count as the trailer being final content
- [x] 9b.15f Record the accepted normalisation consequence: `VERDICT: REQUEST-_CHANGES` normalises to a valid verdict. Confirm a manufactured verdict alone still fails the substance rule
- [x] 9b.16 Confirm the gate names every objecting reviewer on every invocation for as long as the objection stands. **This is a nag, not an audit trail** — the wording here and in the spec claimed the latter and was withdrawn in round 11. It goes to stderr with no durable sink, no operator identity and no timestamp; what it guarantees is that an objection reappears until the change is amended or re-reviewed, which is worth having and is not a record of who proceeded
- [x] 9b.17 Run the shared predicate over every `REVIEWS.md` in the repo and confirm each well-formed one still counts — the change must not discount good evidence
- [ ] 9b.18 Bump to gate **1.6.0** (was 1.5.0), run `tools/change-gate-conformance.sh` green — its `TOTAL:` line must report zero failed and zero inconclusive — and publish. **Bumped and green at 69/69; NOT published**, which is the remaining half. 1.5.0 is not amended in place because it briefly reached the fleet on 2026-07-30, and a version that ever shipped must keep meaning one thing. Publication is still gated on 8b.7
- [x] 9b.19 Re-verify this branch's two changes under 1.5.0 — after 8b they carry trailers and MUST read as current; before 8b they MUST read as unverifiable. Test both directions.

## 9c. Fix the wrapper's process-table exposure (reviewer-cli.sh 1.1.0 → 1.2.0)

- [x] 9c.1 `tdd="true"` — failing test: the prompt must not appear in the process table for any of the four vendor arms
- [x] 9c.2 `tdd="true"` — deliver the prompt by file path or stdin per arm, never as argv; make the test pass for all four
- [x] 9c.3 Verify `codex exec` still works — its arm carries a pin because it hangs reading stdin (pilot friction #3); that arm takes a file path
- [x] 9c.4 Confirm the 3/4/5 exit-code contract and the timeout wrapper are unchanged
- [x] 9c.5 Bump to 1.2.0, publish, and confirm the arbiter refuses an older overwrite

## 9d. Correct the egress documentation

- [x] 9d.1 Document that vendor CLIs are agentic and run with the operator's credentials — the boundary is what they can reach on this machine as this user, not the prompt and not the repository
- [x] 9d.2 Document consent as scoped to vendor selection, not to a file set the producer does not control
- [x] 9d.3 Confirm the untrusted-reviewer-output requirement is in the capability delta, not only in prose — it was prose-only in the previous revision
- [x] 9d.4 State that no secret or PII screening is performed, and recommend checking before invoking
- [x] 9d.6 Document that vendor CLIs **write and execute** as well as read — an earlier revision described reading only, which leaves a reviewer CLI editing the change it reviews outside the model entirely
- [x] 9d.7 `tdd="true"` — failing test: the producer prints a stderr notice at invocation naming the vendors and stating that no screening is performed, since invocation alone is the consent act
- [x] 9d.8 Weaken the independence claim to "a different CLI": `opencode` may route to the implementing host's provider and model, so two counted reviewers can be one model twice
- [x] 9d.9 `tdd="true"` — failing test: the producer writes a standing notice into `REVIEWS.md` marking reviewer sections as third-party input to be read as claims, not instructions, so the warning reaches any agent that loads the file. Cite §14 as the governing policy rather than restating it
- [x] 9d.10 State the notice's honest limit alongside it: an instruction-following model can be talked out of a notice, and consumer sandboxing is not attempted because the consumer is the operator's own session, which this change does not control and cannot conformance-test
- [x] 9d.5 Record `screen-review-egress` as the named follow-up change, owned by whoever implements this one

## 10. Verify and record

- [x] 10.1 Run `openspec validate --all` green
- [ ] 10.2 Run `openspec-change-gate.sh --ci` green
- [x] 10.3 `tdd="true"` — failing test: `install-shared-artifact.sh` refuses a downgrade today (`:148`), so add `--allow-downgrade <artifact> --reason <text>` — both mandatory together, scoped to the named artifact for that invocation only, no wildcard and no environment variable. Without it every row of the rollback table fails at the first command
- [x] 10.3a `tdd="true"` — failing test: an unknown artifact name is a usage error, not a silent no-op
- [x] 10.3b `tdd="true"` — failing test: authorising one artifact does not downgrade a second older artifact in the same run
- [x] 10.3c `tdd="true"` — failing test: a reason containing a newline, tab or other control character is rejected outright (not escaped), so it cannot forge a second log record; empty-after-trim and >200 chars are rejected too
- [x] 10.3d Append one tab-separated record per downgrade to `~/.agenticapps/install.log`: UTC ISO-8601, `downgrade`, artifact, from-version, to-version, user, reason. Document it as an operator's record, not evidence against an adversary who can also write it
- [x] 10.4 Rehearse rollback using that flag: republish producer 1.0.0 under a live 1.5.0 gate, confirm it blocks as the design predicts, then restore — the ordering claim must be tested, not asserted
- [x] 10.5 Stage-2 independent code review per §07 — **DONE 2026-07-31.** Dispatched to a sub-agent with no implementation context and instructed not to read `session-handoff.md`, `proposal.md`, `design.md` or `REVIEWS.md`, since those carry the author's rationale and §07's independence rule is about bias, not just about a separate process. Verdict: REQUEST-CHANGES.
  It found what six rounds of Stage-1 vendor review across three vendors did not: **the producer and the gate do not share a predicate**, so two ordinary vendor outputs made the producer report success on evidence the gate counted as zero reviewers. That is the change's own thesis, false in its own code. Fixed in gate 1.6.0 and producer 1.2.0; see the CHANGELOG.
  The reason Stage 1 could not have caught it is worth recording: Stage 1 reads artifacts, and the artifacts *described* the invariant correctly. Only reading the code — or running it — shows the two awk programs differ under a comment asserting they are byte-identical. This is the case for §07 existing, stated better than the section states it.
- [x] 10.6 Write the ADR: why the installed copy was promoted over the in-repo ancestor, the floor-vs-preference distinction, why identity moved into the artifact, and why the digest covers exactly what is transmitted
