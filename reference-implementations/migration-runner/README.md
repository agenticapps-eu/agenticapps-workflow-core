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
| `lint-migration.sh` | enforces the executable format (L0–L10 plus the unnumbered whole-document checks, below) |
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

## Your first executable migration

Everything below this section describes the format's *rules*. This section is
the thing to copy. It exists because the review that authored a migration from
this README alone produced a document that linted clean and refused to run:
the README described the five headings, the five roles and the info-string
grammar, but never once showed the `### Step ` heading those headings live
under, and never showed a complete document. Once `### Step 1:` was guessed
from the fixtures, everything worked first time.

The skeleton below is `test-fixtures/0060-first-migration.md`, committed and
exercised by the suite, so this example cannot rot into being wrong. It is the
smallest complete migration this format admits.

Save it as `migrations/0060-first-migration.md` — **the filename's leading
digits are what put it in scope**, never the frontmatter `id`:

````markdown
---
id: 0060
slug: first-migration
title: Add a repo .editorconfig
from_version: 3.0.0
to_version: 3.1.0
migration_format: executable
applies_to:
  - .editorconfig
---

# Migration 0060 — Add a repo .editorconfig

## Steps

### Step 1: create .editorconfig

**Idempotency check:**
```bash role=check
test -f .editorconfig
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
printf 'root = true\n' > .editorconfig
```

**Rollback:**
```bash role=rollback
rm -f .editorconfig
```
````

The parts that are load-bearing, in the order they bite:

1. **`### Step <N>:` — three hashes.** A step is recognised only by a line
   starting `### Step ` followed by digits, outside any fence. `## Step 1:`
   yields a migration with **zero steps**; the linter now rejects that
   (`steps: ... declares no '### Step ' heading`), but it is still the first
   thing to get right. Steps must be numbered consecutively from 1.
2. **Six frontmatter fields.** `id`, `slug`, `title`, `from_version`,
   `to_version` and `applies_to` are §08 requirements; `migration_format:
   executable` is what an at-or-above-threshold migration must declare. The
   linter enforces `migration_format`, the `id`↔filename agreement, and the
   **presence** of `applies_to` (the write boundary).
3. **All four required headings, in this order**, each immediately followed by
   its role-tagged fence: `**Idempotency check:**`, `**Pre-condition:**`,
   `**Apply:**`, `**Rollback:**`. A fifth, `**Verify:**` with a `role=verify`
   fence, is optional and may appear at most once — put it between **Apply:**
   and **Rollback:** (see `0059-heredoc-fence-escape.md`).
4. **The info string is exact**: `bash`, whitespace, `role=`, a lowercase role
   name, nothing else. A ` ```bash ` fence with no `role=` is illustration and
   is never executed.
5. **Every fence body must actually do something.** A `# TODO:` placeholder,
   or a bare `:`, is rejected — see L8.

Two commands, both of which take `--host` (there is no default):

```bash
# Judge the document. Exit 0 = clean; 1 = violations on stderr; 64 = you
# invoked this wrong; 65 = unresolvable host/threshold; 66 = no such file.
bash lint-migration.sh --host claude-workflow migrations/0060-first-migration.md

# Preview: runs check and precondition up to the first pending step and
# prints that step's apply SOURCE. Not a sandbox — see the dry-run warning
# further down. Drop --dry-run to apply for real.
bash run-migration.sh --host claude-workflow --dry-run migrations/0060-first-migration.md .
```

`run-migration.sh` lints first and refuses to execute anything the linter
rejects, so the first command is a fast check rather than a separate gate.

**Wiring the linter into CI** — which §08's Conformance section requires of an
adopting host — enumerate migrations as `migrations/[0-9]*.md`, **not**
`migrations/*.md`:

```bash
for m in migrations/[0-9]*.md; do
  bash lint-migration.sh --host claude-workflow "$m" || exit 1
done
```

A filename with no leading numeric ID is a MUST-report violation with no
carve-out (an unreadable ID must never be a quiet route out of scope), and
`migrations/` is also where every host in the fleet keeps a
`migrations/README.md`. The broad glob turns that README into a CI failure on
adoption day, on a file working exactly as intended. The narrower glob is the
fix; a `README.md` exemption inside the linter is not, because that exemption
is something a migration could be renamed into.

### Emitting a fenced code block from a migration

**Read this before writing an `apply` block that patches a markdown file.**
This is the one thing about this format that will surprise you, and the linter
rejects it rather than letting it through silently (L9/L10 above).

A block's captured body ends at the first line whose first three characters
are a fence delimiter — **including a line inside a heredoc**. So the obvious
way to append a documentation section is broken:

````text
**Apply:**
```bash role=apply
cat >> CLAUDE.md <<'EOF'

## Running the suite

```bash                                  <- the apply block ENDS here
bash tools/migration-runner.test.sh
```
EOF
```
````

The captured body is only the first three lines. Run, it writes a truncated
CLAUDE.md and **exits 0** (an unterminated heredoc writes its partial payload
and succeeds), so the step reports applied — and on the next run the step's own
idempotency check matches the truncated output, so it reports skipped forever.

**A four-backtick outer fence does not help.** The info-string grammar requires
the literal `bash` immediately after the delimiter, and a four-backtick opener
puts a backtick there, so the fence carries no role at all — `extract.sh roles`
returns nothing for it.

Three escapes work. All three are exercised end-to-end by
`test-fixtures/0059-heredoc-fence-escape.md`, which asserts the emitted file
byte-for-byte.

**1. `printf` — byte-exact output, fence at column 1.** Preferred when the
emitted file's bytes matter:

```bash
{
  printf '%s\n' ''
  printf '%s\n' '## Running the suite'
  printf '%s\n' ''
  printf '%s\n' '```bash'
  printf '%s\n' 'bash tools/migration-runner.test.sh'
  printf '%s\n' '```'
} >> CLAUDE.md
```

**2. Indent the nested delimiter inside the heredoc.** Simpler to read, at the
cost of one leading space in the output — which is below CommonMark's
three-space limit, so the emitted block still renders as a fenced block:

````text
```bash role=apply
cat >> CLAUDE.md <<'EOF'

## Running the suite

 ```bash
 bash tools/migration-runner.test.sh
 ```
EOF
```
````

**3. `<<-` with a TAB-indented payload — byte-exact output, fence at column
1.** This is escape 2's readability with escape 1's output. `<<-` strips
leading *tabs* from every heredoc body line before the shell sees them, so the
nested delimiter sits off column 1 in the migration's source — where the fence
state machine, which tests "first three characters of the line", does not see
it — and back at column 1 in the emitted file. Every indented line below
begins with a literal TAB, including the terminator:

````text
```bash role=apply
cat >> CLAUDE.md <<-'EOF'
→
→## Running the suite
→
→```bash
→bash tools/migration-runner.test.sh
→```
→EOF
```
````

`→` marks a literal tab above. **This escape is tabs-only.** `<<-` strips tabs
and nothing else, so an editor, a formatter, or a copy-paste that turns those
tabs into spaces silently converts the block back into the broken form at the
top of this section. 0059's byte-exact assertion is what catches that; if you
use this escape, keep it covered by one.

This third escape was added after this README had already said, for a while,
that "two escapes work". It was found by trying it, not by reasoning about it.

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

## The linter — L0 through L10

`lint-migration.sh` runs eleven *numbered* rules. Ten of them (L1–L10) are
per-step or per-fence; **L0 is per-document** and is reported without a step
number, which is a historical inconsistency in the numbering rather than a
meaningful distinction — every other whole-document check the linter performs
is deliberately unnumbered, and L0 predates that convention. All are described
in more depth in the script's own header comment; this table is the index. The
linter also reports five whole-document violation classes that are not part of
this numbering at all — those are covered separately, in "Whole-document checks
and the opt-in mechanism" below.

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
| **L8** | a tagged fence whose captured body contains no executable statement (nothing left after blank lines, whole-line `#` comments and whole-line `:`/`true` are discarded), for any of the five roles |
| **L9** | a tagged fence TERMINATED by a line that is itself a fence *opener* — a ``` line carrying a non-empty info string. Its body is truncated there |
| **L10** | a tagged fence whose captured body leaves a heredoc unterminated |

Six of the eleven were designed in from the start (L1, L3, L5, L6 as
structural rules; L0 and L2 as the frontmatter/heading checks that go with
them). **L4, L7, L8, L9 and L10 were not designed in — each was found by a
review round, each because a migration that looked fine would have linted clean
and done nothing:**

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
- **L8 exists because a tagged-but-vacuous check fence is a silent no-op that
  reports success.** `bash -c ''` — and a fence containing only blank lines,
  or only `#` comments, or the bare no-op builtin `:` — exits 0. The
  three-valued `check` contract (below) reads exit 0 as "already applied." So a
  `role=check` fence with nothing meaningful in it makes the runner print
  `step N: skipped (already applied)` and apply nothing, on a tree where
  nothing was ever applied — at exit 0. This was reproduced against the real
  CLI (`0049-bad-l8-empty-check.md`, `0050-bad-l8-empty-precondition.md`)
  before L8 was written, and reproduced again for the comment and `:` variants
  (`0053-bad-l8-comment-only-check.md`, `0054-bad-l8-noop-builtin-check.md`)
  when the final whole-branch review found that L8's original
  `tr -d '[:space:]'` test was **one character** short of catching a leftover
  `# TODO:` placeholder. L8 checks every role, not just `check` — a vacuous
  `precondition` passes just as emptily, and a vacuous `apply`
  (`0055-bad-l8-comment-only-apply.md`) is attempted and does nothing.

  **A bare `:` or `true` counts as non-executable only as an ENTIRE body.**
  That is a decision, not an accident: `:` is the shell's explicit no-op, so a
  fence whose whole body is `:` provably does nothing and exits 0 — the same
  observable outcome as an empty body, reached deliberately. Nothing
  legitimate is lost (a `check` that must always report "not applied" writes
  `false`), and `:` inside a larger body — `while :; do`, `: "${VAR:?}"` — is
  ordinary shell and is left completely alone.

  **What L8 does not do — know this before you rely on it.** L8's test is
  whole-line and lexical. It rejects a body that is *provably inert by
  inspection*; it does not detect a body that *executes and accomplishes
  nothing*. All of these lint clean today, and as a `check` each exits 0 —
  which the three-valued contract reads as "already applied", so the runner
  prints `step N: skipped (already applied)` on an untouched tree:

  ```bash
  true; true
  :;:
  ( : )
  exit 0
  echo "checking whether the allowlist is hardened"
  ```

  On the apply side, `echo "TODO: write the file"` reports `step 1: applied`
  having written nothing. Note that `true; true` is one keystroke from the
  whole-line `true` that L8 *does* reject — an earlier version of this
  documentation claimed stripping `true` closed that hole; it narrowed it.

  **This is a stated limit, not a to-do.** "Does this shell accomplish
  anything?" is not answerable by inspecting the text, and a widening that
  tries trades a caught no-op for a risk of rejecting real migrations — a
  trade this format has already lost once, when L10 rejected a valid
  README-following migration (see L10 below). The five shapes above are pinned
  as ACCEPTED in `tools/migration-runner.test.sh` so that the boundary is
  machine-checked and cannot be quietly re-described as closed. If a step's
  correctness depends on its `check` really checking something, that remains
  the author's obligation and the reviewer's, not the linter's.
- **L9 exists because a fence delimiter emitted from inside a heredoc
  truncates the block that emitted it.** `extract.sh` ends a block's capture
  at the first line whose first three characters are a fence delimiter,
  *including one inside a heredoc body*. §08 already mandated heredoc-awareness
  for `### Step` headings and was silent on the identical hazard for fences.
  Reproduced against the real CLI on `0052-bad-l9-heredoc-fence.md`, an
  in-scope migration whose apply is `cat >> CLAUDE.md <<'EOF'` … containing a
  nested ```bash fence … `EOF`: lint exit 0 clean, `step 1: applied` at exit 0,
  CLAUDE.md receiving only the truncated prefix — and then, because the step's
  own idempotency check matches that truncated output, `step 1: skipped
  (already applied)` forever after. The migration permanently self-certifies as
  done. **Every existing guard passed it**: L1 reads the role from the fence's
  *opening* line, L7 balances (the inner fence closes and the real closer
  re-opens), L8 sees a non-empty body, the runner's zero-apply pre-flight sees
  a non-empty body, and `bash -c` on an unterminated heredoc writes the partial
  payload and exits 0. L9's test is lexical and exact rather than heuristic — a
  CommonMark closing fence may not carry an info string, so a tagged fence
  "closed" by a line that does carry one is definitively truncated. See
  "Emitting a fenced code block from a migration" below for the escapes.

  **This rule rests on the constructed defect above, not on the idiom being
  common — because it is not.** An earlier version of this bullet said "6 of
  the 73 migrations in the fleet today already emit a fence delimiter from
  inside a heredoc, because that is the normal idiom for patching CLAUDE.md and
  skill files." That figure was relayed from a review and never measured, and
  it is wrong. Measured across all four hosts' `migrations/` directories — 73
  numbered migrations (claude-workflow 34, codex-workflow 16, opencode-workflow
  12, pi-agentic-apps-workflow 11):

  | measured | count |
  |---|---|
  | numbered migrations in the fleet | 73 |
  | using a heredoc at all inside a fenced body | 7 |
  | emitting a three-backtick line from inside a heredoc | 0 |
  | emitting a three-backtick line into a file by any means | 0 |

  Running L10's own scan over all 482 fenced bodies in those 73 documents fires
  0 times. So adopting this format costs the current fleet nothing, and L9 is
  justified by `0052-bad-l9-heredoc-fence.md` — executed, committed, and
  self-certifying — rather than by a prevalence claim nobody had checked.
- **L10 exists because L9 cannot see a truncation that happens at a BARE
  delimiter,** which is indistinguishable from a legitimate closer, and because
  an ordinary mistyped heredoc terminator produces the same silent partial
  write with no fence involved at all. It scans a tagged fence's captured body
  for a heredoc whose terminator never arrives.
  `0058-bad-l10-mistyped-heredoc.md` is the fixture that proves it is not a
  restatement of L9: it has no nested fence anywhere, every fence opens and
  closes normally, its body is non-empty and comment-free — L7, L8 and L9 all
  pass it, and L10 fires alone.

  `bash -n` looked like the precise, heuristic-free way to do this and was
  tried first. It does not work on the bash this fleet actually runs: bash 5
  warns `here-document at line N delimited by end-of-file`, but bash 3.2 —
  what macOS ships as `/bin/bash` — is completely silent and exits 0. So L10
  reads the redirection operators itself, and is deliberately conservative in
  the *skip* direction: it ignores a `<<` inside an odd number of preceding
  quotes on its line (`echo "a << b"`), one inside a `$((...))` span
  (`x=$((1<<2))`), and a `<<<` herestring; it skips whole-line `#` comments
  entirely; and it accepts an unquoted delimiter matching
  `^[A-Za-z_][A-Za-z0-9_]*$` or a delimiter quoted with `'`, `"` or a leading
  backslash.

  **Two claims that used to sit here were disproved by construction, and both
  are corrected rather than softened.**

  *"Each narrowing is a possible missed detection, never a possible false
  accusation."* False. The missing comment skip made L10 read a heredoc opener
  out of prose and reject a valid migration — the worst case being one that
  followed this very README, emitting its payload with `printf` and saying so
  in a comment mentioning `<<EOF`. `0061-l10-comment-mentions-heredoc.md` is
  that migration, committed as an ACCEPT fixture; before the fix it linted
  dirty with an L10 message whose every substantive clause was false: no heredoc
  is opened, nothing is unterminated, and no partial payload is written.

  *"L9 covers the tagged-fence truncation case independently of it."* False.
  `0062-l10-backslash-bare-fence.md` truncates a `<<\EOF` heredoc with a BARE
  fence line and fired **neither** rule: L9 is silent because a bare
  terminator is indistinguishable from a legitimate closer, and L10 did not
  parse `<<\EOF` as an opener at all. Lint exited 0, the runner reported
  `step 1: applied`, the payload was truncated, and the second run reported
  `skipped (already applied)` — the review's Critical 1 verbatim, against the
  linter that was supposed to have closed it.

  What the pair covers, as tested:

  | truncating line | body | fires |
  |---|---|---|
  | carries an info string (` ```bash `) | anything | **L9** |
  | bare (` ``` `) | opens a heredoc L10 can parse | **L10** |
  | none — terminator merely mistyped | opens a heredoc L10 can parse | **L10** |
  | bare | opens a heredoc L10 does **not** parse | *neither* |

  The last row is a real residue, not a closed case. The skip list above is
  exactly the list of openers that land in it.

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
| `64` | usage error — the script itself was invoked wrong: a missing `--host`, an **unknown flag**, a flag missing its value, no document at all, an extra positional argument, a bad `--on-failure` value, or (for the runner) an unresolvable `--host`/`--threshold` one layer down. Both scripts use 64 for every one of these, without exception — three of them used to exit `1`, the violation code, through bare `${VAR:?}` expansions, so a caller could not tell "you invoked me wrong" from "this document is malformed" |
| `65` | every pre-execution refusal — a lint violation, an out-of-scope document, a zero-step document, or a step with no `apply` block. Nothing has executed; the tree is guaranteed untouched |
| `66` | the named document does not exist or cannot be read |
| `1` | a failure once execution has begun (a step's `check`/`precondition`/`apply`/`verify`) — earlier steps may already have applied |

`lint-migration.sh` uses the same 64/65/66 vocabulary for itself, with one
documented difference the runner translates: lint's `65` means "the host or
threshold VALUE could not be resolved", which is a problem with how the *runner*
was invoked, so the runner maps it to its own `64`. Lint's own `1` is reserved
for format violations, exactly as the runner's `1` is reserved for
post-execution failures.

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

L1 through L10 are the numbered rules attached to one step or one fence (L0 is
numbered but is per-document — see the note under the rule table above). The
linter also reports five violation classes that are properties of the
*document as a whole* — its filename, its frontmatter, and whether it declares
any steps at all — rather than of any single step, so they are not part of that
numbering:

| Message prefix | Catches |
|---|---|
| `lint: <file>: filename does not begin with a numeric migration ID` | the file's basename has no parseable `<digits>-` prefix at all. **Never a skip** — an ID the linter cannot read is a violation, not a quiet route out of scope |
| `threshold: <file>: id <N> is at or above threshold <T> but frontmatter does not declare migration_format: executable` | a migration in scope by filename ID that never declared the frontmatter field the format requires there — a spec MUST (§08, "Threshold scope") |
| `id-mismatch: <file>: frontmatter id '<A>' does not match filename id '<B>'` (or: frontmatter `id` is not numeric) | frontmatter `id:`, where present, disagreeing with the filename that actually decides scope |
| `steps: <file>: declares no '### Step ' heading` | an in-scope migration with nothing to dispatch. §08 has always required at least one step and the runner has always refused a zero-step document — but §08 also requires an adopting host to run the LINTER in CI, and CI does not run the runner, so before this rule that CI was green on a document that cannot run. `## Step 1:` instead of `### Step 1:` is how it happens |
| `frontmatter: <file>: no 'applies_to:' field` | the one frontmatter field this format newly makes load-bearing. At or above the threshold `applies_to` is the write boundary an `apply` may not cross; omitted entirely, the permitted write set is undefined and every statement about what the rollback owes the tree is vacuous. **Presence only** — which paths an `apply` actually writes to is unenforceable, see "`applies_to`'s dual meaning" below. The other §08-required fields (`slug`, `title`, `from_version`, `to_version`) are deliberately not checked: none of them changes what a block is permitted to do |

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
`0045-unclosed-fence-verify.md`, `0052-bad-l9-heredoc-fence.md`, and so on)
plus three conformant documents: `0016-conformant.md` (the baseline),
`0059-heredoc-fence-escape.md` (the two documented ways to emit a fenced code
block, run end to end) and `0060-first-migration.md` (the README's own worked
example, so that example cannot rot into being wrong).
**Most of these fixtures fail the linter by design** —
that is the whole point of a fixture named `bad-*`. Do not lint
`test-fixtures/` broadly; the suite that exercises them correctly is
`tools/migration-runner.test.sh`, which asserts each fixture's *expected*
verdict (clean or a specific violation) rather than expecting every fixture
to pass. Run it directly:

```bash
bash tools/migration-runner.test.sh
```
