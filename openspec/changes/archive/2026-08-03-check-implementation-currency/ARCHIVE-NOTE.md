# Archive note — 2026-08-03

Merged as `db02493` (PR #66, squash, no `--admin`). Every task is checked and
every artifact is done, so this note exists to stop **"0 open boxes" from reading
as "no open questions"** — the residual the previous archive was criticised for
carrying silently.

## What became durable truth

`project-hook-binding` gained a third axis and lost a false sentence:

- **Removed:** *"A machine's provisioning is reported on **two** independent
  axes"*, and *"`attested` … is the only value on either axis under which the
  fleet's protections may be described as running as documented."* The second was
  **observed false** for fifteen hours on 2026-08-03 and had to go rather than be
  contradicted.
- **Added:** `currency ∈ {current, stale, unknown}`, the licence now requiring
  `complete` + `attested` + `current`, and a new requirement — *"The
  implementation version marker is compared, not merely carried."*

## Residuals, carried forward by name

### 1. Requirement placement — the finding this change deepened

The entire three-axis state model, every currency invariant and all six currency
scenarios now live under a requirement titled **"An unresolvable shim allows, and
the operator sees it"**, which is about none of those things.

opencode raised this in round 2 as non-blocking, and it is **correct and
pre-existing** — but this change made it materially worse, adding ~200 lines of
provisioning-state contract under a heading about shim resolution. There is a
requirement two headings down called *"Provisioning is checked per machine, not
only per repository"* that is where a reader would actually look.

Not fixed here because moving it is a restructuring of the durable capability,
not a line item in a change about currency. **This is the reason to open that
change**, and the longer it waits the larger the move gets.

### 2. The `cmp`-error path is reasoned, not tested

`cmp` exits 1 for *they differ* and 2 for *I could not compare them*. The
implementation branches on this and reports `unknown` for exit 2, because
collapsing the two would report an I/O error as `stale`.

`cmp` exit 2 is verified against a real invocation. **What is untested is the
path that reaches it**: a genuine mid-read I/O error, on a file that passed `-r`
a microsecond earlier, cannot be constructed portably in this suite. Three lines,
provably reachable, no test.

Recorded as negative evidence rather than counted as coverage — the same
discipline the previous change used for the `PostToolUse` warning channel, and
for the same reason: an untested branch that nobody wrote down becomes a tested
one in the next person's summary.

### 3. Inherited, still open

The `PostToolUse` fail-open report channel remains **unverified**, unchanged by
this change. `normalize-claude-md` is still the live instance, and this
capability still records a verified channel for `PreToolUse` only.

## One decision worth finding again

`--no-source-check --strict` exits **1 unconditionally**. That is deliberate:
carving the explicit opt-out out of `--strict` would restore, in a single flag,
the silent pass this change exists to remove. There is no escape hatch under
`--strict`, and the cost — `--no-source-check` is useful only without it — is
stated rather than buried.

If a future reviewer reads that combination as a bug, this is the paragraph to
point them at.

## Two things this change was wrong about, both caught by review

1. **Its own cause.** The first draft proposed building a comparison that
   already existed as `--source-check`. Round 1 caught it and the change was
   rewritten.
2. **Its own test fixtures.** Five were named for the words their assertions
   grep for, so `has "$OUT" "behind"` matched the directory `.../auth-behind`
   against the *unfixed* tool — six assertions passing green on a broken build.
   This is the `override-dir` defect from the previous change, repeated on the
   same suite four days later. Caught only because the whole suite was re-run
   against the pre-change tool rather than trusted to be red.

The second is the one to remember: **a test that has never been observed failing
is not evidence of anything**, and this suite has now produced that error twice.
