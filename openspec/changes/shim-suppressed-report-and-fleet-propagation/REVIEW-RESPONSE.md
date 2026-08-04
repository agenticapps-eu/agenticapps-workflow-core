# Response to Stage-2 plan review, round 1

Three reviewers ran before any code: gemini (APPROVE), codex (REQUEST-CHANGES),
opencode (REQUEST-CHANGES). Every finding was verified against the repository
before it was accepted or declined. Nine accepted, none declined outright, one
narrowed.

## The finding that grew — codex 1

**Claim:** core's self-hosting binder is omitted; `--fleet` excludes core, so it
can report zero while `.claude/hooks/openspec-change-gate.sh` stays at 1.1.0.

**Verified, and it is worse than stated.** `head -8` on that file shows
`# shim-contract: 1.1.0`, and `FLEET` says in its own comment that core is
excluded from `--fleet` deliberately. So the change's acceptance criterion —
"`--fleet` reports 0" — was structurally incapable of seeing the authority
repo. That is the lineage's recurring failure in the verification step of a
change written about that failure.

Following it into the file found a **live violation of the rule this capability
publishes**. On an unresolvable gate, core's binder does:

```
printf 'openspec-gate: WARNING — gate not found at %s; this edit is not gated.\n' "$GATE" >&2
exit 0
```

`spec.md:611-615` states that a `PreToolUse` hook exiting 0 has its stderr
discarded from the transcript, so "a shim exiting 0 with a warning on stderr
therefore warns nobody" — and `spec.md:251-253` puts core's copy explicitly in
scope for the fail-open-and-report rule while exempting it only from the
resolution-order clauses. The authority repo has been shipping the exact
construction its own spec names as the defect, at 1.1.0, invisible to the
instrument.

**Accepted, and the change grows to cover it:** core's binder is bumped to
1.2.0, its `exit 0` becomes a non-blocking error code with a report, and
verification scores core as an explicit positional argument rather than relying
on `--fleet`.

## Accepted without qualification

- **codex 3 — the invariant is overbroad.** After `exec` the process is the
  implementation, and its exit is not the shim's to constrain; a stderr write can
  also fail. Scoped to shim-generated exits before `exec`.
- **codex 5 — matcher instruction would cause a regression.** Each repo has
  several matchers; the gate's is `Edit|Write|MultiEdit|NotebookEdit`. "Update
  the `settings.json` matcher to `Bash|Edit|Write|MultiEdit`" applied literally
  would strip `NotebookEdit` from the gate. Scoped to the `database-sentinel`
  entry only.
- **opencode 1 — the event-class gap.** The invariant is argued entirely from
  `PreToolUse` rendering, and `normalize-claude-md` is `PostToolUse`, whose
  channel this capability records as unverified. Generalising across event
  classes is what `spec.md:617-627` forbids by name. The invariant is now scoped
  to classes with a verified channel, and the unverified class is named.
- **opencode 2 — the audit scenario contradicted the capability.** "A path that
  cannot write stderr is changed to exit 0" could be read as licence to make the
  unresolvable-implementation path exit 0, which is the silent fail-open this
  capability rejects, and would defeat the change from inside its own spec. Now
  bounded: exit 0 only where no announcement obligation exists, never for a
  fail-open that loses protection.
- **opencode 3 — the acceptance criterion did not cover the matcher fix.**
  Verified: `project-hook-conformance.sh` reads `settings.json` only for override
  env vectors (`:306-309`), never for matchers, and no other tool in `tools/`
  reads them at fleet scope. One of the two shipped behaviour changes had no
  check. A per-repo matcher assertion is now its own task.
- **opencode 4 — the marker-write-failure fork.** If `mkdir`/`printf` fails, today
  every call reports in full. That is the right behaviour and it was unstated, so
  an implementer could have "fixed" it either way. Now specified as fail-loud,
  with a test.
- **codex 4 — marker written before the report.** Reordered to report-then-mark,
  so a suppressed line can never claim a full notice that was never emitted.

## Accepted as narrowed

- **codex 2 — the `agents-task-viewer` third candidate.** Verified: that repo does
  carry `bin/openspec-change-gate.sh` (17k), and its current unmarked shim falls
  back to it. Conversion to the two-candidate contract shim removes that
  fallback, which is what the contract requires — `spec.md` calls a repo-local
  copy "the drift the shim exists to remove". So the removal stands. What the
  review is right about is that it must not happen blind: the shared install is
  verified present before conversion, and the orphaned 17k copy is disposed of
  explicitly rather than left as dead code that nothing invokes and nothing
  reports.

## Accepted as wording

- **opencode 5 — bucket, not interval.** `epoch/3600` is a wall-clock bucket, so
  "earlier in the interval" is imprecise at boundaries. The suppressed line and
  the spec now say **this hour**, which is what the arithmetic means.
- **opencode 6 / design open question — the `add-agent-board` checkout.** One
  sentence added rather than silence: its hooks do fire when that worktree is
  used, and the README's re-measurement counted it among the defective copies.
- **gemini 1 — canonical content for the suppressed line.** The spec now names
  what the line must carry (hook, unchanged state, that the call was allowed, and
  a reference to the full notice) rather than only requiring that a line exist.

## Noted, not changed

- **gemini 2 — marker race.** Two hooks racing on the marker can produce at worst
  one extra full report or one extra suppressed line, neither of which loses a
  signal. Locking a hook that must stay behaviour-free costs more than the
  failure. Recorded in `design.md` rather than mitigated.
- **opencode's `:613` vs `:614`** — the off-by-one is real and cosmetic; citations
  corrected in passing.

# Response to Stage-2 plan review, round 2

Two counted reviewers, both REQUEST-CHANGES; opencode timed out at 180s and is
recorded as failed rather than silently dropped. Eight findings, all accepted.
Two of them found instrument defects that the round-1 revision had recorded as
acceptable caveats — the review was right that recording them was not enough.

## The instrument could report zero on a repo with no shims at all

**codex round 2, verified.** `project-hook-conformance.sh:195` and `:265` are
both `[ -f "$shim" ] || continue`. A declared hook with no shim file is skipped
on the marker axis and on the identity axis, so it contributes nothing to the
total. A project that lost its shims scores identically to one that is current.

This is the **same `|| continue` shape** as the currency-table defect repaired in
this repo on 2026-08-04, in a different tool. Second occurrence, so the response
is the shape rather than the instance: absence is reported on both axes, and a
declaration distinguishes `agents-task-viewer`'s argued opt-out from a deletion.
Without that declaration the instrument must either report both or neither, and
the previous behaviour chose neither.

## A caveat is not a check

Round 1 recorded "no instrument reads matchers" in the design and made the
matcher assertion a manual task. Both round-2 reviewers rejected that, and they
are right on this change's own terms: its thesis is that a check must not be
cited beyond what it can see, so shipping an uncheckable half with a note
attached reproduces the failure at one remove. The instrument is extended
instead, with the negative case tested — a check that catches a missing
`MultiEdit` but would pass a gate entry stripped of `NotebookEdit` licenses the
regression it was added to prevent.

## Accepted without qualification

- **codex — core is not genuinely scored by the tool.** Verified at `:268`:
  positionally the check reads core's marker and then exempts byte identity as
  out of profile. It never exercises the fail-open path. Task 7.2 overclaimed;
  7.2a now states what the tool establishes and cites the behavioural test and
  the live run for the rest.
- **codex — `PostToolUse` wording still generalised.** The scoping paragraph was
  added in round 1 but the scenarios still promised the operator "sees" a notice
  and that a call "was allowed". Neither is true of a post-tool hook, where the
  call has already completed. Scenario wording is now class-aware.
- **codex — tests asserted existence, not content.** A non-empty first line
  satisfied the invariant, so a suppressed message with none of the four required
  fields would have passed. The content assertion is now its own task.
- **codex — the rollout lifecycle contradicted itself.** Core merges first,
  propagation evidence exists only afterwards, and one PR cannot be both. Split
  into core PR 1 and core PR 2, with the archive in PR 2 — archiving before the
  evidence exists would fold a delta whose central claim is unverified.
- **codex — the unwritable-marker rule was underspecified.** It now binds the
  recording step only: a report that could not be recorded does not suppress the
  next one, while a marker written earlier and later unwritable suppresses
  normally. The two look identical at the call site and only one is a lie.
- **gemini — no test for the inverse anti-pattern.** Exit 0 *with* stderr is what
  core's binder did. Added as its own test so it cannot return.
- **gemini — the opt-out rationale needs a durable home.** Relocated to an ADR in
  `agents-task-viewer` rather than `CLAUDE.md`, which tooling rewrites and hands
  trim. Not `settings.json`: it is strict JSON and cannot carry the comment.
