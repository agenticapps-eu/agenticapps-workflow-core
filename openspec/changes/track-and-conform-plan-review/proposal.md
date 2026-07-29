## Why

`run-plan-review.sh` is the producer that satisfies §18's review requirement —
it invokes the vendor reviewer CLIs and writes `REVIEWS.md`. It has two
defects, both found while using it.

**It exists in no repository.** The developed implementation is 227 lines,
version-marked `1.0.0`, and lives only at `~/.agenticapps/bin/run-plan-review.sh`
on this machine. Core's `gate/run-plan-review.sh` is a 66-line ancestor with no
version marker — installers treat an unmarked file as `0.0.0` — and `gate/` is
itself untracked. Unlike the change-gate, reviewer-cli and shared-install, this
artifact has no entry under `reference-implementations/`. If this machine is
lost, so is the producer.

**It enforces a floor the spec retired.** It defaults `MIN_REVIEWERS=2`, but
§18 dropped the floor to one at spec 1.1.0. §18 lines 88–102 record the exact
reasoning: a hard ≥2 floor "does not argue that one reviewer is worse than
*none*, which is what a hard ≥2 floor effectively enforced whenever a vendor
was slow, rate-limited" or timed out.

That is not hypothetical. Reviewing `shim-project-hooks` on 2026-07-29, gemini
returned a complete review while codex and opencode exceeded the 180s timeout.
The producer discarded gemini's review and wrote nothing — enforcing zero
reviewers in precisely the situation the spec changed the floor to prevent. The
run had to be repeated with an explicit `MIN_REVIEWERS=1` override to recover
the opinion.

## What Changes

- **Add `reference-implementations/run-plan-review/`** containing the 227-line
  implementation, a README, and the artifact's install contract — matching the
  layout already used by `openspec-change-gate/`, `reviewer-cli/` and
  `shared-install/`.

- **Default `MIN_REVIEWERS` to 1**, conforming to §18 as of spec 1.1.0. An
  explicit higher value remains honoured, so a caller that wants ≥2 still gets
  it.

- **Report, do not discard.** When the reviewer count is at or above the floor
  but below the number requested, the producer SHALL write the reviews it
  obtained and name the vendors that failed, rather than leaving `REVIEWS.md`
  unchanged.

- **Bump the version marker to `1.1.0`** so the installer arbiter will replace
  older copies and refuse to be clobbered by them.

- **Retire `gate/run-plan-review.sh`**, the unmarked 66-line ancestor, so the
  reference implementation is the single source. This resolves one of the 14
  untracked items in core flagged in the 2026-07-29 handoff; the remaining
  contents of `gate/` are classified separately.

- **NOT changing** the sanitiser, the `## Reviewer:` forge guard, or the
  per-code reporting of reviewer-cli's 3/4/5 exits. Those are why 1.0.0 is the
  real implementation and are carried across unmodified.

## Capabilities

### New Capabilities
- `plan-review-production`: how the plan-review producer sources reviews,
  what floor it enforces, what it does with a partial result, and where its
  implementation is tracked.

### Modified Capabilities
<!-- None. §18's reviewer floor is already one as of spec 1.1.0; this change
     makes the producer conform to the spec as written, and does not alter the
     spec. -->

## Impact

**Repos touched (1):** `agenticapps-workflow-core`.

**Machine state:** `~/.agenticapps/bin/run-plan-review.sh` is republished at
1.1.0 via the existing install path. The version arbiter prevents an older host
installer from reverting it.

**Behaviour change:** a review run yielding one reviewer now writes
`REVIEWS.md` and succeeds, where before it wrote nothing and failed. This is
strictly more permissive, and it is the behaviour §18 specifies. Runs already
yielding two or more reviewers are unaffected.

**Risk of the permissive direction:** a single reviewer is a weaker signal than
three. §18 argues this explicitly and accepts it — the floor sits "where the
guarantee is real: no code without at least one independent opinion". This
change implements that decision; it does not re-litigate it. Callers wanting a
stronger bar set `MIN_REVIEWERS` explicitly.

**Not bundled with `shim-project-hooks`.** That change is reviewed *by* this
machinery; modifying the reviewer inside the change it is reviewing would make
neither result trustworthy.
