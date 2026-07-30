Ordered per design Decision 9. Sections 1–3 may proceed in any order; **§8
(publish producer) must complete before §9b (publish gate)**, and §8b
(re-review) must sit between them. Reversing that order blocks every change in
every project.

## 1. Repair and extend §18

- [ ] 1.1 Correct `spec/18-retargeted-change-gate.md` line 146 ("the ≥2-reviewer requirement") to the one-reviewer floor
- [ ] 1.2 Correct line 174 ("`REVIEWS.md` ≥ 2 reviewers for edits under an active change") to ≥ 1
- [ ] 1.3 Add a **verdict term to the truth table** — required before the gate may count on verdicts, since the gate's source records that blocking on a verdict is non-conformant while the table lacks one
- [ ] 1.4 Specify the verdict grammar exactly: section-bounded, fence-skipped, case-insensitive, anchored at **both** ends, optional markdown emphasis, closed vocabulary `APPROVE|REQUEST-CHANGES`, conflicting verdicts malformed
- [ ] 1.5 Add the substance rule: a counted section carries at least one content line beyond heading, timestamp, trailer and verdict
- [ ] 1.6 Add: the implementing host's vendor never counts, duplicates count once, the identity is recorded in `REVIEWS.md` and read from there, and an absent or unrecognised identity counts zero
- [ ] 1.7 Add: a review is bound to a digest of the artifacts reviewed; a stale or digest-less review does not count
- [ ] 1.8 Correct **every** other site stating a ≥2 floor — not a grep-and-judge, a checklist. `spec/17:129`; `spec/02:100`; `reference-implementations/openspec-change-gate/README.md:44`; `.../openspec-change-gate/hooks/openspec-gate.ci.yml:4,33`; `reference-implementations/reviewer-cli/README.md:34,74,127`; `.../reviewer-cli/reviewer-cli.sh:29,43,59,146`; the producer header (`:22,27,38`)
- [ ] 1.9 Re-grep after 1.8 for `≥ *2|>= *2|at least two|two independent|MIN_REVIEWERS` and confirm every survivor is either intentional prose about *preference* or inside `gate/`, which is classified separately
- [ ] 1.10 Name, without correcting, the out-of-repo sites that will contradict until re-vendor: the `agentic-apps-workflow` skill and the operator's `CLAUDE.md`
- [ ] 1.11 Bump `spec_version` in `spec/00-overview.md:4` from `1.2.0` to `1.3.0` and record the change in `CHANGELOG.md`. Minor: enforcement terms are added and the floor text is corrected to match existing behaviour, so no host conformant to 1.2.0's behaviour becomes non-conformant

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
- [ ] 4.7 Confirm the producer's predicate and the gate's predicate are the same rule — a section the producer counts must be one the gate counts

## 5. Require the implementing host, never default it

- [ ] 5.1 `tdd="true"` — failing test: invoked with no implementing-host identity, the producer exits with a usage error and writes nothing
- [ ] 5.2 `tdd="true"` — failing test: an identity outside `claude|codex|gemini|opencode` is a usage error
- [ ] 5.3 `tdd="true"` — remove the `AGENT_SELF:-claude` default (`run-plan-review.sh:68`); require the identity explicitly; make both tests pass
- [ ] 5.4 `tdd="true"` — failing test: the declared host's own vendor is recorded as excluded, not failed, and does not count
- [ ] 5.5 `tdd="true"` — failing test: the same vendor named twice contributes at most one
- [ ] 5.6 `tdd="true"` — failing test: two implementing hosts are accepted, recorded, and both excluded from the floor
- [ ] 5.7 Confirm no **gate** caller changes are needed — if any host shim must export an identity, Decision 5 has been violated
- [ ] 5.8 **Inventory every producer caller** — grep core, the four hosts, the seven projects, `~/.agenticapps/bin/`, and the workflow skill for invocations of `run-plan-review.sh` — and migrate each to pass an identity. Removing the default is a breaking interface change; this is the migration
- [ ] 5.9 Confirm an un-migrated caller fails with a usage error naming the missing input, not with a guessed host

## 6. Make REVIEWS.md self-contained

- [ ] 6.1 `tdd="true"` — failing test: `REVIEWS.md` records requested, counted, excluded and failed vendors with reasons
- [ ] 6.2 `tdd="true"` — failing test: `REVIEWS.md` carries a trailer with the implementing host, the digest, and the producer version
- [ ] 6.3 `tdd="true"` — implement the record block and the trailer; make both tests pass
- [ ] 6.4 Test that a failure reason distinguishes timeout, non-zero exit, no-verdict and no-substance
- [ ] 6.5 Confirm the record and trailer survive the existing stdout sanitiser and do not trip the `## Reviewer:` forge guard
- [ ] 6.6 Confirm the trailer is not parsed as a reviewer section, and does not itself satisfy the substance rule for the section above it

## 7. Compute the digest

- [ ] 7.1 `tdd="true"` — failing test: the digest covers `proposal.md`, `design.md` and every `specs/**/*.md`, ordered `LC_ALL=C`, and nothing else
- [ ] 7.2 `tdd="true"` — **widen the producer's prompt glob from `specs/*/spec.md` to `specs/**/*.md`** so the transmitted set and the digest set are the same set; failing test: a nested spec file reaches the reviewers
- [ ] 7.3 `tdd="true"` — implement SHA-256 over the serialisation with **both** path and content length-framed; make the test pass
- [ ] 7.4 `tdd="true"` — failing test: a change directory containing a path with an embedded newline produces a distinct digest from the crafted collision the unframed-path form would allow
- [ ] 7.5 `tdd="true"` — failing test: a symlink in the artifact set makes the digest uncomputable and the producer refuses to publish
- [ ] 7.6 `tdd="true"` — failing test: prompt, digest and published file derive from one snapshot — mutate an artifact between prompt construction and publication and confirm the producer refuses rather than publishing a digest for bytes nobody reviewed
- [ ] 7.7 Test that editing `tasks.md` does **not** change the digest, and that ticking a checkbox therefore does not stale a review
- [ ] 7.8 Test that deleting a spec file present at review time **does** change it
- [ ] 7.9 Test that a CRLF-only difference does not change it, and that a trailing-newline-only difference does not either
- [ ] 7.10 Compute the digest independently (a second implementation, or `shasum` by hand) on one real change and confirm the two agree — the contract exists to make this true

## 7b. Specify and implement the trailer

- [ ] 7b.1 `tdd="true"` — failing test: the producer writes exactly one trailer, as the file's final content, with all three required fields in the specified grammar
- [ ] 7b.2 `tdd="true"` — failing test: the gate parses that trailer and rejects a file with none, with two, with a non-final one, or with a required field missing
- [ ] 7b.3 `tdd="true"` — failing test: an unrecognised trailer field is ignored and the review still counts, so a later producer can extend the format
- [ ] 7b.4 `tdd="true"` — failing test: the trailer and the generation-timestamp line do not satisfy the substance rule for the section above them — the exclusions that were unimplementable before the grammar existed
- [ ] 7b.5 Confirm producer and gate share one trailer grammar, tested by round-tripping a producer-written file through the gate's parser
- [ ] 7b.6 `tdd="true"` — failing test: a duplicated required key makes the trailer malformed rather than resolving first-wins or last-wins
- [x] 7b.7 `tdd="true"` — failing test: a vendor response carrying the trailer's opening delimiter **at the start of a line** is rejected and the vendor recorded as failed, so one vendor cannot invalidate the artifact
- [x] 7b.7a `tdd="true"` — failing test: a vendor response mentioning the trailer delimiter or `## Reviewer:` **inside a sentence** is KEPT. Regression-test against round 6 of this change, where opencode's review quoted `openspec-review-trailer` inline and codex's quoted `## Reviewer: codex-2` inline — a substring guard would have destroyed the first. Match the anchoring the shipped forge guard already uses (`^[[:space:]]*…`)
- [ ] 7b.8 `tdd="true"` — failing test: an optional `tasks-digest` that no longer matches produces a non-blocking report of implementation-plan drift, and its absence changes nothing
- [x] 7b.9 `tdd="true"` — failing test: a reviewer section containing a `### Findings` subheading keeps its verdict, because sections bound at headings of level ≤ 2
- [ ] 7b.10 `tdd="true"` — failing test: the generation-timestamp line does not satisfy the substance rule, per its specified grammar

## 8. Publish the producer — before the gate

- [ ] 8.1 Confirm the sanitiser, forge guard, and 3/4/5 exit-code reporting are unmodified by diffing against the 2.2 baseline
- [ ] 8.2 Bump the version marker to 1.1.0 with a header changelog note, following the existing marker convention
- [ ] 8.3 Add the `resolve-core-artifact.sh` mapping for `bin/run-plan-review.sh`
- [ ] 8.4 Point the Claude installer at core rather than its vendored 1.0.0 copy, so core is the operational source of truth
- [ ] 8.5 Publish to `~/.agenticapps/bin/`; verify it reports 1.1.0 and that the arbiter refuses a simulated older-version overwrite
- [ ] 8.6 Reproduce the 2026-07-29 failure end-to-end: three vendors, short timeout, single survivor now yields a written `REVIEWS.md` carrying a trailer

## 8b. Re-review the in-flight changes — between producer and gate

- [ ] 8b.1 **Inventory every active change across the fleet** — core, the four hosts, the seven projects — not just this branch. The gate is global; a project discovering the trailer requirement when the new gate blocks it is a flag day announced by an outage
- [ ] 8b.2 Re-run the producer over `track-and-conform-plan-review` so it carries a 1.1.0 trailer for its current text
- [ ] 8b.3 Re-run it over `shim-project-hooks` likewise, once that change's own revision has settled
- [ ] 8b.4 Re-review every other active change the inventory found, or record explicitly which are accepted as blocked and why
- [ ] 8b.5 Confirm each new `REVIEWS.md` satisfies verdict, substance, identity and digest before the gate that requires them exists

## 9. Retire the ancestor

- [ ] 9.1 Confirm nothing references `gate/run-plan-review.sh` — grep core, the four hosts, and the seven projects
- [ ] 9.2 Delete `gate/run-plan-review.sh`
- [ ] 9.3 Record in the handoff that `gate/`'s remaining contents are still unclassified, so the open question is not silently closed

## 9b. Harden the gate (openspec-change-gate.sh 1.4.0 → 1.5.0)

- [ ] 9b.1 `tdd="true"` — failing test: a `REVIEWS.md` section with a heading and no verdict must not count toward the floor
- [ ] 9b.2 `tdd="true"` — failing test: a section with a verdict and no body must not count
- [ ] 9b.3 `tdd="true"` — make `reviewer_count()` and `pending_rejections()` share one verdict-and-substance predicate; make both tests pass
- [ ] 9b.4 `tdd="true"` — failing tests for each shipped-regex bypass: `REQUEST-CHANGES-LATER` must not match; `verdict: approve` must match; a verdict under a later non-reviewer `##` must not attribute to the reviewer above it
- [ ] 9b.5 `tdd="true"` — failing test: two conflicting verdicts in one section make it malformed, uncounted and reported
- [ ] 9b.6 Verify both functions still skip fenced blocks, per the existing comments
- [ ] 9b.7 `tdd="true"` — failing test: with no implementing-host identity in `REVIEWS.md`, the gate counts zero reviewers and blocks
- [ ] 9b.8 `tdd="true"` — read the identity from the artifact's trailer; retire `OPENSPEC_GATE_SELF` as an identity source; make the test pass
- [ ] 9b.9 Test that a `REVIEWS.md` produced on one host and evaluated on another excludes the **recorded** host, not the running one
- [ ] 9b.10 `tdd="true"` — failing test: a change amended after review is detected as stale and does not count
- [ ] 9b.11 `tdd="true"` — implement digest verification against the §7 contract; make the test pass
- [ ] 9b.12 `tdd="true"` — failing test: a `REVIEWS.md` with no digest is reported unverifiable and does not count
- [ ] 9b.13 `tdd="true"` — failing test: the gate distinguishes and reports "no REVIEWS.md", "trailer absent or malformed", "digest mismatch — stale", and "no section with a verdict and a body" as separate reasons
- [ ] 9b.14 `tdd="true"` — failing test: one vendor with two well-formed sections carrying conflicting verdicts contributes one to the count and is reported as REQUEST-CHANGES
- [ ] 9b.15 `tdd="true"` — failing tests for the emphasis normalisation: `**VERDICT: REQUEST-CHANGES**`, `VERDICT: **REQUEST-CHANGES**`, `VERDICT:** REQUEST-CHANGES` and `**VERDICT:** REQUEST-CHANGES` all count
- [ ] 9b.15a `tdd="true"` — failing tests for the timestamp grammar: `_generated 2026-07-29T12:04:50Z · timeout 600s_` is recognised and excluded from substance; a fractional-second or `+00:00` variant is not recognised as the producer's timestamp line
- [ ] 9b.15b `tdd="true"` — failing test: the `·` separator is matched bytewise as `0xC2 0xB7` under `LC_ALL=C`, not via a locale-aware character class. Run the harness under `LC_ALL=C` explicitly
- [ ] 9b.15c `tdd="true"` — failing test: a `## Reviewer: codex-2` heading does not count and is reported as an unrecognised reviewer; confirm this closes the exclusion bypass on a `codex`-authored change
- [ ] 9b.15d `tdd="true"` — failing tests for malformed trailer values: a `digest` that is not `sha256:` + 64 lowercase hex, a non-semver `producer-version`, and `implementing-host: claude, codex` (space after comma) each count zero reviewers
- [ ] 9b.15e `tdd="true"` — failing test: trailing blank lines after `-->` still count as the trailer being final content
- [ ] 9b.15f Record the accepted normalisation consequence: `VERDICT: REQUEST-_CHANGES` normalises to a valid verdict. Confirm a manufactured verdict alone still fails the substance rule
- [ ] 9b.16 Confirm the gate names every objecting reviewer on every invocation for as long as the objection stands — this report is the audit trail for proceeding past an objection
- [ ] 9b.17 Run the shared predicate over every `REVIEWS.md` in the repo and confirm each well-formed one still counts — the change must not discount good evidence
- [ ] 9b.18 Bump to gate 1.5.0, run `tools/change-gate-conformance.sh` green — its `TOTAL:` line must report zero failed and zero inconclusive — and publish
- [ ] 9b.19 Re-verify this branch's two changes under 1.5.0 — after 8b they carry trailers and MUST read as current; before 8b they MUST read as unverifiable. Test both directions.

## 9c. Fix the wrapper's process-table exposure (reviewer-cli.sh 1.1.0 → 1.2.0)

- [ ] 9c.1 `tdd="true"` — failing test: the prompt must not appear in the process table for any of the four vendor arms
- [ ] 9c.2 `tdd="true"` — deliver the prompt by file path or stdin per arm, never as argv; make the test pass for all four
- [ ] 9c.3 Verify `codex exec` still works — its arm carries a pin because it hangs reading stdin (pilot friction #3); that arm takes a file path
- [ ] 9c.4 Confirm the 3/4/5 exit-code contract and the timeout wrapper are unchanged
- [ ] 9c.5 Bump to 1.2.0, publish, and confirm the arbiter refuses an older overwrite

## 9d. Correct the egress documentation

- [ ] 9d.1 Document that vendor CLIs are agentic and run with the operator's credentials — the boundary is what they can reach on this machine as this user, not the prompt and not the repository
- [ ] 9d.2 Document consent as scoped to vendor selection, not to a file set the producer does not control
- [ ] 9d.3 Confirm the untrusted-reviewer-output requirement is in the capability delta, not only in prose — it was prose-only in the previous revision
- [ ] 9d.4 State that no secret or PII screening is performed, and recommend checking before invoking
- [ ] 9d.6 Document that vendor CLIs **write and execute** as well as read — an earlier revision described reading only, which leaves a reviewer CLI editing the change it reviews outside the model entirely
- [ ] 9d.7 `tdd="true"` — failing test: the producer prints a stderr notice at invocation naming the vendors and stating that no screening is performed, since invocation alone is the consent act
- [ ] 9d.8 Weaken the independence claim to "a different CLI": `opencode` may route to the implementing host's provider and model, so two counted reviewers can be one model twice
- [ ] 9d.9 `tdd="true"` — failing test: the producer writes a standing notice into `REVIEWS.md` marking reviewer sections as third-party input to be read as claims, not instructions, so the warning reaches any agent that loads the file. Cite §14 as the governing policy rather than restating it
- [ ] 9d.10 State the notice's honest limit alongside it: an instruction-following model can be talked out of a notice, and consumer sandboxing is not attempted because the consumer is the operator's own session, which this change does not control and cannot conformance-test
- [ ] 9d.5 Record `screen-review-egress` as the named follow-up change, owned by whoever implements this one

## 10. Verify and record

- [ ] 10.1 Run `openspec validate --all` green
- [ ] 10.2 Run `openspec-change-gate.sh --ci` green
- [ ] 10.3 `tdd="true"` — failing test: `install-shared-artifact.sh` refuses a downgrade today (`:148`), so add `--allow-downgrade <artifact> --reason <text>` — both mandatory together, scoped to the named artifact for that invocation only, no wildcard and no environment variable. Without it every row of the rollback table fails at the first command
- [ ] 10.3a `tdd="true"` — failing test: an unknown artifact name is a usage error, not a silent no-op
- [ ] 10.3b `tdd="true"` — failing test: authorising one artifact does not downgrade a second older artifact in the same run
- [ ] 10.3c `tdd="true"` — failing test: a reason containing a newline, tab or other control character is rejected outright (not escaped), so it cannot forge a second log record; empty-after-trim and >200 chars are rejected too
- [ ] 10.3d Append one tab-separated record per downgrade to `~/.agenticapps/install.log`: UTC ISO-8601, `downgrade`, artifact, from-version, to-version, user, reason. Document it as an operator's record, not evidence against an adversary who can also write it
- [ ] 10.4 Rehearse rollback using that flag: republish producer 1.0.0 under a live 1.5.0 gate, confirm it blocks as the design predicts, then restore — the ordering claim must be tested, not asserted
- [ ] 10.5 Stage-2 independent code review per §07
- [ ] 10.6 Write the ADR: why the installed copy was promoted over the in-repo ancestor, the floor-vs-preference distinction, why identity moved into the artifact, and why the digest covers exactly what is transmitted
