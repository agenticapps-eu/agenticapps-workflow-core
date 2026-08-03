# Tasks

**Read `REVIEWS.md` before starting.** Three reviewers returned REQUEST-CHANGES
and the first draft of this change was wrong about its own cause — it proposed
building a comparison that already exists. The tasks below are the corrected
scope.

## 1. Establish the defect as a test before changing anything

- [ ] 1.1 `tdd="true"` — RED: an install that matches its manifest row while
  differing from the authority must not produce the "This machine is provisioned"
  summary. It does today; that is the defect, and it is reproducible right now by
  pointing `--source-check` at a tree of pre-`f6e4b64` implementations. Record the
  RED output verbatim
- [ ] 1.2 `tdd="true"` — RED: a default run (no `--source-check`) must disclose
  that the currency question was not asked. Today it reads identically to a run
  where it was asked and passed
- [ ] 1.3 The four `stale` sub-cases, each asserted on its **message**, not only
  its verdict — a single "differs" assertion would pass on all four and the
  messages are where the remedy lives: published lower, published higher,
  versions equal with bytes differing, and no authority file for a **declared**
  artifact
- [ ] 1.4 The `unknown` sub-cases, per design Decision 7: path absent, path
  present but holding no declared artifact (**not** an authority checkout — must
  not report every artifact stale), and an unreadable file. Assert
  **specifically that none of them reads as `current`**; asserting only the
  absence of `stale` passes on a silent green
- [ ] 1.5 **Out-of-scope artifacts are not judged.** `openspec-change-gate`,
  `reviewer-cli` and `run-plan-review` share the bin and are published by another
  installer. Assert none of them is reported stale. This is a regression fence: an
  earlier revision of the delta made an absent authority file stale without
  scoping it, and running it flagged exactly these three
- [ ] 1.6 Semver ordering is component-wise numeric — assert `1.10.0` is reported
  **ahead** of `1.9.0`, which a lexical compare inverts, pointing the operator at
  the opposite remedy

## 2. Promote the existing comparison to an axis

- [ ] 2.1 Resolve the authority by default from the tool's own location, which is
  inside core — the gate hook's fixed-point argument. Keep `--source-check DIR`
  as the explicit override and add `--no-source-check`. **Do not add
  `--authority`**: the first draft proposed it and review found it overlapping
  `--source-check` with no conflict semantics
- [ ] 2.2 Judge the **declared** set (`ARTIFACTS`) only
- [ ] 2.3 Verdict on bytes; message from `# <hook>-version:`, reusing
  `semver_cmp` from `project-hook-conformance.sh` rather than a second
  implementation. Where either side has no parseable marker, say the version
  could not be read rather than inventing one
- [ ] 2.4 Emit `CURRENCY current|stale|unknown`, and per-condition remedies per
  design Decision 5 — **not** one universal "re-run the installer", which is
  wrong for a published-ahead version, a lagging authority checkout, and
  `drifted`+`stale` together
- [ ] 2.5 Qualify `current` as *matches this authority checkout*, never *matches
  what core ships*
- [ ] 2.6 Aggregate: any `stale` → `stale`; else any `unknown` → `unknown`; else
  `current`
- [ ] 2.7 Count currency toward `--strict`, and record in the header that this
  makes `--strict` newly able to fail — a real behaviour change, not a pure
  reporting one
- [ ] 2.8 **Install nothing.** No auto-repair, not even behind a flag

## 3. Correct what the old vocabulary is quoted as saying

- [ ] 3.1 The summary stops saying "This machine is provisioned. The shims will
  resolve." unless `complete` + `attested` + `current`. Under `unknown` it names
  the question it did not ask
- [ ] 3.2 `reference-implementations/project-hooks/README.md` — the state
  vocabulary is documented there as a pair. Include the dated observation: a rule
  with a recorded counter-example is harder to quietly re-weaken
- [ ] 3.3 Grep for every other place describing the state as a pair or attaching
  "running as documented" to `attested` alone. Do not assume the two files above
  are all of them

## 4. Verify

- [ ] 4.1 Re-run the five project-hook suites; record before/after counts
- [ ] 4.2 Reproduce against the **real** history rather than only fixtures: build
  an authority tree from `f6e4b64~1` and confirm the machine reports `stale` with
  the right per-artifact messages, then confirm the current tree reports `current`
- [ ] 4.3 `openspec validate --all`, gate `--ci`, gate conformance harness
- [ ] 4.4 Confirm no shim, project, published artifact or manifest format
  changed. A diff that reaches the fleet means something went wrong
- [ ] 4.5 Re-run `run-plan-review.sh` after implementation with
  `REVIEW_TIMEOUT=600`. At the default 180s two of three reviewers time out and
  are silently not counted, which is how this change nearly shipped on one
  opinion
