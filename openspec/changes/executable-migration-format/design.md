## Context

The full design note, including the survey that produced these decisions, is at
`docs/superpowers/specs/2026-08-04-executable-migration-format-design.md`. The
implementation plan is at
`docs/superpowers/plans/2026-08-04-executable-migration-format.md`. This
document records the decisions and their rationale.

Two findings from the 2026-08-04 survey shaped the design more than anything in
the original brief:

**§08 already mandates the quartet.** `spec/08-migration-format.md:81` — "Every
step MUST have four sections, in this order." Migrations `0014` and `0015` in
`codex-workflow` are therefore already non-conformant, not decay awaiting a new
format. The change is about making an existing MUST machine-dispatchable.

**A hardened extractor already exists.** `codex-workflow/migrations/run-tests.sh`
lines 71–190 hold `extract_step_block()`, which finds the fenced block after a
`**Label:**` marker. It carries a delimiter guard (so `Step 1` cannot match
`Step 10`), an inline-code-span fallback for single-line steps, and a deliberate
literal-prefix match so a metacharacter in a label cannot inject a regex. Both
guards were defects found under review there.

**Fleet state set the scope.** Every live install is at head: all seven FLEET
repos are on claude 3.2.0, and the three with a second host are current on it
too. `cparx`'s codex and opencode stamps read 0.5.0 but neither has skills
installed — they are abandoned mid-setup surfaces, not lagging installs. Since
fresh setup installs a snapshot rather than replaying (ADR-0036), **no existing
migration ever needs to run again.**

## Goals / Non-Goals

**Goals:**
- Applying a migration requires bash and nothing else — no agent, no API key, no
  Node.
- Two runs against the same repo produce the same tree.
- A migration that would do nothing fails loudly rather than reporting success.
- Existing migrations are untouched.

**Non-Goals:**
- Retrofitting any of the 73 existing migrations. Scope is zero by decision.
- The installer (bash, `curl`-fetched, multi-select host detection). Separate change.
- The Docker smoke run. Separate change.
- `role=apply-agent`. It existed to absorb legacy prose; there is none in scope.
- `answers:` frontmatter. Its only consumer was `0000-baseline`, which never replays.
- Touching any host repo. The four thresholds are declared when the installer lands.

## Decisions

**Both markers, not one.** Keep `**Label:**` headings as the document's readable
structure; add `role=` to mark what executes. *Alternative rejected — `role=`
only:* discards a reviewed extractor and its two hard-won document-shape fixes,
and rewrites fences in documents reviewers already know. *Alternative rejected —
labels only:* there is then no way to mark a fence as illustration, which is the
one thing headings cannot express. The cost of "both" is two markers that can
disagree, which rule L2 makes an error.

**Greenfield, retrofit scope zero.** The format governs migrations written from
now on. *Alternative rejected — retrofit all 16 codex migrations:* enables a
differential test (apply both ways, diff the trees) but changes 91 fences that
no project will ever replay. *Alternative rejected — fleet-wide:* 445 fences,
~4.5× the cost, same zero beneficiaries.

**ID threshold, cross-checked against frontmatter.** The linter keys on the
filename's ID because it cannot be forgotten. *Alternative rejected —
frontmatter alone:* a forgotten declaration means the file is silently never
checked. *Alternative rejected — presence of any `role=` fence:* worse; a
migration that omitted every tag is invisible to the linter and does nothing
when run.

**Unattended failure aborts and rolls back nothing (A2).** *Alternative
considered — auto-rollback when unattended:* never leaves a half-applied tree,
but does the precise thing §08 forbids, on the reasoning that absence of anyone
to ask is not consent. It also destroys evidence, and §08's own stated reason
for the rule — partial state is sometimes more useful than a full revert —
applies more strongly when nobody is watching. Auto-rollback's advantage matters
most when the same machine will retry, and that case has a terminal, so it
prompts anyway.

**Bash, not JavaScript.** Steps are bash, so a JS runner shells out for every
block and buys only a process boundary. Keeping it bash means migrations stay
runnable on a machine with no Node, which is also why the installer that will
consume this is bash.

**Dry-run prints source, not a diff.** Producing a diff requires applying the
step. The spec text is corrected to promise what is deliverable rather than
retain a claim nothing satisfies.

## Risks / Trade-offs

**A misspelled role silently becomes illustration** → rule L4 rejects
unrecognised role values, and fixture `bad-l4-typo-role.md` is the regression
guard. This is the sharpest edge of making un-annotated fences illustrative, and
it is why the linter blocks from day one rather than warning.

**`rollback` never executes on the non-interactive path**, making the one block
every step must have the one nothing runs, and therefore the most likely to be
silently wrong → the harness exercises each rollback directly against its own
step's post-apply state. If they rot anyway, the honest options are to test them
harder or to stop mandating them, not to keep a required block nothing runs.

**Two markers can drift** → rule L2 makes disagreement an error rather than a
preference.

**The format has no production users on day one**, so its first real test is the
first migration written under it → the conformant fixture exercises all five
roles including `verify`, and the runner is proved idempotent by a second run
asserting a byte-identical tree.

**§08 is implemented by four host repos**, so revising it is the highest-risk
part of the change → no host is touched here, the amended atomicity rule
invalidates nothing (no host implements the executable runner yet), and the
threshold mechanism means existing migrations remain conformant by being out of
scope rather than by being grandfathered.

## Migration Plan

Eight tasks, each ending with a working tree and its own commit, in the order
given in the plan: extractor → linter structural rules → linter agreement and
threshold → runner happy path → A2 failure policy → rollback fixtures → §08
revision → CI and README.

Rollback strategy: every task is an independent commit touching only new files,
except task 7, which edits `spec/08-migration-format.md`. Reverting task 7 alone
restores the previous contract and leaves the scripts in place, unused and
harmless.

## Open Questions

- **`cparx`'s two vestigial version stamps are unresolved.** `.codex/`
  (untracked, no skills) and `.opencode/` (tracked config, no skills), both
  reading 0.5.0. They are the only thing in the fleet that makes historic
  migrations look live. Removing them is a `factiv`-family decision and is out
  of scope here.
- **Whether the four host thresholds belong in each host's instruction file or
  in a manifest** is deferred to the installer change, which is what will first
  need to read them.
