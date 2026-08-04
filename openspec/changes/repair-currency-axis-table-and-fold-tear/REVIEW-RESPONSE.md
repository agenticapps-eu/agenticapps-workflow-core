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
