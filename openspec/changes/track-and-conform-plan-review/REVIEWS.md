## Reviewer: gemini
_generated 2026-07-29T12:50:33Z · timeout 600s_

VERDICT: REQUEST-CHANGES
- The timestamp format in `Requirement: A reviewer counts only with a verdict and a body` is specified as `<UTC ISO-8601>`, but ISO 8601 has many variants (e.g., with/without milliseconds, `Z` vs `+00:00`). For a spec this precise, "recognised by that shape" is too ambiguous and could lead to parsing inconsistencies. Please specify the exact format string or regex required.
- The grammar for the `implementing-host` list in `Requirement: The trailer has a grammar` is defined as "comma-separated without spaces". This is ambiguous. It should specify whether whitespace is forbidden entirely between values, or if it is merely trimmed by the parser (e.g., `claude, codex` vs `claude,codex`). Please provide a more precise EBNF-style grammar or an explicit statement about whitespace handling.
- In `Requirement: Reviewer output is untrusted input`, the proposal correctly states that the existing `## Reviewer:` guard is not an injection control. However, the risk feels understated. A vendor could return malicious instruction-shaped prose that, while not forging a *reviewer*, could still compromise a later agent that consumes `REVIEWS.md` as context. The spec delta should require that consuming agents treat review content as potentially hostile and sandbox or sanitize it accordingly, rather than just noting the input is untrusted.

## Reviewer: codex
_generated 2026-07-29T12:54:07Z · timeout 600s_

VERDICT: REQUEST-CHANGES

- The change contradicts §16: it declares `spec/*.md` durable while §16 requires `openspec/specs/` as the sole current truth. Archiving these ADDED capabilities would create a second normative source without actually modifying §18.
- Reviewer names have no closed grammar. A valid-looking `## Reviewer: codex-2` or `## Reviewer: arbitrary` can count and evade implementing-host exclusion; restrict headings to the four known vendors.
- Parser rules remain inconsistent: “exactly one verdict” conflicts with repeated identical verdicts counting once, and the non-reviewer-heading scenario conflicts with level-1/2-only section termination. Fenced-block syntax is also undefined.
- The spec-version migration is unspecified. Core is currently 1.2.0, while the change repeatedly attributes behavior to 1.1.0; invalidating all existing evidence is a major tightening under the repository’s versioning policy.
- “Every caller is migrated” conflicts with the claimed one-file Claude edit and deferred workflow-skill update. Existing Claude setup, skill, migration, installer, resolver, and manifest paths require explicit migration.
- The downgrade capability is security-sensitive but lacks an exact interface, artifact allowlist, durable log location/format, mandatory reason grammar, and protection against log injection.
- Invocation is not reliable proof of operator consent when scripts or agents can invoke the producer. A stderr notice is informational; this needs explicit confirmation or an auditable noninteractive consent token before running CLIs with user-level read/write/execute access.

## Reviewer: opencode
_generated 2026-07-29T13:01:54Z · timeout 600s_

I'll verify a few load-bearing factual claims against the repo before issuing the verdict.
VERDICT: REQUEST-CHANGES

Verified against the repo before ruling. The premise checks out (§18 lines 73/80 vs 146/174 contradiction is real; gate 1.4.0 ships `MIN_REVIEWERS:-1` and the unanchored, case-sensitive regex at :205; `gate/run-plan-review.sh` is the 66-line unmarked ancestor). The defects are in the change itself:

**Contradictions inside the change — its own thesis applied to itself**

- **Section-boundary rule is stated two ways.** `design.md:326` and `proposal.md:161` say a reviewer section runs to "the next heading of **any level**"; the normative delta (`specs/change-gate-enforcement/spec.md:34`) says "level 1 or 2" and explicitly denounces "any level" as the rejected previous wording. A change whose entire thesis is "one rule stated once" ships its headline rule in two mutually exclusive versions — in the very artifacts the digest binds and reviewers review. An implementer following design.md builds the truncating parser the delta forbids.
- **Wrong coupling statement in the load-bearing ordering plan.** Migration Plan says "Steps 3 and 4 are coupled — reversing them blocks every change." Steps 3–4 are both producer steps (seed reference impl; modify+publish); reversing them blocks nothing. The actual coupling is producer (4) before gate (8) per Decision 9. The sentence a reader relies on to get the order right names the wrong pair.
- **Two step 9s** in the Migration Plan (design.md:462 "Confirm the re-reviewed changes…" and :472 "Publish reviewer-cli 1.2.0").
- **Version-namespace collision.** design.md:89: gate floor "live since 1.1.0"; proposal.md:267: gate "defaulted `MIN_REVIEWERS=1` since 1.4.0". One means the spec version, one the gate version, and neither says which — the same ambiguity class the change criticises in §18.

**Unverifiable / overstated factual claims**

- **`openspec status` does not report the `specs/**/*.md` glob.** Ran it (openspec 1.6.0): it reports `[x] specs` — no glob. The digest-set rationale "adopting the tool's definition rather than minting a fourth" cites tool behaviour that isn't observable; cite the openspec source/docs or drop the justification and own the choice.
- **"52-case harness"** — the harness (`tools/change-gate-conformance.sh`) exists, but no case count is stated anywhere in the repo; the number is unverifiable as written.

**Under-specification — the defect class this change exists to fix**

- **Trailer "final content" is not decidable.** Trailing blank lines / no trailing newline after `-->`: two conformant parsers split. Specify whitespace tolerance explicitly.
- **Empty-file canonicalisation is ambiguous.** "A trailing LF is appended if absent" — for a zero-byte `design.md`, is the canonical form empty or `\n`? Two implementations disagree on the digest.
- **Malformed trailer *values* have no rule.** Scenarios cover missing/duplicated keys but not a `digest` failing the `sha256:<64 hex>` grammar or a garbage `producer-version`. Fail-closed on malformed values, not just absent ones.
- **Normalisation manufactures verdicts.** Stripping every `*`/`_` line-wide means `VERDICT: REQUEST-_CHANGES` or `V*E*R*D*I*C*T: APPROVE` normalise to valid verdicts. "Cannot merge distinct values" is true; the converse (noise → valid value) is unaddressed. Accept it explicitly or restrict stripping to emphasis runs.
- **Duplicate-vendor mix unspecified:** one vendor with one malformed (conflicting-verdict) section and one well-formed section — count contribution undefined (only the two-well-formed case has a scenario).

**Security / self-defeat**

- **The trailer-delimiter rejection DoSes this change's own review.** Any reviewer quoting the trailer grammar from the spec delta (which literally contains `<!-- openspec-review-trailer v1`) in its response body is rejected as failed. Reviewing *this* change under producer 1.1.0 is the most likely place that happens. The gate already handles two trailers as malformed; the producer rule should distinguish quoted discussion from a parseable second trailer, or acknowledge the trap.
- **reviewer-cli argv fix only closes one channel.** The named threat is "other local processes"; a prompt written to a default-umask file in shared `/tmp` is equally readable. Specify the file's location, permissions and lifetime, or narrow the claimed property to argv.
- **Timestamp grammar uses a non-ASCII `·`** while the digest contract mandates `LC_ALL=C` byte semantics — awk regex matching of a UTF-8 middle dot under the C locale is a portability trap for a shape the substance rule must recognise.

**Scope tension**

- **Caller inventory vs "Repos touched (2)".** The breaking-change requirement says every producer caller SHALL be migrated *in this change*, and tasks 5.8 scopes the inventory to "the four hosts, the seven projects, and the workflow skill." But host edits are a declared non-goal and only 2 repos are touched. Either the hosts'/projects' callers don't exist (say so, making the inventory claim checkable) or migrating them breaches the stated scope. As written the requirement is unsatisfiable within the change's own boundaries.

**Procedural**

- **Spec-first ordering re-creates the divergence window.** Step 1 adds verdict/substance/trailer/digest terms to §18 that no gate enforces until step 8 — for the whole migration the spec mandates what no artifact implements, the exact defect being repaired. Unavoidable perhaps, but it must be acknowledged with an explicit window, not silent.

The analysis quality is high and most round-1..5 findings are genuinely resolved; but a change arguing that under-specification and self-contradiction are the enemy cannot ship both in its own artifacts.

