# ADR-0018: Setup-flow equivalence — a guarded snapshot conforms with §08

**Status:** Accepted
**Date:** 2026-07-14
**Linear:** —
**Spec trajectory:** v0.9.0 (§08 amendment; supersedes ADR-0013's replayability assumption)

## Context

ADR-0013 established the migration framework and, under "Setup ⊕ update
unification", asserted:

> Setup applies migrations from `0000` forward; update applies migrations from
> the project's installed version forward. Same migration files, same runtime,
> same on-disk outcome.

Section 08 encoded that as a Conformance MUST — migrations live in "a single
directory consumed by both setup and update flows" — and the Concept section
cited ADR-0013 as the rationale.

The assumption underneath is that a migration chain is *shell-replayable*: that
"apply migration N" is a mechanical operation a setup flow can execute
unattended, N times, from a clean slate. ADR-0013 itself recorded the seed of
the problem in its own Negative consequences:

> The migration runtime is markdown-skill prose, not executable code.
> Idempotency checks are shell snippets the agent runs; the apply step is
> markdown the agent interprets and writes.

That has since become load-bearing rather than theoretical. `claude-workflow`'s
chain contains steps that are prose (content an agent composes into a file),
agent-driven (a step whose apply is a judgment the agent makes), and
interactive (a step that requires user input). None of those can be replayed by
a script. A fresh-project setup that tried would either hang waiting for input
or silently produce a different shape than the chain describes — the exact
divergence §08 exists to prevent. `claude-workflow` therefore ships a prebuilt
snapshot from setup instead of replaying (host ADR-0036, host issue #74), with
`migrations/check-snapshot-parity.sh` running in CI to prove the snapshot and
the migration sources agree.

Under §08 as written, that host is non-conformant on a MUST — which is
untenable, because it is the reference implementation and the source of this
spec's canonical prose. It is also not an isolated case: `opencode-workflow`
already ships the same pattern ("Installs from a **snapshot, not a migration
replay** (ADR-0007) — `check-snapshot-parity.sh` keeps snapshot ≡ chain
end-state") while its registry row claims `full`. Two of the four scaffolder
hosts have independently converged on guarded-snapshot install, and the spec
has been silently mis-describing both.

The pressure test: §08's MUST was written to prevent *two sources of truth* for
"what does v1.3.0 look like on disk" — the divergent-code-paths risk ADR-0013
names explicitly. Replay-on-setup was the mechanism that delivered that
guarantee, and the spec froze the mechanism instead of the guarantee. A
snapshot assembled from the migration sources and guarded in CI delivers the
same guarantee by a different route: there is still exactly one source of
truth; the snapshot is a build artifact of it, and the guard is what makes that
checkable rather than merely asserted.

## Decision

Amend §08 at spec v0.9.0 so that the **end state of the setup flow is
normative, and the mechanism is not**.

The setup flow MUST produce an end state equivalent to a full `0000`→latest
replay, by one of two conformant strategies:

- **replay** — setup applies every migration from `0000-baseline` forward; or
- **snapshot** — setup installs a prebuilt artifact assembled from the same
  sources, PROVIDED a drift guard runs in CI and fails the build when the
  snapshot and the sources disagree.

A host choosing snapshot MUST name its guard in its instruction file. The
update flow's obligation is unchanged: it consumes the single `migrations/`
directory directly.

This supersedes ADR-0013's assumption that both flows replay. ADR-0013's
*decision* — a versioned, idempotent, atomic, dry-runnable migration framework
as the single source of truth for the on-disk shape — stands unamended. What is
superseded is one assumption about how the setup flow consumes it.

The guard is the load-bearing half of this decision. "Snapshot" without a
mechanical, CI-enforced equivalence check is exactly the second source of truth
§08 forbids; the amendment is not a relaxation of the guarantee, only of the
route to it.

## Alternatives Rejected

- **Force replay — hold §08 as written and require hosts to make their chains
  shell-replayable.** Rejected as impossible, not merely expensive. The
  unreplayable steps are unreplayable by nature: a step whose apply is "the
  agent composes prose appropriate to this project" or "ask the user which
  stack they want" has no mechanical equivalent. Making the chain replayable
  means deleting the prose/agent/interactive steps — i.e. deleting the
  scaffolder's actual value — or degrading them into templated stubs the setup
  flow writes and the user then rewrites by hand. The spec would be dictating a
  worse product to preserve a mechanism it only ever wanted for its guarantee.
- **Leave §08 as-is and let the reference implementation carry a permanent
  `partial`.** Rejected. It makes `full` structurally unreachable for the host
  that authors this spec's canonical prose, on a requirement the host satisfies
  in substance (one source of truth, mechanically guarded) and fails only in
  letter. A conformance level no host can reach while doing the right thing is
  a defect in the level, not in the hosts. It would also strand
  `opencode-workflow`'s existing `full` claim as quietly false, and it teaches
  every future host that the ledger measures mechanism-compliance rather than
  end-state correctness.
- **Permit snapshot unconditionally, with no guard requirement.** Rejected —
  this is the one shape that genuinely reintroduces the divergent-shape risk
  ADR-0013 identified. An unguarded snapshot *is* a second source of truth: it
  can drift from the sources silently, and nothing in the build catches it. The
  guard is what makes the equivalence claim checkable, so it is a MUST, not a
  SHOULD.
- **Specify the guard's implementation (a named script, a fixed diff format).**
  Rejected — same error as freezing replay-on-setup, one level down. Hosts
  differ in what their snapshot is (a directory tree, a tarball, a set of
  skill files) and in what "assembled from the same sources" means mechanically.
  The spec requires that a guard exist, run in CI, fail the build on
  disagreement, and be named in the host's instruction file. How it compares is
  the host's business.
- **Make the setup flow optional / silent on it.** Rejected — setup is where a
  fresh project's entire shape comes from. Saying nothing about it would leave
  the one flow that most needs an equivalence guarantee with none, and the
  original divergent-code-paths risk fully open.
- **Ship this as a major (1.0.0) because a Conformance MUST changed.**
  Rejected per the versioning policy. The amendment is additive/relaxing: it
  strictly widens the set of implementations that satisfy the MUST. Every host
  conformant at 0.8.0 — i.e. every replaying host — remains conformant with no
  action. Nothing is tightened, no canonical block is reworded, no gate is
  removed. That is a Minor.

## Consequences

**Positive:**
- `claude-workflow` can claim `full` at 0.9.0 on the merits, and its registry
  row can state the snapshot install as a conformant strategy rather than an
  undocumented deviation.
- `opencode-workflow`'s existing `full` claim becomes accurate as written; the
  pattern it already ships is now the spec's named second strategy.
- The spec now says what it actually means. "One source of truth for the
  on-disk shape, mechanically proven" is the guarantee; hosts pick the route.
- Future hosts get an explicit, guarded escape hatch instead of either quietly
  deviating (and mis-claiming `full`) or contorting their chain to stay
  replayable.

**Negative:**
- Two conformant setup strategies is more surface than one. A reviewer auditing
  a host must now determine which strategy it uses and, for snapshot hosts,
  verify the guard exists and actually runs in CI — a check that is easy to
  perform shallowly ("a script with the right name exists") and thereby
  worthless. The guard's *effectiveness* is not something §08 can assert from
  the outside; the host's CI has to be trusted to run it and fail on it.
- The equivalence obligation is stated but not independently verifiable by this
  repo. Nothing in `agenticapps-workflow-core` can confirm a host's snapshot
  equals its chain end-state; the spec takes the host's guard at its word.
- "Assembled from the same sources" is deliberately loose. A host could satisfy
  the letter with a generous interpretation of "assembled" while the snapshot
  is substantially hand-maintained. The guard is the only thing standing
  between that and a silent second source of truth.

**Follow-ups:**
- Consider a §09 conformance check for snapshot hosts, mirroring the
  §15 knowledge-capture check block: guard named in the instruction file, guard
  wired into CI, guard fails the build on disagreement. Deferred — the pattern
  has two instances today; a third would justify codifying the review checks.
- `tools/drift-report.sh` has no notion of setup strategy and does not check any
  of this. Out of scope here; the tool has separately tracked defects.

## References

- Migration format spec: section 08 of this repo (amended at v0.9.0)
- ADR-0013 — the migration framework; its "Setup ⊕ update unification"
  assumption is superseded in part by this ADR
- `claude-workflow` ADR-0036 (snapshot install), host issue #74 (the
  unreplayable chain), `migrations/check-snapshot-parity.sh` (its guard)
- `opencode-workflow` ADR-0007 (snapshot install), its own
  `check-snapshot-parity.sh`

---

*This ADR documents a host-agnostic decision. For host-specific bindings (concrete
paths, skill names, plugin invocations), see each host repo's documentation.*
