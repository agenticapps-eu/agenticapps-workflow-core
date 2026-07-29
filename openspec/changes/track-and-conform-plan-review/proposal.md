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

**It enforces a floor the spec retired — and the spec contradicts itself.** The
producer defaults `MIN_REVIEWERS=2`. §18 dropped the floor to one at spec
1.1.0, and lines 88–102 record the reasoning: a hard ≥2 floor "does not argue
that one reviewer is worse than *none*, which is what a hard ≥2 floor
effectively enforced whenever a vendor was slow, rate-limited" or timed out.

But 1.1.0 updated only part of §18. Line 73's truth table says `REVIEWS.md ≥ 1
reviewer → allow` and line 80 says "at least one independent reviewer", while
line 146 still says "the ≥2-reviewer requirement" and line 174 still requires
"`REVIEWS.md` ≥ 2 reviewers for edits under an active change". The section
mandates both floors at once, so "the producer is non-conformant" is only half
true: the spec is not currently satisfiable as written.

That is not hypothetical. Reviewing `shim-project-hooks` on 2026-07-29, gemini
returned a complete review while codex and opencode exceeded the 180s timeout.
The producer discarded gemini's review and wrote nothing — enforcing zero
reviewers in precisely the situation the spec changed the floor to prevent. The
run had to be repeated with an explicit `MIN_REVIEWERS=1` override to recover
the opinion.

**Three further defects surfaced when this change was itself reviewed**, each
confirmed against the code:

- `MIN_REVIEWERS=0` is accepted. The guard rejects only empty and non-digit
  values, so `0` passes, `[ 0 -lt 0 ]` is false, and the producer publishes a
  possibly-empty `REVIEWS.md` and exits 0 — reporting a satisfied floor it
  never evaluated. This is the same failure class as the non-numeric case the
  comment directly above that guard was written to prevent.
- **A "reviewer" need not have reviewed.** Any non-empty, exit-zero output
  counts. In this change's own review, opencode's section contains no verdict
  at all — it is a preamble stating it will fact-check — yet it counted as one
  of three reviewers. With the floor at one, an unparseable section alone can
  open the gate.
- **Independence is unenforced.** Self-exclusion depends on `OPENSPEC_GATE_SELF`
  defaulting to `claude`. On another host that default is wrong, and a single
  self-review satisfies a floor of one.

## What Changes

- **Add `reference-implementations/run-plan-review/`** containing the 227-line
  implementation, a README, and the artifact's install contract — matching the
  layout already used by `openspec-change-gate/`, `reviewer-cli/` and
  `shared-install/`.

This change covers the whole review pipeline, not the producer alone. The
enforcement point is the **gate**, so hardening the producer by itself would be
cosmetic: a hand-written or stale `REVIEWS.md` opens the gate regardless of
what produced it. Three shared-bin artifacts and one spec section are involved:

| Artifact | Version | Defect |
|---|---|---|
| `spec/18-retargeted-change-gate.md` | — | mandates ≥1 and ≥2 simultaneously |
| `run-plan-review.sh` | 1.0.0 | stale floor; accepts `MIN=0`; discards partial results; untracked |
| `openspec-change-gate.sh` | 1.4.0 | counts headings, not verdicts; reviews not bound to the revision reviewed |
| `reviewer-cli.sh` | 1.1.0 | passes the full prompt as a vendor CLI argument |

- **Repair §18's contradiction.** Lines 146 and 174 are corrected to the floor
  the truth table and rationale already state, so the section mandates one
  floor rather than two. **BREAKING** for any host that read the ≥2 clauses as
  authoritative.

- **Add a verdict term to §18's truth table.** The gate today deliberately
  refuses to block on verdicts, and says why in its own source: "§18's truth
  table has no verdict term, so a gate that blocked on this would be
  non-conformant." Requiring a verdict to *count* a reviewer is therefore a
  spec change first and a gate change second. The two cannot ship separately.

- **Make the gate require verdicts.** `reviewer_count()` counts `## Reviewer`
  headings; `pending_rejections()` parses verdicts, tolerating markdown
  emphasis since 1.3.1. They already diverge exactly as that file's comment
  warns — "the gate counts one set of reviewers and reports on another." A
  section with no verdict counts toward the floor while reporting nothing.
  `reviewer_count()` adopts the same verdict predicate. Gate → **1.5.0**.

- **Bind reviews to what was reviewed.** `REVIEWS.md` SHALL record a content
  digest of the artifacts reviewed, and the gate SHALL treat a review as stale
  when they no longer match. Today an amended change keeps its old
  `REVIEWS.md` and the gate cannot tell — a hole walked through twice during
  this very session, when both open changes were revised after review.

- **Stop the wrapper exposing prompts in the process table.** `reviewer-cli.sh`
  reads the prompt file and then passes its full contents as an argv element
  to every vendor (`claude -p "$prompt"`, `codex exec "$prompt"`). The producer
  already passes a file; the exposure is entirely in the wrapper. It moves to
  stdin or a file path. Wrapper → **1.2.0**.

- **Default `MIN_REVIEWERS` to 1 and reject values below 1.** An explicit
  higher value is honoured; `0` is now an error rather than a silent
  gate-opener.

- **Define a complete review.** A reviewer section counts toward the floor only
  if it carries a parseable verdict. A vendor that produced output without one
  is recorded as failed, not counted.

- **Make self-exclusion normative and fail closed.** One host-agnostic binary
  cannot infer which host invoked it, so "determine the host by rule" is not
  implementable. Instead the caller SHALL supply an authoritative identity, and
  the producer and gate SHALL **refuse to count any reviewer** when it is
  absent or invalid — rather than defaulting to `claude`, which is wrong on
  every host but one. Duplicate vendors count once.

- **Specify the verdict format exactly** rather than saying "parseable":
  case-insensitive, anchored at line start, optional markdown emphasis, one of
  a closed vocabulary — matching the parser the gate already ships, so no
  existing well-formed `REVIEWS.md` is invalidated.

- **Report, do not discard.** When the floor is met but fewer reviewers
  succeeded than were requested, the producer SHALL write the reviews it
  obtained. `REVIEWS.md` itself SHALL record which vendors were requested,
  which succeeded, which were excluded, and which failed with the reason — so a
  later reader can tell "not requested" from "failed", without relying on
  ephemeral stderr.

- **Document the egress trust boundary honestly.** The vendors are *agentic*
  CLIs with their own file access — they can read beyond the prompt they are
  handed, so the boundary is the repository, not the prompt. The capability
  SHALL say so rather than implying the prompt bounds it. Reviewer output is
  likewise **untrusted third-party input** that lands in `REVIEWS.md` and is
  then read back by agents, and SHALL be documented as such. Secret/PII
  screening is deferred to its own named change; deferring it does not make the
  narrower boundary claim true, which is why the claim is corrected here.

- **Complete the publication path.** Add the `resolve-core-artifact.sh` mapping
  for the producer and point the Claude installer at core rather than its
  vendored 1.0.0 copy, so core is genuinely the operational source of truth
  rather than nominally so.

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
- `plan-review-production`: how the plan-review producer sources reviews, what
  floor it enforces, what it does with a partial result, and where its
  implementation is tracked.
- `change-gate-enforcement`: the normative contract §18's changes amount to —
  one floor stated once, a verdict required to count, rejections counting,
  independence supplied rather than guessed, and reviews bound to the revision
  they reviewed. Written as a delta so `validate` and reviewers can assess the
  changed contract, rather than it existing only as proposal prose.

### Modified Capabilities
<!-- Core's durable spec lives in spec/*.md, not openspec/specs/ — migrating
     those 19 sections is the open question recorded in the 2026-07-29 handoff
     and is not attempted here. There is therefore no openspec/specs/ entry to
     delta against, and this section is empty for a structural reason, not
     because no spec changes. The §18 edits are named explicitly under "Spec
     changes" below and carried by tasks, so they are not hidden. -->

## Spec changes

`spec/18-retargeted-change-gate.md` is edited to remove its internal
contradiction:

- **Line 146** — "REVIEWS.md and the ≥2-reviewer requirement" → the one-reviewer
  floor.
- **Line 174** — "`REVIEWS.md` ≥ 2 reviewers for edits under an active change"
  → ≥ 1.
- **Add**: a reviewer section counts only if it carries a parseable verdict.
- **Add**: the host's own vendor never counts toward the floor, and duplicate
  vendors count once.

Lines 73 and 80 already state the one-reviewer floor and are unchanged; this
brings the rest of the section into line with them rather than introducing a
new rule.

## Impact

**Repos touched (1):** `agenticapps-workflow-core`.

**Spec version:** §18 changes meaning for any reader who trusted the ≥2
clauses, so the spec version is bumped and the four hosts are informed at their
next re-vendor. The gate binary already enforces ≥1, so no *running* gate
changes behaviour — this aligns the text with the enforcement that has been
live since 1.1.0.

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
