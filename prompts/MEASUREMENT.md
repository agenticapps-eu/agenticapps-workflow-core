# Measuring the Go / quality skills (does impeccable + the Go skills actually help?)

You keep `database-sentinel` and the security gate on merit (asymmetric downside — a
missed RLS/SQL-injection is expensive). You measure the rest before keeping them.

## The trial (one afternoon, evidence not opinion)

1. Pick the **last ~10 merged PRs** in cParx (or the busiest product repo).
2. For each PR's diff, run the skill under test in isolation — `impeccable`, then each
   Go skill — as a review pass over just that diff.
3. Classify every finding it produces into exactly one bucket:
   - **Real + actionable** — a defect or clear improvement you would fix.
   - **Real but trivial** — technically true, not worth a change.
   - **Noise** — false positive, style nit, or duplicate of what tests/compiler already catch.
4. Tally per skill: `signal_rate = real_actionable / total_findings`, and
   `hits_per_pr = real_actionable / 10`.

## The decision rule

| Result | Verdict |
|---|---|
| `hits_per_pr ≥ ~1` and `signal_rate ≥ ~0.5` | **Keep** — it earns its slot, wire as a conditional gate. |
| finds real things but `signal_rate < ~0.3` | **Keep but narrow** — restrict to the file types where its hits cluster. |
| `hits_per_pr < ~0.3` | **Drop** — the model's baseline + tests already cover it. |

Record the numbers in an ADR so the decision is revisitable when models change. Re-run
the trial once a year or on a major model bump — a skill that was noise on an older
model may become redundant (or newly useful) later.

## Why this beats guessing
Your doubt ("are the agents building good code anyway?") is exactly a signal-rate
question. If a skill's findings are mostly things your tests and the discipline rules
already prevent, it is ceremony; if it catches real defects your pipeline misses, it is
cheap insurance. The tally tells you which, per skill, on your actual code.
