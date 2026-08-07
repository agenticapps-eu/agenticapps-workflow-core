---
name: openspec-change-review
version: 2.0.0
implements_spec: 1.0.0
description: |
  Step 2b of the workflow. Runs ≥2 adversarial reviewers of OTHER vendors over
  an OpenSpec change BEFORE any code is written, and writes REVIEWS.md. Invoke
  after `openspec validate --all` is green and before the first code edit.
---

# OpenSpec change review — adversarial, before code

Host-neutral. Nothing here names a host; the one host-specific fact — which
vendor is *yours* — you already know, and rule 2 below is how you use it.

## Why this exists when `validate` already runs

`openspec validate --all` is a schema and structure check. It confirms every
requirement has a scenario. It cannot tell you the delta describes the **wrong
behaviour**, that the problem is imagined, or that the solution is merely
plausible. That is what a reader is for, and this runs *before code exists*,
where a fix is cheapest.

The §18 gate does **not** enforce this. It blocks only on validation being red.
Reviewer count and verdicts produce `NOTE` lines and nothing more. So this step
is a discipline you keep — the machine will let you skip it.

## The rule

1. **At least two reviewers**, and they must be **distinct vendors**.
2. **Never your own vendor.** A host must not review its own change. That
   exclusion is *this skill's* job: `reviewer-cli.sh` is one file shared by every
   host and ships every arm, including the one you must not call.
3. **A reviewer that fails, times out, or is absent does not count.** Say so in
   `REVIEWS.md` and run a different vendor. Silently counting an unreachable
   reviewer lets one vendor satisfy a two-vendor rule.
4. **Record the resolved model, not just the CLI name.** A client like
   `opencode` is not a provider — two arms pointed at the same underlying model
   are one opinion wearing two names.

## Procedure

### 1. Resolve the change, and validate it first

```bash
openspec list                       # or: ls -d openspec/changes/*/ | grep -v archive
openspec validate --all
```

Work on exactly one change. Reviewing a change that does not parse spends a paid
reviewer call on a problem `validate` reports for free.

### 2. Build the prompt in a file

It is long; passing it as an argument inline runs into quoting limits.

```bash
CHANGE=openspec/changes/<name>
{
  echo "You are reviewing a proposed software change BEFORE any code is written."
  echo "Be adversarial and specific. Your job is to find what is WRONG."
  echo
  echo "Return, in this order:"
  echo "  1. VERDICT: APPROVE | REQUEST-CHANGES"
  echo "  2. Findings, each as: [SEVERITY HIGH|MEDIUM|LOW] <file/section> — <the problem> — <the fix>"
  echo "  3. Anything the proposal ASSUMES but does not state."
  echo
  echo "Judge: is the problem statement real? Is this solution right, or merely"
  echo "plausible? What breaks that the proposal has not considered? Is the spec"
  echo "delta consistent with the stated intent? Are the tasks sufficient?"
  echo
  echo "=== PROPOSAL ==="; cat "$CHANGE/proposal.md"
  [ -f "$CHANGE/design.md" ] && { echo "=== DESIGN ==="; cat "$CHANGE/design.md"; }
  [ -f "$CHANGE/tasks.md" ]  && { echo "=== TASKS ===";  cat "$CHANGE/tasks.md"; }
  echo "=== SPEC DELTA ==="; find "$CHANGE" -name '*.md' \
      ! -name proposal.md ! -name design.md ! -name tasks.md ! -name REVIEWS.md -exec cat {} +
} > /tmp/change-review-prompt.txt
```

### 3. Run the reviewers through the wrapper

Never call a vendor CLI directly:

```bash
~/.agenticapps/bin/reviewer-cli.sh gemini /tmp/change-review-prompt.txt > /tmp/review-gemini.txt
~/.agenticapps/bin/reviewer-cli.sh codex  /tmp/change-review-prompt.txt > /tmp/review-codex.txt
```

Available vendors come from `AGENTICAPPS_REVIEWERS` (default:
`gemini codex claude opencode`). Adding a vendor is configuration, not a code
change.

The wrapper is not ceremony. Some vendor CLIs read stdin and **hang** without
`</dev/null`. The wrapper pins stdin and bounds the call with `timeout`
(`REVIEWER_TIMEOUT`, default 300s) — *provided a bounding binary exists*. With
neither `timeout` nor `gtimeout` on PATH it warns and runs unbounded, which is
stock macOS; `brew install coreutils` before relying on the bound.

Exit codes: **3** unavailable · **4** timed out · **5** unknown vendor · anything
else is the vendor CLI's own code. Treat *any* non-zero as not counted, and
distinguish 3 from 4 in what you write — "unavailable" sends someone to check
PATH for a CLI that was present and merely slow.

Vendor CLIs print banners and hook logs to stdout, inline with the review.
Sanitising that is **this skill's** job, not the wrapper's.

### 4. Write `REVIEWS.md`

To `$CHANGE/REVIEWS.md`. Writes under `openspec/**` are exempt from the gate, so
this works while the gate is engaged.

```markdown
---
reviewers: [gemini, codex]
models: [gemini-3-pro, gpt-5.2-codex]
verdicts: [APPROVE, REQUEST-CHANGES]
reviewed_artifacts_sha: <sha of the concatenated prompt>
---

# Change review — <slug>

## Reviewer: gemini (gemini-3-pro)
VERDICT: APPROVE
[MEDIUM] design.md — <problem> — <fix>

## Reviewer: codex (gpt-5.2-codex)
VERDICT: REQUEST-CHANGES
[HIGH] spec delta — <problem> — <fix>

## Not counted
- opencode — exit 4, timed out at 300s. Re-run or substitute a vendor.

## Resolution
<For each HIGH and MEDIUM: what you changed, or why you are not changing it.>
```

### 5. Then proceed

Two `REQUEST-CHANGES` verdicts open the gate exactly as two approvals do —
nothing here blocks. So the resolution section is the whole value: an
unaddressed HIGH finding that you recorded and ignored is a decision; an
unaddressed HIGH finding you never read is an accident.

## What this is NOT

- **Not** the code review. That is step 4 and it reads the diff.
- **Not** a substitute for `validate`, nor satisfied by it.
- **Not** a gate the machine enforces. See above.
- **Not** something to run again after code exists — its value is that it is
  cheap to act on now.
