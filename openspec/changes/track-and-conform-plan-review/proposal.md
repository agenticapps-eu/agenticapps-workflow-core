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
enforcement point is the **gate**, so hardening the producer by itself would
leave the rule unenforced: a *stale* `REVIEWS.md` opens the gate regardless of
what produced it.

The claim stops there, deliberately. This change does not address a
**forged** `REVIEWS.md`. The digest below is computable by anyone holding the
same artifacts, so it detects drift, not authorship; resisting deliberate
forgery would need a signature and is not attempted. An earlier draft argued
from forgery and shipped a mechanism that does not answer it.

Three shared-bin artifacts and one spec section are involved:

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

  **The digest covers exactly what the producer sends to reviewers**:
  `proposal.md`, `design.md` and `specs/**/*.md` — OpenSpec's own glob for a
  change's spec artifact, so the digest set is the tool's definition rather than
  a fourth one invented here. Not `tasks.md` — the
  producer has never sent it (`run-plan-review.sh:101-102`), so no reviewer has
  seen it, and binding it would stale a review on every checkbox ticked during
  implementation. Not `REVIEWS.md`, which carries the digest. SHA-256 over a
  length-framed, `LC_ALL=C`-ordered, LF-normalised serialisation, specified in
  the delta so two implementations cannot disagree.

- **Stop the wrapper exposing prompts in the process table.** `reviewer-cli.sh`
  reads the prompt file and then passes its full contents as an argv element
  to every vendor (`claude -p "$prompt"`, `codex exec "$prompt"`). The producer
  already passes a file; the exposure is entirely in the wrapper. The
  requirement is that change content never appears in a process's argv; whether
  a given arm delivers by file path or stdin is the implementation's call,
  since the `codex` arm hangs on stdin. Wrapper → **1.2.0**.

- **Default `MIN_REVIEWERS` to 1 and reject values below 1.** An explicit
  higher value is honoured; `0` is now an error rather than a silent
  gate-opener.

- **Define a complete review: a verdict *and* a body.** A section counts only
  if it carries both. A verdict alone is not a review — on 2026-07-29T07:52:54Z
  gemini returned a bare `VERDICT: APPROVE` with no body and it counted toward
  the floor. Requiring a verdict, as the previous revision proposed, would count
  it again. A vendor producing output that fails either half is recorded as
  failed, with which half as the reason.

- **Record the implementing host in the artifact; never default it.** The
  previous revision said "the caller supplies an authoritative identity" and
  meant the *invoking* host. That is the wrong party: CI, a pre-commit hook or
  another agent routinely evaluates evidence a different host produced. The
  producer now **requires** the implementing host explicitly, from the closed
  vocabulary `claude|codex|gemini|opencode|pi` — the union of hosts and reviewer
  vendors, since `pi` is a host with no reviewer arm — with no default, and records it in
  `REVIEWS.md`. The gate reads it **from the artifact** and fails closed when it
  is missing or unrecognised. `OPENSPEC_GATE_SELF` is retired as an identity
  source. Duplicate vendors count once.

  This is what keeps the non-goal true for the **gate**: no host shim exports
  anything, and no CI or pre-commit caller fails closed when the default goes.
  It is **not** true of the **producer**, whose calling convention breaks —
  an invocation that worked before now exits with a usage error. An earlier
  revision said "no flag day" without that distinction. Every producer caller is
  inventoried and migrated in this change.

  The vendor vocabulary and the digest's artifact set are both closed lists
  living in three places (spec, producer, gate). Adding a vendor or a reviewable
  artifact is therefore a coordinated edit, not a config change. That is the
  price of having the gate and the producer agree by construction, and it is
  recorded here so the cost is chosen rather than discovered.

- **Specify the verdict format exactly** rather than saying "parseable". The
  shipped regex is not case-insensitive, not end-anchored, and never clears its
  current-reviewer state at a non-reviewer heading, so `REQUEST-CHANGES-LATER`
  matches, a lower-case verdict does not, and a verdict under an unrelated `##`
  section is attributed to the reviewer above it. The delta fixes all three,
  enumerates the vocabulary (`APPROVE` | `REQUEST-CHANGES`), bounds a reviewer
  section at the next heading of level 1 or 2, and makes two conflicting verdicts
  a malformed section rather than an undefined one. Checked against every
  `REVIEWS.md` in the repo so no existing well-formed evidence is invalidated.

- **Report, do not discard.** When the floor is met but fewer reviewers
  succeeded than were requested, the producer SHALL write the reviews it
  obtained. `REVIEWS.md` itself SHALL record which vendors were requested,
  which succeeded, which were excluded, and which failed with the reason — so a
  later reader can tell "not requested" from "failed", without relying on
  ephemeral stderr.

- **Document the egress trust boundary honestly.** The vendors are *agentic*
  CLIs running with the operator's credentials and filesystem access — they read
  beyond the prompt they are handed, including the working tree and
  configuration under `$HOME`. The boundary is **what the vendor CLI can reach
  on this machine as this user** — not the prompt, and not the repository
  either, which an earlier draft claimed. Invoking the producer is consent to
  running the named vendors, not consent to a file set the producer does not
  control. Reviewer output is likewise **untrusted third-party input** that
  lands in `REVIEWS.md` and is then read back by agents — now a requirement in
  the capability delta rather than prose, so nothing quietly drops it. The
  capability states plainly that **no secret or PII screening is performed** and
  recommends checking before invoking; screening is deferred to
  `screen-review-egress`, named and owned rather than gestured at.

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
- **Add**: a reviewer section counts only if it carries a verdict and a body,
  in the grammar the delta specifies.
- **Add**: the implementing host's own vendor never counts toward the floor,
  duplicate vendors count once, and the identity is read from `REVIEWS.md`.
- **Add**: a review is bound to a digest of the artifacts reviewed; a stale or
  digest-less review does not count.

Lines 73 and 80 already state the one-reviewer floor and are unchanged; this
brings the rest of the section into line with them rather than introducing a
new rule.

**§18 is not the only site.** A reviewer objected that repairing §18 alone
leaves the contradiction alive elsewhere, and a grep confirms it. Every one of
these is corrected by this change rather than left to a later sweep:

| Site | What it says |
|---|---|
| `spec/17-lifecycle-and-gate-mapping.md:129` | "`REVIEWS.md` with ≥2 independent reviewers" |
| `spec/02-hook-taxonomy.md:100` | "at least two external AI reviewers" |
| `reference-implementations/openspec-change-gate/README.md:44` | "Default `2`" |
| `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml:4,33` | "≥ 2 independent reviewers" |
| `reference-implementations/reviewer-cli/README.md:34,74,127` | "two independent ones"; "§18's `>= 2` threshold" |
| `reference-implementations/reviewer-cli/reviewer-cli.sh:29,43,59,146` | "(>= 2 DISTINCT external vendors)" |
| `run-plan-review.sh:22,27,38` | "drive >=2 other-vendor agent CLIs"; "default 2" |

`gate/` carries the claim in several more places (`README.md:5` and `:13`,
`openspec-change-gate.sh:24`, `hooks/openspec-gate.ci.yml:19`). That list is
**not** presented as exhaustive: `gate/` is untracked and unclassified, so it is
surveyed rather than corrected. `gate/run-plan-review.sh` is deleted by this
change; the rest is named in the open questions.

**No enforcement floor moves anywhere, in CI or elsewhere.** A reviewer asked
whether lowering the CI floor was intended; a previous revision answered that it
was, and that answer was wrong. `openspec-gate.ci.yml` runs
`openspec-change-gate.sh --ci`, and that gate has defaulted `MIN_REVIEWERS=1`
since **gate 1.4.0** — so **CI already enforces one**, and the `>= 2` lines in the
workflow are stale comments describing enforcement that has not existed for two
gate versions. The producer is the only artifact defaulting to 2, and CI never
invokes the producer.

Pinning CI to 2 was considered on the merits — merging is not time-critical the
way editing is, which is the whole basis of §18's rationale — and rejected: a
second threshold is a second thing to contradict, which is the defect this
change exists to repair. A project wanting a stricter merge bar sets
`MIN_REVIEWERS` in its own workflow.

Text outside this repo — the `agentic-apps-workflow` skill and the operator's
`CLAUDE.md`, both of which state ≥2 — is **not** corrected here. Those are host
artifacts that re-vendor from core. They are named so the contradiction is known
rather than discovered.

## A note on this change's own evidence

`CALLER-INVENTORY.md` and `evidence/` sit in the change directory but are **not
in the digest set**, which covers `proposal.md`, `design.md` and
`specs/**/*.md`. The digest set is exactly what the producer transmits, so
reviewers never receive them and cannot verify claims that rest on them — a
reviewer in round 8 asked for the caller inventory that had been sitting beside
the file it was reviewing.

That is a real limitation of binding the digest to the transmitted set, and it
is accepted rather than fixed here: widening the set would send implementation
scratch to third-party CLIs on every run, and narrowing the claim is cheaper.
Where this proposal relies on the inventory, it states the finding inline
instead of pointing at the file.

**The finding, inline:** no executable caller of `run-plan-review.sh` exists
anywhere in core, `~/.agenticapps/bin/`, the four hosts, the seven projects or
the workflow skill. Every reference is documentation — install echoes, diagram
lines, descriptive JSON. The breaking interface change therefore surfaces as an
interactive usage error naming the missing input, with no unattended job to
fail unattended.

## Impact

**Repos touched (2):** `agenticapps-workflow-core`, and `claude-workflow` for
one edit — repointing `claude-workflow/install.sh` away from its vendored
`bin/run-plan-review.sh` and at core. An earlier revision claimed one repo while
carrying that task; a reviewer checked and both files exist.

That edit does not breach the "not touching the four hosts" non-goal, which is
about **re-vendoring workflow content** to the hosts. It is the opposite: it
removes a vendored copy so core stops being the source of truth only nominally.
The non-goal is scoped to that in the design rather than left to be read as
unqualified.

**Spec version:** §18 changes meaning for any reader who trusted the ≥2
clauses, so `spec_version` in `spec/00-overview.md` goes **1.2.0 → 1.3.0** and
the four hosts are informed at their next re-vendor. Minor, not major: the
enforcement terms are added, and the floor text is corrected to match
enforcement that already exists — no host that conformed to 1.2.0's *behaviour*
becomes non-conformant, though evidence produced under it does become
unverifiable (see below).

**Running behaviour does change — the previous revision said otherwise and was
wrong.** That claim was true only of the floor: the gate has defaulted to ≥1
since **gate 1.4.0**, so the floor edit is text catching up with enforcement.
But gate 1.5.0
adds three enforcement terms that did not exist —

1. a section must carry a verdict **and** a body to count;
2. the implementing-host identity must be present and valid in `REVIEWS.md`;
3. the digest must match the current artifacts.

Every `REVIEWS.md` in existence predates the trailer that carries (2) and (3).
**All of them become unverifiable when 1.5.0 lands**, including the two on this
branch. This is a one-time re-review wave across every project with an open
change, and it is scheduled in the migration rather than discovered in
production. Grandfathering was considered and rejected: it would exempt exactly
the evidence whose staleness motivated the rule.

**Publication is ordered, and the order is load-bearing.** Gate 1.5.0 requires a
trailer only producer 1.1.0 writes, so the producer ships first and the
in-flight changes are re-reviewed before the gate lands. Publishing the gate
first would block every change in every project until each was re-reviewed. The
wrapper is independent and ships last. Rollback is per artifact, in reverse, and
rolling the producer back under a live 1.5.0 gate has the same blocking effect
as the wrong forward order.

**Machine state:** `~/.agenticapps/bin/run-plan-review.sh` is republished at
1.1.0, `openspec-change-gate.sh` at 1.5.0 and `reviewer-cli.sh` at 1.2.0, via
the existing install path. Each gets or keeps a `reference-implementations/`
entry; the producer additionally gets a `resolve-core-artifact.sh` mapping and
the Claude installer is repointed at core rather than its vendored copy. The
version arbiter prevents an older host installer from reverting any of them.

**Behaviour change:** a review run yielding one **counted** reviewer now
writes `REVIEWS.md` and succeeds, where before it wrote nothing and failed.
Runs already yielding two or more counted reviewers are unaffected.

"Counted" is load-bearing and the earlier phrasing dropped it. A run yielding
one reviewer still writes nothing when that reviewer is the declared
implementing host (excluded), returns a verdict with no body, returns a body
with no verdict, or trips a structural guard. The capability requirements are
careful about this; this summary was not, and a skimming reader carries away
the summary.

**The change is more permissive in one direction and stricter in the other.**
The floor drops, so runs that previously failed now succeed. But counting
tightens — verdict, substance, identity and digest are all new conditions — so
some runs that previously succeeded now fail. Both are intended; neither is
"strictly more permissive".

**A known gap, not a fixed one:** when an *explicitly raised* floor is missed,
completed reviews are still discarded. `MIN_REVIEWERS=2` with one good review
writes nothing, exactly as before. The stated goal was to stop discarding
completed reviews, and it is met only for the default floor — the case that
actually bit on 2026-07-29. Preserving evidence from a failed run would need
somewhere to put it that the gate does not read as satisfying the floor, which
is a larger change than this one. A reviewer identified the overclaim in round
7; the goal is narrowed here rather than the gap being papered over.

**Risk of the permissive direction:** a single reviewer is a weaker signal than
three. §18 argues this explicitly and accepts it — the floor sits "where the
guarantee is real: no code without at least one independent opinion". This
change implements that decision; it does not re-litigate it. Callers wanting a
stronger bar set `MIN_REVIEWERS` explicitly.

**Not bundled with `shim-project-hooks`.** That change is reviewed *by* this
machinery; modifying the reviewer inside the change it is reviewing would make
neither result trustworthy.
