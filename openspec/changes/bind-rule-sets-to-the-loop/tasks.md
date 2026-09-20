# Tasks

## 1. The producer carries the plan-review lens — tests first

- [x] 1.1 RED: `tools/run-plan-review-conformance.sh` section I — the prompt
      names `the-pragmatic-programmer`; does NOT name `refactoring`; tells a
      reviewer without it to say so; the lens sits above the `--- CHANGE:`
      marker; the digest of an unchanged change is identical under a pre-lens
      copy of the producer, and a ticked task does not move it either.
- [x] 1.2 Implement in `run-plan-review.sh`: lens appended to `INSTRUCT`,
      version 1.2.0 → 1.3.0.
- [x] 1.3 GREEN, twice: 67/67 after the round-2 cross-check row, 4 RED before.

## 2. The rule, where the workflow reads it

- [x] 2.1 `skills/agentic-apps-workflow/SKILL.md`: `## Rule sets` — the
      step/book/size table, apply reads nothing, plan-review is wired in the
      producer, code-review's lens is named by the invoker, bound never
      vendored, a missing rule set is reported not blocking, and the two pairs
      never loaded together.
- [x] 2.2 Skill `version` 4.1.0 → 4.2.0 (additive).
- [x] 2.3 `CHANGELOG.md` `[Unreleased]` entry.
- [x] 2.4 `design.md`; the locked decision (apply reads nothing) recorded there
      with its rejected alternative.

## 3. Evidence — before archive

- [x] 3.1 Plan-review round 1: codex REQUEST-CHANGES (gemini, opencode exit 1).
      Four findings accepted, one partly — see `design.md`.
- [x] 3.2 Round 2: codex REQUEST-CHANGES (gemini, opencode exit 1). Five
      findings, all accepted — see `design.md`. Mapping cross-check row added
      and proven to fail on drift.
- [x] 3.2a Round 3: codex REQUEST-CHANGES, and the first live confirmation the
      lens is read ("Read `the-pragmatic-programmer` mini rule set: yes").
      Five findings accepted — see `design.md`. Rounds kept as
      `REVIEWS-round{1,2,3}.md`.
- [ ] 3.3 Code-review on the diff, naming the two books to the reviewer — the
      first exercise of the code-review path this change describes.
- [ ] 3.4 Archive; ship; `install.sh` on both machines so the published
      `run-plan-review.sh` is 1.3.0.

## 4. Follow-up, tracked separately

Not a task of this change. The A/B cannot be run from inside it: the producer's
lens is unconditional by requirement, and ten future changes cannot gate this
one's completion.

- [ ] 4.1 Open a Linear issue for the observational read: over the next ten
      changes, record findings per plan-review round, code-review findings by
      category, diff size, new dependencies and tokens in `MEASUREMENT.md`. The
      reviews written before 2026-09-20 are the pre-lens baseline.
- [ ] 4.2 On that evidence, keep the mapping, move a book to another step, or
      drop one. A book that changes nothing costs tokens for nothing.
