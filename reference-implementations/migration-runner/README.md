# migration-runner — reference implementation

The reference implementation of [§08's "Executable form"](../../spec/08-migration-format.md)
(spec_version 2.0.0): the fenced-block dispatch format that lets a migration's
four (or five) sections be run by a machine instead of read by a human,
without giving up the prose form that every migration below a host's
threshold still uses.

Three scripts, composed as a pipeline:

| Script | Role |
|---|---|
| `extract.sh` | pulls role-tagged fenced blocks out of a migration document |
| `lint-migration.sh` | enforces the executable format (L0–L8 below) |
| `run-migration.sh` | lints, then dispatches a migration's steps |

**`extract.sh` is a library plus a CLI. It is called as a subprocess — `bash
"$EXTRACT" steps|roles|block ...` — never sourced.** Both `lint-migration.sh`
and `run-migration.sh` shell out to it rather than `source`ing its functions.
This is deliberate, not an oversight: sourcing would share `extract.sh`'s awk
helper functions and any variables it sets into the caller's own shell state,
which is exactly the kind of cross-script coupling §08's own "each block
executes in its own shell" rule (Non-mutation and diagnostics) forbids one
layer down, between *steps*. Keeping the boundary a subprocess call, with a
document path and (for `roles`/`block`) a step number as the only inputs,
means `extract.sh`'s internals can change without either caller's shell state
being at risk, and it means the extractor's own bugs can't leak a `local`
that was never `local` into a caller that assumed otherwise. Every invocation
also re-reads `$DOC` fresh from disk — nothing is cached — which is what lets
`run-migration.sh` notice a document that changed shape mid-run (see
`0046-apply-dropped-by-step1.md`).

## The five roles

At or above a host's declared threshold, each step's four §08 sections must
be backed by a role-tagged fenced block:

| Role | Heading it MUST follow | Required per step |
|---|---|---|
| `check` | **Idempotency check:** | exactly one |
| `precondition` | **Pre-condition:** | exactly one |
| `apply` | **Apply:** | exactly one |
| `verify` | **Verify:** | at most one (optional) |
| `rollback` | **Rollback:** | exactly one |

The prose headings are retained, not replaced — they already carry the
document's readable structure. The role tag adds the one thing a heading
cannot express: that a given fence is, or is not, meant to run.

**Info-string grammar**, exact, no exceptions:

```
^bash[ \t]+role=[a-z]+$
```

The literal word `bash`, one or more spaces or tabs, the literal `role=`, a
lowercase role name, then nothing but the fence's own trailing whitespace. A
fence carrying an extra key (` ```bash role=apply retry=2 `), a non-`bash`
language (` ```yaml role=apply `), wrong case, or any other trailing content
is not a valid tagged fence and is rejected — "close enough" is never honoured
silently (L5, below). A ` ```bash ` fence with no `role=` at all is
illustration: never executed, never counted toward a step's roles. That is
what lets a migration show a contrasting or explanatory snippet next to the
commands it actually runs (see `0016-conformant.md`'s Step 1, which does
exactly this).

## The linter — L0 through L8

`lint-migration.sh` runs nine *numbered*, per-step-or-per-fence rules. All
are described in more depth in the script's own header comment; this table
is the index. It also reports three whole-document violation classes that
are not part of this numbering at all — those are covered separately, in
"Whole-document checks and the opt-in mechanism" below.

| Rule | Catches |
|---|---|
| **L0** | `migration_format:` frontmatter present but not the literal value `executable` |
| **L1** | a step missing one of `check` / `precondition` / `apply` / `rollback` (presence only — a duplicate of any role, including a second `verify`, is L3's job, not L1's) |
| **L2** | a role-tagged fence sitting under the wrong heading (e.g. `role=apply` following **Rollback:**) |
| **L3** | any role appearing more than once within a step |
| **L4** | a `role=` value that is not one of the five valid roles |
| **L5** | a `role=` info string that doesn't match the exact grammar above, on *any* fence — not just fences already recognised as tagged |
| **L6** | steps not numbered consecutively from 1 |
| **L7** | a fence opened and never closed before end of file |
| **L8** | a tagged fence whose captured body is empty or whitespace-only, for any of the five roles |

Six of the nine were designed in from the start (L1, L3, L5, L6 as
structural rules; L0 and L2 as the frontmatter/heading checks that go with
them). **L4, L7, and L8 were not designed in — each was found by a review
round, each because a migration that looked fine would have linted clean and
done nothing:**

- **L4 exists because a misspelled role is indistinguishable from an
  illustration fence.** `role=applyy` (or `role=Apply`, or any value that
  isn't one of the five) is a `bash` fence with a `role=` key — syntactically
  a tagged fence — but semantically nothing, because no dispatcher recognises
  that role. Before L4 existed, `bad-l4-typo-role.md`'s equivalent fixture
  linted clean at exit 0: the typo silently demoted a real command to a
  comment, the migration reported success, and had done nothing. L4 is what
  makes an unrecognised role name a violation instead of a shrug.
- **L7 exists because a step's roles are read from a fence's *opening*
  line, but a runner can only ever execute a fence's *closing* line as the
  end of its captured body.** `extract.sh`'s `mr_roles` reports a role the
  instant it sees `` ```bash role=apply `` — it doesn't wait for the closing
  fence. `mr_block`, which `run_block` actually calls to get a body to
  execute, only confirms a match once it reaches the *closing* `` ``` ``. An
  unclosed fence is therefore visible to the first check and invisible to the
  second: the document lints clean (every required role is "present"), and
  then fails at runtime reporting a role "missing" that the linter just
  confirmed was there. L7 closes that asymmetry by rejecting an unclosed
  fence as its own, distinct violation, before a runner ever gets to be
  surprised by it.
- **L8 exists because a tagged-but-empty check fence is a silent no-op that
  reports success.** `bash -c ''` — and a fence containing only blank lines —
  exits 0. The three-valued `check` contract (below) reads exit 0 as "already
  applied." So a `role=check` fence with nothing in it makes the runner print
  `step N: skipped (already applied)` and apply nothing, on a tree where
  nothing was ever applied — at exit 0. This was reproduced against the real
  CLI (`0049-bad-l8-empty-check.md`, `0050-bad-l8-empty-precondition.md`)
  before L8 was written: the tagged-but-empty fence is not hypothetical, it
  runs clean today without this rule. L8 checks every role, not just
  `check` — an empty `precondition` passes just as vacuously, for the same
  reason.

## Why the runner lints before executing

Rejecting a bad migration at lint time is not sufficient on its own, because
nothing obliges the operator to have linted first. A runner that will
dispatch whatever it is handed can be given an all-illustration document —
every fence un-annotated, or every role tag typo'd into invisibility — and
report success having changed nothing. That is the exact silent-no-op class
this whole format exists to prevent, and it is worst when the step silently
skipped was the security-relevant one. `run-migration.sh` therefore:

1. Asks `lint-migration.sh --scope-only` whether the document is even in
   scope for the given host (below-threshold, non-opted-in documents are
   *not examined*, which is not the same as *examined and found
   well-formed* — a runner that conflated the two could have a migration
   renamed to a low number to evaporate the whole gate).
2. Runs the full lint and aborts on any violation.
3. Aborts if the document yields zero steps, or if any step's `apply` block
   is absent or captures as empty — even a tagged one.

None of this is optional or bypassable through the CLI; there is no
environment-variable escape hatch (an earlier fix round added one for
testing and a later round removed it, because anything upstream of an
invocation — a CI `env:` block, a wrapper script, `.envrc` — can set an
inherited environment variable, and a bypassed run is byte-identical to a
real one with nothing to grep for).

**`--host` is required, with no default.** An optional threshold looks
harmless and reopens the same hole one layer down: with no threshold
resolvable, nothing is in scope for the linter, the lint passes trivially,
and a runner that lints-before-executing would then execute anything at all.
A missing `--host` is a usage error (exit 64), checked before the script
ever looks at the filesystem — there is no "no threshold given" path that
treats an absent threshold as an empty scope.

## Exit-code scheme

| Code | Meaning |
|---|---|
| `64` | usage error — the runner itself was invoked wrong (missing `--host`, bad `--on-failure`, an unresolvable `--host`/`--threshold`) |
| `65` | every pre-execution refusal — a lint violation, an out-of-scope document, a zero-step document, or a step with no `apply` block. Nothing has executed; the tree is guaranteed untouched |
| `66` | the named document does not exist or cannot be read |
| `1` | a failure once execution has begun (a step's `check`/`precondition`/`apply`/`verify`) — earlier steps may already have applied |

Refusal (`65`) and post-execution failure (`1`) are deliberately different
codes for one reason: **a caller cannot otherwise tell "refused, the tree is
untouched" from "ran partway, the tree may have changed" without parsing
stderr.** A CI job, a wrapper, or an operator deciding whether it's safe to
retry needs exactly that distinction, and needs to get it from `$?` alone —
parsing diagnostic text to recover it is fragile in exactly the way an exit
code is supposed to not be. This is deliberately *one* shared refusal code,
not one per refusal kind: the only load-bearing question upstream of the
runner is "did anything run at all", and a distinct code per refusal kind
would answer a question nobody needs answered that way.

## Failure policy (apply/verify only)

`precondition` failures and a `check` exiting outside `{0,1}` always
hard-abort, unconditionally, regardless of whether a terminal is attached —
they mean the migration's assumptions about the tree don't hold, or that its
own idempotency check couldn't even run, and neither retrying nor prompting
changes that. **The interactive policy below governs `apply` and `verify`
failures only.**

- **A terminal is attached (stdin is a TTY) and no `--on-failure` override
  was given:** the runner prompts — retry / skip with warning / roll back.
- **Non-TTY, no override:** the runner **aborts in place**, reports on
  stderr which steps applied, and **rolls back nothing**. The absence of
  anyone to ask is not consent, and a half-applied tree is itself evidence
  of what went wrong — evidence an automatic rollback would destroy.
- **Rollback runs only on an explicit answer.** End-of-input, an empty
  answer, and an unrecognised answer at the prompt are all treated as
  "abort, do not roll back" — never as consent. A prompt whose default is
  destruction is not consent.
- **Rollback order is reverse document order**, and it **excludes a step
  whose `apply` itself failed**. A step whose `apply` succeeded and whose
  `verify` then failed **is** rolled back (its `apply` completed; its
  rollback describes a state that exists). Only a step whose `apply` itself
  failed is **never** rolled back (its state is unknown; rolling it back
  could destroy work it did not create) — on a destructive operation this
  is the distinction that matters, so it is named explicitly rather than
  left to "the failed step," which a skimming reader could misread as
  excluding the verify-failed case too. This is why the runner tracks two lists, `applied` and the wider
  `rollbackable` — a step joins `rollbackable` the moment its own `apply`
  succeeds, before `verify` runs, which is what makes a verify-failed step
  eligible while an apply-failed step is not.
- A `--on-failure=abort|skip|prompt` flag selects the policy directly,
  independent of TTY detection, so an automated invocation is never at the
  mercy of whether stdin happens to be a terminal.

## Dry-run is not a safe preview of an untrusted migration

**This needs to be said plainly, because a reviewer specifically asked for
it: dry-run mode still executes `check` and `precondition` blocks, for real,
with the caller's own environment, credentials, and network access.** It
evaluates them up to and including the first pending step, prints that
step's `apply` **source** (never a diff — producing one would require
applying the step), and stops. But "evaluates" means "runs" — a
`precondition` fence in an untrusted document is an arbitrary shell command
that a dry run executes exactly as a real run would. The one guarantee
dry-run makes is that `apply` and `rollback` are never invoked; there is no
guarantee, and no way for a runner to enforce one, that a document's `check`
or `precondition` don't do something a `check`/`precondition` block is
supposed to never do.

**The non-mutation rule ("`check`/`precondition` MUST NOT write to the
working tree") binds honest authors, not hostile ones.** It is stated in the
spec as an obligation on the migration's author — nothing in the linter or
the runner verifies that a `check` or `precondition` block actually refrains
from writing anywhere. A malicious or merely careless migration can put
anything at all in those two blocks, and dry-run will run it. Do not treat
`--dry-run` as a sandbox, a preview safe to point at a migration you haven't
already trusted, or a substitute for reading the document first. An earlier
draft of the dry-run implementation tried a scratch-copy workaround
(`apply` against a mirrored directory instead of skipping it) specifically
to make later steps previewable too; a review found the mirror itself
unsafe (an ordinary recursive copy preserves symlinks, so even a "purely
relative" write can land outside the copy; `mkdir -p "$HOME/..."`, `git
push`, and similar absolute or networked effects reach past any copy
regardless) and it was removed rather than hardened. "The working tree was
not modified" has to be a property of the runner, not of the fixtures a
workaround happened to be tested against — and even with the workaround
gone, the check/precondition exposure above is not something dry-run closes
at all.

## The THRESHOLDS file

`THRESHOLDS` declares, one row per host, the first migration ID at or above
which that host's migrations must satisfy the executable form:

```
claude-workflow            0035
codex-workflow              0016
opencode-workflow           0012
pi-agentic-apps-workflow    0011
```

Each number is the next unused ID in that host's `migrations/` directory at
the time this format was adopted — everything from that number onward must
satisfy the executable form; everything before it is frozen history that
predates the format and is never judged (unless it opts in — see below).
`--host NAME` resolves a row from this file; `--threshold N` sets one
directly. There is deliberately no "neither given" path: an unresolvable
threshold is a hard error (linter exit 65, treated by the runner as its own
usage error, exit 64), never an empty scope, because an empty scope would
make every migration out of scope, every lint trivially clean, and every
migration runnable.

Raising a threshold is a recorded decision — it excuses migrations from the
format, which is the one thing that lets a silent no-op back in. Lowering
one is free.

## Whole-document checks and the opt-in mechanism

L0 through L8 are the numbered rules, each attached to one step or one
fence. The linter also reports three violation classes that are properties
of the *document as a whole* — its filename, and the relationship between
its filename and its frontmatter — rather than of any single step, so they
are not part of that numbering:

| Message prefix | Catches |
|---|---|
| `lint: <file>: filename does not begin with a numeric migration ID` | the file's basename has no parseable `<digits>-` prefix at all. **Never a skip** — an ID the linter cannot read is a violation, not a quiet route out of scope |
| `threshold: <file>: id <N> is at or above threshold <T> but frontmatter does not declare migration_format: executable` | a migration in scope by filename ID that never declared the frontmatter field the format requires there — a spec MUST (§08, "Threshold scope") |
| `id-mismatch: <file>: frontmatter id '<A>' does not match filename id '<B>'` (or: frontmatter `id` is not numeric) | frontmatter `id:`, where present, disagreeing with the filename that actually decides scope |

**The ID-from-filename rule was itself a Stage 2 review finding, not part of
the original design.** The first draft read a migration's ID from
frontmatter `id:`; reading it from the filename instead — the design that
shipped — means deleting one line can never evade the linter.
`0026-bad-no-frontmatter-id.md` (no `id:` line at all) and
`0027-bad-id-mismatch.md` are its dedicated regression fixtures;
`0030-scope-by-filename.md` carries a frontmatter `id` that is deliberately
below every threshold, so only reading the filename puts it in scope at
all — a fixture that exists specifically to catch a future "simplification"
back to reading frontmatter.

**Opting in below threshold.** A migration below its host's threshold MAY
declare `migration_format: executable` in frontmatter to opt in early — once
declared, it is judged exactly as if its filename ID had put it in scope. A
declaration can only ADD a migration to scope, never remove one the filename
ID already established there; L0 rejects any other value the field might
carry (a typo written deliberately is worth reporting, not silently
ignored). This is the opt-in mechanism referenced above, under THRESHOLDS.

## `applies_to`'s dual meaning

`applies_to` has carried one meaning since §08 predated the executable form:
impact-awareness metadata in plan output — "here is what this migration
touches" for a human or a plan-review reader, nothing enforced.

**At or above a host's threshold, `applies_to` gains a second, stricter
meaning: it becomes a write boundary.** A step's `apply` block must not
modify any file or directory outside the paths its migration's `applies_to`
declares. This is what makes the rollback contract meaningful rather than
aspirational — a rollback's obligation to restore pre-apply state only
extends as far as `apply` was allowed to reach.

**This is stated as an author obligation, in the same unenforced sense as
the non-mutation rule above — nothing in `lint-migration.sh` or
`run-migration.sh` checks which paths an `apply` block actually writes to.**
A host may add such a check; none ships with this reference implementation
today. Below a host's threshold, `applies_to` keeps its original,
single meaning (impact-awareness only) — the write-boundary reading applies
only once a migration is in the executable form's scope.

## Publishing alongside the other shared artifacts

These three scripts are not yet installed anywhere outside this repo. When
the installer lands, it will publish them to the shared
`~/.agenticapps/bin/` path exactly as it already does for the change gate,
`run-plan-review`, and `reviewer-cli` — see
[`reference-implementations/README.md`](../README.md) and
[`shared-install/`](../shared-install/). That means the same arbitration
discipline applies once it ships: a `# migration-runner-version:` marker (in
the style of `# gate-version:` / `# run-plan-review-version:` /
`# reviewer-cli-version:`), an installer that refuses to downgrade against
the marker already on disk, and the compare-and-write serialised through
`install-shared-artifact.sh` rather than hand-rolled per host — refusing to
downgrade is necessary and not sufficient; two installers each deciding
correctly against the same observed state can still let the later writer
win if the read-compare-write isn't serialised. All three scripts already
carry the marker line (`# migration-runner-version: 0.1.0`) at the top, in
anticipation of that installer.

## Fixtures and the test suite

`test-fixtures/` holds one document per rule this format enforces, named for
the violation it demonstrates (`0021-bad-l4-typo-role.md`,
`0045-unclosed-fence-verify.md`, and so on) plus the conformant baseline,
`0016-conformant.md`. **Most of these fixtures fail the linter by design** —
that is the whole point of a fixture named `bad-*`. Do not lint
`test-fixtures/` broadly; the suite that exercises them correctly is
`tools/migration-runner.test.sh`, which asserts each fixture's *expected*
verdict (clean or a specific violation) rather than expecting every fixture
to pass. Run it directly:

```bash
bash tools/migration-runner.test.sh
```
