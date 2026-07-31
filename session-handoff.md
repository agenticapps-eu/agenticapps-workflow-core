# Session Handoff — 2026-07-31 (evening)

## The one thing to know

**Both PRs are merged and the installer is verified working from main.** The
Claude installer no longer vendors core's artifacts — it pins them.
`install.sh` and migration 0032 resolve the change-gate, the plan-review
producer and the vendor wrapper from core at a verified commit and publish
those bytes. The three copies in `claude-workflow/bin/` are gone.

- **core PR #47** merged → main `6cd3b9c` (merge commit, not squash)
- **claude-workflow PR #109** merged → main `70ef922`
- Both feature branches deleted.

**Merge order and method mattered and were deliberate.** #109 pinned a commit
on #47's branch while #47 was open, so #47 was merged with a **merge commit**
to keep that sha reachable; the manifest then advanced to `6cd3b9c`, core's
main. All seven pinned entries were re-verified at the new revision and all
seven were byte-identical. Nothing broke; the re-pin was follow-through.

## Verified end-to-end, not just in CI

A real `install.sh` run from merged main:

| check | result |
|---|---|
| published gate / producer / wrapper vs. the pin | byte-identical, all three |
| installed versions | 2.0.0 / 1.2.0 / 1.2.0 |
| leftover temp copies | 0 |
| `openspec-change-gate.sh --ci` | exit 0 |
| migration suite | **226 pass / 0 fail** (was 218 / 4) |
| resolve over the network, no local checkout (what CI does) | all three resolve |

## What changed and why

All three vendored copies were stale **at once** — gate 1.3.1 vs 2.0.0,
producer 1.0.0 vs 1.2.0, wrapper 1.1.0 vs 1.2.0 — and all four pre-existing
test failures were exactly that. The runtime never read those copies (the hook
resolves `~/.agenticapps/bin` first), so they existed only to feed the
installer, and they drifted.

**Re-vendoring was rejected**: it fixes the bytes and keeps the mechanism that
made them wrong. **Fails closed**: no fallback to the copy on disk — that
fallback, run that morning, would have republished gate 1.3.1 over the 2.0.0
just shipped.

**The mechanism had been wired to nothing.** `resolve-core-artifact.sh` and
`core-vendor.manifest` were written 2026-07-28 and sat **untracked** in
claude-workflow — never committed, invoked by no code. Task 8.3 had added the
producer's path mapping to a resolver no caller ran.

## What resolving from the pin falsified

The producer test had been green against a copy nothing ships. Against the real
1.2.0 it failed three ways, all fixed: the wrapper delivers the prompt on
**stdin**, not argv; `AGENT_SELF=none` is rejected by 1.2.0's identity
validation; a review with no verdict line is not counted.

## Two defects I introduced and caught before merge

- **The cleanup trap had nothing to clean.** `x="$(resolve_core …)"` runs in a
  subshell, so `RESOLVED+=` died with it — three leaked temp copies per run,
  verified, now zero.
- **A vacuous test row.** The first 0032 check greped for
  `resolve-core-artifact.sh` anywhere in the file, and the pre-flight mentions
  it, so gutting the real resolve call left it green. Caught by mutation.

I also missed `.github/workflows/openspec-gate.yml` on the first pass — it
scored the two deleted files, and CI caught it, not me.

## Next session: start here

Nothing is blocked and nothing is urgent. In rough priority:

1. **`change-gate-conformance.sh` reports success for a missing file** —
   `SKIP (not found)`, `TOTAL: 0 passed, 0 failed`, exit 0. The wrapper's
   harness fails correctly on the same input; only that one caught the
   deletion. Worked around with `test -s` in claude-workflow's CI. **The real
   fix belongs here in core**, which owns both harnesses. This is the highest-
   value leftover — it is a harness that certifies nothing while looking green.
2. **Archive `track-and-conform-plan-review`.** Task 8.4 was its last real open
   item; the rest are declared limits (§14 non-conformance, `MIN_REVIEWERS` not
   persisted, union host vocabulary) and out-of-repo sites.
3. **`shim-project-hooks` is now on main as an open, unimplemented proposal** —
   it landed with #47, intentionally. Implement or archive it.
4. **Migration 0032 installs the producer without version arbitration.**
   Pre-existing; left untouched to keep the edit to a shipped migration minimal.
   The gate and wrapper are arbitrated; the producer is not.
5. **The other three hosts still vendor.** `codex-workflow` keeps copies plus a
   provenance-style manifest; `pi-agentic-apps-workflow` has no manifest at all.
   claude-workflow is the only host where the pin decides what gets published —
   porting ADR-0047 to codex is the obvious next repo.
6. **Retake the fleet inventory if any count matters** (recorded 37, breakdown
   sums to 35, neither trusted). It gates nothing.

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered; codex has raised it as a §16 conflict three times.
- **The host/vendor vocabulary is restated in at least four places** — spec,
  producer, gate, and the codex review skill. Both reviewers asked for one
  machine-readable source. Deferred, not declined.
- **`~/.codex/skills/codex-openspec-change-review` is a second producer** whose
  every `REVIEWS.md` the gate counts as zero. Belongs to the codex re-vendor.
- **`screen-review-egress`** — still a declared §14 non-conformance.

## Loose ends in the working trees

- `claude-workflow` has an **untracked `openspec/`** (empty spec slot) and
  regenerated `.claude/commands/opsx/*.md`, created by the real `install.sh`
  run — `install.sh` runs `openspec init` when the slot is missing. Harmless
  and arguably correct for a repo subject to §18, but it was not there before.
- `claude-workflow` still has two **unrelated** modified files from earlier
  work, deliberately left alone: `setup/snapshot/workflow-config.md` and
  `templates/workflow-config.md`.
- `core` has untracked `.planning/skill-observations/` files (frozen GSD
  history area; never written to by this work).
