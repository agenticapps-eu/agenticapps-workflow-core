Ordered so the test that proves the defect exists is written before anything
that could hide it. §1 must complete before §2 — a fix landed first would make
the RED unobservable, and an unobserved RED is the red flag the discipline
exists to catch.

`tdd="true"` tasks require an atomic `test(RED):` commit whose output shows a
harness exiting **0** on a target it did not score, followed by a
`feat(GREEN):` commit.

Revised after the Stage-2 plan review: three reviewers returned
REQUEST-CHANGES. `--family` exists on **two** harnesses, not three; the
`resolve-core-artifact` and `shared-install` tools are a distinct single-target
shape rather than an exception parked in Open Questions; `scored` needed
defining against `inconclusive`; and unscoreability needed three independent
conditions rather than one. See `REVIEWS.md` and design Decisions 2–5.

## 1. Pin the defect

- [x] 1.1 `tdd="true"` — write `tools/conformance-harness-reporting.test.sh`,
      following the `drift-report.test.sh` naming precedent. It tests core's own
      tools, so it is a test, not a conformance harness (those score *host*
      artifacts)
- [x] 1.2 Row: a named target that does not exist → non-zero, in both shapes
- [x] 1.3 Row: a named target that is zero-byte → non-zero, and NOT scored as
      rows. This is the false-green condition: an empty script exits 0 and
      passes every `expect 0` row
- [x] 1.4 Row: a named target that is a directory → unscoreable. `[ -s ]` alone
      accepts one
- [x] 1.5 Row: a named target that is non-empty but unreadable → reported
      unscoreable, NOT reported as having failed rows. Asserts legibility, not
      false-green: `bash` on such a file exits 126, so its rows already fail
- [x] 1.6 Row: three named targets to a multi-target harness, middle one absent
      → first and third scored in full, exit non-zero. Guards against fixing
      1.2 with an `exit 2` abort
- [x] 1.7 Row: a single-target harness aborts non-zero naming the target and
      reason, and is NOT required to grow a tally
- [x] 1.8 Row: a run whose rows are all inconclusive → non-zero. Scored total is
      passed + failed, so this trips the backstop
- [x] 1.9 Row: a run that scored zero rows via a route other than 1.2–1.5 →
      non-zero, so the backstop is tested independently of the per-site fixes
- [x] 1.10 Row: an unscoreable target and a row-failure in one run are reported
      distinguishably, with the unscoreable one naming which of the three
      conditions held
- [x] 1.11 Row: roster mode prints `scored N of M` on a **complete** sweep, not
      only a narrowed one
- [x] 1.12 Row: roster mode with an entry absent → names it and the reason,
      exits on the merits of the rest
- [x] 1.13 Row: roster mode with an entry present but zero-byte → reported not
      scored with emptiness as the reason, does not by itself fail the run
- [x] 1.14 Row: roster labels are stable logical names, containing no `$HOME`
      and no absolute workspace path
- [x] 1.15 Row: whole roster absent → non-zero
- [x] 1.16 Row: overlapping unscoreable conditions (a broken symlink is
      non-regular, empty and unreadable at once) report the first reason in the
      order regular / empty / readable
- [x] 1.18 Row: roster mode + an explicit path in one invocation → usage error,
      scores nothing. Currently the explicit path is silently discarded
- [x] 1.19 Row: whole roster absent → coverage line `scored 0 of M` IS printed
      and the exit is NOT the usage error. Both current builders take the usage
      path here, so exit-code-only assertions pass for the wrong reason
- [x] 1.20 Row: a roster entry counts toward the numerator only if it
      contributed ≥1 scored row — otherwise `scored 6 of 6` is reachable with a
      scored total of zero
- [x] 1.21 Row: no absolute path appears anywhere in roster-mode output,
      including the per-entry `═══` heading (`change-gate-conformance.sh:306`)
- [x] 1.22 Row: a target path containing a newline or control character cannot
      forge a line resembling a PASS
- [x] 1.23 Row: default `--family` reports a pin-and-resolve host as
      *resolvable, not attempted*, distinguishably from *not found*
- [x] 1.24 Row: `--family --resolve` scores a resolvable entry, and reports a
      resolve failure as a resolve failure rather than as an absent artifact.
      Drive the failure with an unreachable source rather than a real network
      outage, so the row is hermetic
- [x] 1.25 **Observe RED.** Run against all five harnesses unmodified; record
      output in `evidence/`. Expectations are NOT uniform, and asserting they
      were is a defect a reviewer caught in the first draft of this plan:
      - `change-gate` and `run-plan-review` MUST fail the named-absence rows —
        this is the reported bug
      - `reviewer-cli` and both single-target harnesses MUST **pass** the
        named-absence rows — they are already correct, and a RED there would
        mean the row is wrong, not the tool
      - all five MUST fail the three-condition rows, and the two roster
        builders MUST fail the coverage rows
      Record the expected verdict per harness per row group BEFORE running, so
      the run confirms a prediction rather than being read after the fact

## 2. Fix the multi-target harnesses

- [x] 2.1 `tdd="true"` — `change-gate-conformance.sh`: move the absence check
      off the entry-point loop into `score_gate`, counted as a failure, per
      `reviewer-cli-conformance.sh:169`
- [x] 2.2 `tdd="true"` — `run-plan-review-conformance.sh`: same fix, same line,
      same shape
- [x] 2.3 `tdd="true"` — replace every `[ -f ]` target check with independent
      regular / non-empty / readable tests that report which condition held
- [x] 2.4 `tdd="true"` — coverage line in the two roster builders
      (`change-gate-conformance.sh:868`, `reviewer-cli-conformance.sh:224`):
      `scored N of M`, every unscored entry named with its reason, on every run.
      Logical labels only
- [x] 2.5 `tdd="true"` — move the roster's absence filter AFTER the argument
      count check so a fully-absent roster prints coverage instead of a usage
      error. This is the `set --` / `[ -f ] && set -- "$@"` shape at
      `change-gate-conformance.sh:870-878` and `reviewer-cli-conformance.sh:226-231`
- [x] 2.6 `tdd="true"` — logical labels across ALL roster output, including the
      per-entry `═══ $GATE` heading at `change-gate-conformance.sh:306`. The
      coverage line alone leaves `$HOME` in the log on every run
- [x] 2.7 `tdd="true"` — sanitize control characters and newlines from every
      echoed target path, on both the roster and explicit-path sides
- [x] 2.8 `tdd="true"` — reject roster flag + explicit paths with a usage error
      instead of discarding the paths
- [x] 2.9 `tdd="true"` — `--resolve`: opt-in, default off. **Fully implemented in
      `change-gate-conformance.sh`; `reviewer-cli-conformance.sh` implements the
      REPORTING half only (`resolvable, not attempted`) and has no `--resolve`
      flag. §20 makes the resolving mode a SHOULD, not a MUST, so that is
      conformant — recorded here rather than ticked silently.** Original text: Default mode reports a
      pin-and-resolve entry as *resolvable from pin, not attempted*; `--resolve`
      fetches via the host's `bin/resolve-core-artifact.sh` +
      `tools/core-vendor.manifest` and scores it. A failed resolve is reported
      as a resolve failure, never as an absent artifact
- [x] 2.10 `reviewer-cli-conformance.sh`: its explicit-path site MUST NOT change
      — it is the reference the others were fixed against. Roster builder only

## 3. Fix the single-target harnesses

- [x] 3.1 `resolve-core-artifact-conformance.sh` and `shared-install-conformance.sh`:
      extend the existing absence guard to the three conditions and name the
      reason. `exit 2` and the abort-on-absence behaviour are preserved per
      design Decision 2 — they are conformant, not exceptions
- [x] 3.2 Confirm no tally is introduced. The delta explicitly permits a
      single-target harness to satisfy the backstop by aborting before any row

## 4. The backstop

- [x] 4.1 `tdd="true"` — all five: a run terminating with a scored total of zero
      exits non-zero and says on stderr that it certified nothing
- [x] 4.2 Assert scored = passed + failed in the two harnesses tracking
      `inconclusive`, so an all-inconclusive run trips it
- [x] 4.3 Fold the backstop INTO the existing `[ "$fail" -eq 0 ]` terminal
      expression rather than adding a branch beside it, so the exit code stays
      computed in one place (design Decision 8 reconciles this with Decision 6)
- [x] 4.4 Build the all-inconclusive test seam. `run-plan-review-conformance.sh:256`
      emits INCONCLUSIVE when the gate is absent beside the producer, which is a
      realizable fixture; confirm the seam exists before writing the row, since
      a reviewer flagged it as possibly untestable
- [x] 4.5 **Observe GREEN.** Re-run §1 against all five; every row passes

## 5. Close the spec gap

- [x] 5.1 Add the harness-reporting requirement as a new spec section typed
      `section_type: core-tooling-contract`. NOT §09 (`framing` — normative
      SHALL text is a category error there) and NOT `declarative-contract`,
      which §00 defines as where *host* requirements live
- [x] 5.2 Delta §00's framing sentence ("the requirements live in the
      canonical-prose and declarative-contract sections that follow") to
      acknowledge the new type and state that it binds core's tooling, not hosts
- [x] 5.3 Delta §09 to state that `core-tooling-contract` sections form no part
      of any host's conformance claim at any level, so a host reading the spec
      is not silently conscripted
- [x] 5.4 State the scope explicitly in the section body as well: it governs
      core's `tools/` harnesses. The first draft's unqualified "a conformance
      harness SHALL…" is what condemned two conformant tools
- [x] 5.5 Name `tools/drift-report.sh` as out of scope and why — advisory by
      contract, `exit 0` unconditionally at `:257`, so it certifies nothing a
      false green could corrupt
- [x] 5.6 Bump `spec_version` in `spec/00-overview.md` and write the CHANGELOG
      entry. Classify explicitly: additive requirement on core's own tooling
      plus a new section type, so **minor** — no host's existing conformance
      claim is invalidated
- [x] 5.7 ADR under `adrs/`: three behaviours across five harnesses, why named
      and roster absence resolve differently, and why the expected-absence
      allowlist was rejected (design Decision 5) — it is attractive enough to be
      re-proposed, and why resolving a pinned entry is opt-in (Decision 9)

## 6. Verify against reality

- [x] 6.1 Run `--family` for real. Assert it reports `scored 4 of 6` naming
      `claude-workflow` and `codex-workflow` — the live case that motivated the
      change
- [x] 6.2 Confirm the four present gates score exactly as before, row for row.
      This change must not move a single conformance verdict; if it does,
      something other than reporting changed
- [x] 6.3 Run every harness against its real targets; confirm nothing
      previously green went red for a reason other than unscoreability
- [x] 6.4 `superpowers:verification-before-completion` — paste the RED output,
      the GREEN output, and the live coverage line as evidence

## 7. Review and land

- [x] 7.1 Re-run `run-plan-review.sh` after the artifact revisions, so the
      review on record describes the shipped plan rather than the first draft
- [ ] 7.2 `superpowers:requesting-code-review` in an independent context.
      `openspec validate` is a spec check and does not discharge this
- [ ] 7.3 Address findings, then `/opsx:archive`
- [ ] 7.4 `superpowers:finishing-a-development-branch` → PR. The body names the
      downstream breakage from the proposal's Impact explicitly, so the first
      host CI that goes red has a written explanation waiting for it
