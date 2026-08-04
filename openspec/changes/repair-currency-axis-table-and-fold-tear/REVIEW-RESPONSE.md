# Review response — round 1

Reviewers: gemini (REQUEST-CHANGES), codex (REQUEST-CHANGES), opencode (APPROVE).
Claude excluded as the declared implementing host. Three counted, floor is one,
two preferred.

Two REQUEST-CHANGES verdicts. The gate does not block on them and did not; they
are addressed here because a `NOTE` naming objectors is meant to be answered.

---

## 1. The placement check is ephemeral — ACCEPTED (all three reviewers)

> gemini: "this check should be implemented as an automated test that runs
> alongside existing validation, not just used as a one-time verification"
> codex: "D5 promises durable 'new machinery,' but Impact says no code/tests …
> Name and integrate a persistent placement test, or remove the claim"
> opencode: "once archived, nothing guards the next fold"

All three converged on this independently, and they are right. The design
claimed a durable mitigation while the tasks described assertions an executor
runs once and throws away. Those are not the same thing, and the gap was mine.

**Done:** `tools/spec-placement.test.sh` is committed and wired into
`.github/workflows/openspec-gate.yml` beside the other conformance tests. It
sweeps **every** spec in `openspec/specs/`, not just this capability, and it
asserts the currency-clause parity directly. The change's Impact section no
longer says "no code"; it now names the test.

Of the three options — commit the check, or delete the durability claim, or
leave it — deleting the claim was the cheaper honest fix and was rejected: the
fold that caused this defect is not specific to this capability, so the check
has value beyond the repair.

## 2. Other four specs are unswept technical debt — ANSWERED WITH EVIDENCE

> gemini: "The existence of similar, undiscovered defects in the other four
> specs should be filed and tracked as technical debt."

Filing it was unnecessary — it was cheaper to just run it. All five specs are
now swept:

```
ok    openspec/specs/change-gate-enforcement/spec.md
ok    openspec/specs/conformance-harness-reporting/spec.md
ok    openspec/specs/core-self-enforcement/spec.md
ok    openspec/specs/plan-review-production/spec.md
FAIL  openspec/specs/project-hook-binding/spec.md   ← this change repairs it
```

The other four are clean. `project-hook-binding` carries the only tear in the
repo, so there is no debt to track — and because the committed test runs over
the glob rather than a fixed path, a future spec is covered on the day it is
added. The design's caveat has been updated from "unswept" to this result.

The honest limit stands and is recorded in `design.md`: this detects tears at
*paragraph boundaries*. A fragment relocated as a whole, grammatically intact
paragraph would pass, and only a reader would catch it.

## 3. `current` / `unknown` cross-product ambiguity — DECLINED, premise is wrong

> codex: "with zero present artifacts and an unreadable/non-authority checkout,
> `current` is vacuously true while `unknown` is also true. The implementation
> returns `unknown`. **Specify precedence** or require a readable authority for
> `current`, and add this cross-product scenario."

Codex's reading of the behavior is correct; its claim that precedence is
unspecified is not. The spec states it twice, in the requirement codex is asking
to amend:

- `spec.md:986-987` — "Aggregation: any `stale` makes the machine `stale`,
  otherwise any `unknown` makes it `unknown` — a known finding outranks an
  unasked question."
- `spec.md:998` — "`unknown` SHALL NOT be reported as `current`."

And `provisioning-check.sh:490-494` implements exactly that order:
`stale` → `unknown` → `current`. So the case codex describes resolves to
`unknown` *because the spec requires it to*, not by accident. There is no
ambiguity to remove.

Declined on a second ground as well: adding a cross-product scenario is a new
normative question about a requirement this change does not otherwise touch.
The previous session refused to smuggle a normative change into a refactor; the
same discipline forbids widening this repair because a reviewer raised an
adjacent topic. If the cross-product deserves a scenario, it deserves its own
change.

## 4. Task 1.2 is not executable as written — ACCEPTED IN PART

> codex: "`run-plan-review.sh` is not available from the repository PATH,
> requires `--implementing-host`, and defaults to one reviewer rather than the
> required two."

The first two are correct, and I hit both before codex reported them: the runner
lives at `~/.agenticapps/bin/run-plan-review.sh`, and invoking it without
`--implementing-host` exits with *"the implementing host is required and has no
default"*. Task 1.2 now carries the full path and the flag.

The third is wrong. The runner does not default to one reviewer — it fanned out
to all four configured vendors, excluded claude as the declared implementing
host, and counted three. That is this file's own provenance. No `MIN_REVIEWERS`
setting was needed and none was added.

## 5. Enumerate the hunks rather than count them — ACCEPTED

> opencode: "the task doesn't say which hunks; the executor should enumerate
> them in the apply evidence"

Task 2.4 now names all three: the table cell, the three lines restored to
requirement one, and the three lines plus blank removed from requirement two.

## 6. Residual tension in the cell header — NOTED, NO CHANGE

> opencode: "The row still opens 'judged over the **declared** artifact set
> only' while both clauses are now presence-scoped … Acceptable as-is; flagging
> because this cell has already produced one such misreading."

Concur on both halves, including that it is not a contradiction: "only" scopes
*declared vs. undeclared*, which is orthogonal to present vs. absent. Rewriting
the header would enlarge a normative diff that is currently one clause, on a
cell whose last edit is the defect being repaired. Left alone deliberately,
recorded here so the next reader knows it was considered rather than missed.

---

## Defect found while acting on this review

Writing the check in §1 surfaced a bug in the check itself, worth recording
because it is the same failure mode a third time.

The first version excluded lines beginning with a backtick from the
"paragraph ends mid-sentence" signature — intended to skip code fences, which
the fence tracker already handles. The torn line this whole change exists to
repair is:

```
`CLAUDE.md` went 0644 in and **0600** out, and `DELETE FROM public.users` was
```

It opens on a code span. **The check was blind to its own motivating case** and
still reported RED, because the *other* signature happened to catch the orphan
at line 927. A test that passes for the wrong reason is the thing this change is
about. Fixed, and the reason is a comment in the script so it is not
reintroduced.

---

# Review response — round 2

Re-run after the round-1 changes. gemini **APPROVE** (was REQUEST-CHANGES);
codex **REQUEST-CHANGES** again, with sharper points; opencode rejected by the
runner for emitting no verdict line, so it is uncounted — not a failure of the
change.

Three of codex's four are correct and are fixed. One is a vocabulary collision
in the workflow doc rather than a defect.

## 1. The test cannot be green before the fold — ACCEPTED, and the best catch

> codex: "the placement test scans canonical `openspec/specs/`, yet it must
> become green before `openspec archive` folds the repair there. Reorder the
> archive/check steps."

Correct, and it invalidated the task order. `openspec archive` is what folds a
delta into the spec slot — that is how the *previous* change reached `specs/`
(`db02493` implemented, `09f829e` folded). My §2 said "apply the delta to the
spec slot" as a hand step before archive and §3 claimed GREEN before §4 archived.
Both were wrong: hand-editing the slot pre-archive would double-apply at fold
time, and the test reads the slot, so it cannot pass until the fold happens.

Restructured. §2 lands the guard and states plainly that it is **RED until 4.2**,
CI red by design in that window; §4 archives, which is what performs the repair;
§5 verifies GREEN afterwards. The Migration Plan now records the same ordering,
because it is the kind of fact that reads as a broken build to someone who
arrives mid-branch.

## 2. Stage-2 vs Stage-3 review labelling — COLLISION, wording fixed, semantics kept

> codex: "Task 4.1 incorrectly requests another 'Stage-2 review' after
> implementation … Stage 2 is pre-code; this should be the Stage-3 code-review
> gate."

Codex read the lifecycle numbering, where stage 2 is `validate` and pre-code. The
workflow also uses "two-stage review", where stage 1 is the plan review and
stage 2 is the independent **code** review — and its own verification check
greps the change dir for the literal string "Stage 2" to prove the code review
happened. Both readings are supported by the document, which is the actual
problem.

The task no longer says "Stage-2". It now names what it is — an independent code
review in a cleared session, the Stage-3 execute gate, distinct from the plan
review in §1 — so neither reading can misfire. The gate it satisfies is
unchanged.

## 3. "Spec-only" and "no code changes" are no longer true — ACCEPTED

> codex: "The design calls this 'spec-only,' 'no code changes,' … despite adding
> a shell test and a CI failure condition."

Correct, and self-inflicted: those claims were written before round 1 added the
test, and I updated the proposal's Impact without going back to the design's
Non-Goals and Migration Plan. Both now say what is true — behavior is unchanged
and `provisioning-check.sh` is untouched, but the change adds a test and a CI
step that can fail the build.

## 4. The success message overclaims — ACCEPTED, and thematically exact

> codex: "The placement test is only heuristic, but its success message claims
> every paragraph is whole … narrow the claimed guarantee."

The message read *"PASSED — every paragraph is whole and the currency clauses
agree."* The script cannot know that. It detects tears at paragraph boundaries;
the design says so explicitly two sections above, and the message contradicted it.

This is the change's own subject matter turned on the change: a check whose
report claims more than it verified. The fleet has now produced that failure six
times, and I produced the seventh while fixing the sixth. The message now states
scope rather than conclusion:

```
PASSED — no torn paragraph boundary found, and the currency clauses agree.
         Scope: paragraph-boundary tears only. A grammatically intact
         paragraph moved to the wrong requirement passes this check.
```

That is the same rule the override scan follows — *no known vector found* rather
than *the repository is clean* — which this capability's own spec already
requires of reports. The test now obeys the spec it guards.

## Standing objection

None outstanding. Codex's remaining note ("the normative qualifier and verbatim
restoration are otherwise correct and minimal") agrees with gemini and with
round 1's opencode approval. The round-1 decline on `current`/`unknown`
precedence stands and was not renewed.
