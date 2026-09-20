# The books, at the step that uses them

Three book rule sets were installed machine-wide on 2026-09-20
(`ciembor/agent-rules-books`: `the-pragmatic-programmer`, `refactoring`,
`domain-driven-design-distilled`). Installed, they are model-invokable with broad
trigger descriptions and fire whenever a description happens to match. This
change decides where they are read, and puts the lens in the one place a
reviewer cannot reach for itself.

## Where the books are worth their tokens

The evidence on standing instructions is not encouraging: the ETH Zurich
evaluation of repository context files found agents follow such instructions
faithfully while task success does not improve and inference cost rises by over
20%. The reading that survives it is not "rules do not work" but "rules cost
what they cost, so put them where a decision is being made".

That lands them at four places and keeps them out of a fifth:

- **grilling and propose** — where a shallow module, a duplicated fact or an
  irreversible guess is cheapest to prevent, before any code exists.
- **plan-review** — Pragmatic alone on the delta, from vendors that did not
  write it. Not `refactoring`: that reads diffs, and no diff exists yet.
- **code-review** — the reviewer reads only the diff and can afford the full
  checklist plus Fowler's smells.
- **apply — nothing.** The implementer carries the most context pressure in the
  loop, and the rules have already shaped the spec delta and the tasks by then.
  `codebase-design` still fires by itself when an interface is being shaped.

## Why the producer carries the plan-review lens

`run-plan-review.sh` spawns third-party CLIs headless. They never loaded the
workflow skill, two of the four vendor arms do not resolve skills at all, and a
reviewer machine may not have the books installed. Prose in the skill cannot
reach them; the prompt can. So the lens is appended to the producer's
instruction block, above the `--- CHANGE:` marker and outside the digest set,
with a clause that degrades to a plain review which says the lens was
unavailable.

Round 1 of this change's own review is the test: the lens reaches whichever
reviewers resolve it, and the ones that do not say so rather than pretending.

## Why code-review is not wired the same way

`requesting-code-review` is upstream Superpowers. Patching it is vendoring
(ADR-0024), and it takes no lens argument. The workflow skill therefore says to
name the two books when invoking it. That is weaker than the producer's wiring,
and the change says so rather than implying parity.

## This is a hypothesis until measured

The read is observational and tracked outside this change: findings per
plan-review round, code-review findings by category, diff size, new
dependencies, tokens, in `MEASUREMENT.md`, with reviews written before
2026-09-20 as the pre-lens baseline. An on/off A/B is not available here — the
producer's lens is unconditional by requirement — and ten future changes cannot
gate this one.

## Non-goals

No rule set is vendored, copied or re-worded into core. No gate blocks on a
missing book. `clean-code` and `a-philosophy-of-software-design` are not
installed and are not recommended: each duplicates something already loaded.
