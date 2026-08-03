# Post-implementation review — round 2

`run-plan-review.sh check-implementation-currency --implementing-host claude`
at `REVIEW_TIMEOUT=600`, run **after** the code existed rather than before it.
That ordering is why this round found things round 1 could not: two of the three
reviewers read the tree, not just the delta.

- **gemini — APPROVE.** No findings.
- **codex — REQUEST-CHANGES.** Six findings.
- **opencode — REQUEST-CHANGES.** Four findings plus four non-blocking.

**Every behavioural claim was reproduced before being acted on.** None was taken
on the reviewer's word, and none turned out to be wrong.

## The shape of it: the code was mostly right, the delta was mostly wrong

Eight of the ten blocking findings are **the delta artifacts describing
something the implementation does not do**. Three required code changes. That is
the inverse of the usual review outcome and is worth naming: writing the code
made the delta stale, and nothing but a second review was going to catch it.

## Reproduced, then fixed — code

| # | finding | reproduced | fix |
|---|---|---|---|
| codex 4 | `--source-check DIR` and `--no-source-check` together — precedence unspecified | last-one-wins, silently, in both orders | usage error, **exit 64**, order-independent, asserted |
| codex 6 | a failed comparison is reported as a difference | `cmp` exits 1 for *differ* and **2** for *could not compare*; the code collapsed them | exit 2 → `unknown` for that artifact |
| opencode (minor) | "two directories up" | `reference-implementations/` is a sibling of `tools/` | comment corrected in code and design |

## Reproduced, then fixed — delta text

| # | finding | verdict |
|---|---|---|
| codex 1 | the ADDED requirement's final scenario names **the installer** as *the* remedy, contradicting the per-condition rule three paragraphs above it | **valid, and self-contradictory within one delta.** Rewritten to "the remedy for that condition", with the contradiction recorded |
| codex 2 | "names both versions and the direction" is unimplementable when a marker is missing | **valid.** The behaviour was already right; the requirement demanded the impossible. Now conditional on both being readable |
| codex 3 / opencode 4 | an artifact absent both locally and in the authority: scenario says `stale`, code says not judged | **valid, and the code is right.** Completeness already reports it; two axes reporting one fact is what broke the flat four-state list. Scenario corrected to say "declared **and installed**" |
| codex 5 / opencode 1, 2 | Impact omits `tools/lib/semver.sh` and the `project-hook-conformance.sh` refactor; "BREAKING for output format only" is false; "reusing `semver_cmp` from `project-hook-conformance.sh`" has the direction inverted | **all valid.** `project-hook-conformance.sh` gains a failure mode it did not have — it now refuses when the library is absent — and omitting that from Impact understated the blast radius of a change described as touching one tool |
| opencode (minor) | path disclosure is wider than Decision 8 says — the *success* line prints the authority path too | **valid.** Decision 8's trade-off is unchanged; its stated scope was too narrow |

## The one real decision: `--no-source-check --strict`

opencode found that `--no-source-check` sets `unknown`, `unknown` fails
`--strict`, and so the combination **exits 1 every time** — while the Migration
Plan claimed `--no-source-check` "restores the old default for anyone who needs
it". The claim was false.

Two ways out, and the choice is not obvious:

1. **Carve the explicit opt-out out of `--strict`** — the flag then does restore
   the old behaviour, as documented.
2. **Keep the behaviour and fix the documentation** — the combination is
   contradictory and resolves as a failure.

**Taken: 2, and it is now normative in the delta.** Option 1 would put back, in a
single flag, exactly what this change removes: a way to make a CI job report a
clean pass with the question unasked. There is deliberately **no** escape hatch
under `--strict`. A caller who wants a strict pass must let the question be
asked; one who cannot reach an authority gets `unknown` and a non-zero exit,
which is the honest answer rather than the convenient one.

This is a real cost and is not hidden: `--no-source-check` is now useful only
without `--strict`.

## Recorded, not fixed

- **Requirement placement (opencode, non-blocking).** The entire three-axis state
  model and all currency scenarios live under a requirement titled *"An
  unresolvable shim allows, and the operator sees it"*, which is about none of
  that. The finding is **correct and pre-existing** — this change deepens it
  rather than creating it. Fixing it means restructuring the durable capability,
  which is a change of its own, not a line item in this one. **Carried forward as
  the reason to open it.**
- **`marker_of` reads the first 10 lines only.** The window is shared with the
  installer deliberately, so a file whose marker sits lower cannot be published
  at all — the *published* side can never have one this misses. An **authority**
  file could, and the message then says the version could not be read. Recorded
  in a comment rather than widened.
- **The `cmp`-error path is reasoned, not tested.** A genuine mid-read I/O error
  on a file that passed `-r` a microsecond earlier cannot be constructed
  portably in this suite. The branch is three lines and provably reachable
  (`cmp` exit 2 is verified against a real invocation); what is untested is the
  path that reaches it. Written down rather than counted as covered — the same
  negative-evidence discipline the previous change used for the `PostToolUse`
  channel.

## Suite

**109 passed, 0 failed** — up from 101 after this round added eight assertions
across the flag conflict, `--no-source-check --strict`, and absent-on-both.
