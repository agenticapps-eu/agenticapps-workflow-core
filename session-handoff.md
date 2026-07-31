# Session Handoff — 2026-07-31 (evening)

## The one thing to know

**Task 8.4 is done and both repos have open PRs.** The Claude installer no
longer vendors core's artifacts — it pins them. `install.sh` and migration 0032
resolve the gate, the producer and the wrapper from core at a verified commit
and publish those bytes; the three copies in `claude-workflow/bin/` are deleted.

- **core PR #47** — https://github.com/agenticapps-eu/agenticapps-workflow-core/pull/47 (41 commits, the whole plan-review track)
- **claude-workflow PR #109** — https://github.com/agenticapps-eu/claude-workflow/pull/109 (all checks green)

**#109 depends on #47 and the dependency has a sharp edge.** The manifest pins
`2b82a91`, a commit on core's feature branch, not on main. GitHub serves raw
content by sha for any pushed commit, so it resolves everywhere today — but **a
squash-merge of #47 orphans that sha** and the pin must then be advanced to the
resulting main commit. The failure is loud (a failing test row and a refusing
installer), never a silent fallback to a stale copy.

## Accomplished

| | Was | Now |
|---|---|---|
| `claude-workflow/bin/openspec-change-gate.sh` | vendored 1.3.1 | **deleted — resolved at 2.0.0** |
| `claude-workflow/bin/run-plan-review.sh` | vendored 1.0.0 | **deleted — resolved at 1.2.0** |
| `claude-workflow/bin/reviewer-cli.sh` | vendored 1.1.0 | **deleted — resolved at 1.2.0** |
| migration suite | 218 pass / 4 fail | **226 pass / 0 fail** |

All four pre-existing failures *were* this bug. Six commits on
`feat/installer-resolves-core-artifacts`, TDD throughout (RED committed before
GREEN), every new row mutation-tested.

## Decisions

- **Pin, not re-vendor.** Re-vendoring fixes the bytes and keeps the mechanism
  that made them wrong. The runtime never read those copies — the hook resolves
  `~/.agenticapps/bin` first — so they existed only to feed the installer, and
  they drifted. All three were stale at once.
- **Fails closed.** No fallback to the copy on disk. That fallback, run today,
  would have republished gate 1.3.1 over the 2.0.0 just shipped.
- **Migration 0032 edited, not superseded.** It is shipped, but the edit only
  reaches projects that have *not* applied it, and for them the alternative is a
  hard failure on a missing file. Fixture updated in lockstep; only the three
  source assignments are exempt from apply-parity.
- **Drift is now measured against the pin, not `$CORE_SPEC_DIR`.** CI checks
  core out at `ref: main`, so the old comparison asked "does this match whatever
  main says today" — an answer that changes without either repo changing.

## What resolving from the pin immediately falsified

The producer test had been green against a copy nothing ships. Against the real
1.2.0 it failed three ways, all fixed: the wrapper delivers the prompt on
**stdin**, not argv; `AGENT_SELF=none` is rejected by 1.2.0's identity
validation; a review with no verdict line is not counted.

**The mechanism had been wired to nothing.** `resolve-core-artifact.sh` and
`core-vendor.manifest` were written 2026-07-28 and sat **untracked** in
claude-workflow — never committed, invoked by no code. Task 8.3 added the
producer's path mapping to a resolver no caller ran.

## Two defects I introduced and caught before merge

- **The cleanup trap had nothing to clean.** `x="$(resolve_core …)"` runs in a
  subshell, so `RESOLVED+=` died with it — three leaked temp copies per run,
  verified, now zero.
- **A vacuous test row.** The first 0032 check greped for
  `resolve-core-artifact.sh` anywhere in the file, and the pre-flight mentions
  it, so gutting the real resolve call left it green. Caught by mutation; it now
  asserts what 0032 installs *from*.

## Files modified

- `claude-workflow/` — `install.sh`, `migrations/0032-bind-openspec-v1.md`,
  `migrations/run-tests.sh`, `migrations/test-fixtures/0032/common-apply.sh`,
  `tools/core-vendor.manifest`, `.github/workflows/openspec-gate.yml`,
  `.gitignore`, `docs/decisions/0047-…md`; three `bin/` files deleted, four
  re-vendored at the pin
- `agenticapps-workflow-core/` — `openspec/changes/track-and-conform-plan-review/tasks.md` (8.4)

## Next session: start here

1. **Merge core #47 first, then re-pin.** If it squash-merges, update
   `core_commit` and all seven sha256s in `claude-workflow/tools/core-vendor.manifest`
   to the new main commit and re-run `bash migrations/run-tests.sh resolve-pin`.
   Then merge #109. Nothing else blocks either PR.
2. **`change-gate-conformance.sh` reports success for a missing file** —
   `SKIP (not found)`, `TOTAL: 0 passed, 0 failed`, exit 0. The wrapper's harness
   fails correctly on the same input. Worked around with `test -s` in CI; **the
   real fix belongs in core**, which owns both harnesses.
3. **Migration 0032 installs the producer without version arbitration.**
   Pre-existing, left untouched to keep the edit to a shipped migration minimal.
   The gate and wrapper are arbitrated; the producer is not.
4. **The other three hosts still vendor.** `codex-workflow` keeps copies plus a
   provenance-style manifest; `pi-agentic-apps-workflow` has no manifest.
   claude-workflow is the first host where the pin decides what gets published.
5. `shim-project-hooks` remains proposed, not implemented — and merging #47
   lands it as an open proposal. Intentional, but see it before merging.

## Open questions

- **Does core migrate `spec/`'s 19 sections into `openspec/specs/`?** Still
  unanswered; codex has raised it as a §16 conflict three times.
- **The host/vendor vocabulary is restated in at least four places.** Both
  reviewers asked for one machine-readable source. Deferred, not declined.
- **`~/.codex/skills/codex-openspec-change-review` is a second producer** whose
  every `REVIEWS.md` the gate counts as zero. Belongs to the codex re-vendor.
- **`screen-review-egress`** — still a declared §14 non-conformance.
- **The fleet inventory total is not trusted** (recorded 37, breakdown sums to
  35). It gates nothing; retake it if any count matters.
