# Design — one enforcement floor

## Context

Three decisions arrive together because they are one decision seen from three
sides: *how much of this workflow has to know which agent is running it?*

Today the answer is "one hook, three implementations, 320 lines". The claim here
is that the answer can be "none", and that the enforcement it provides survives
the removal because it was never the load-bearing surface.

## Decision 1 — remove the host hook

### Alternatives considered

**A. Remove it entirely.** *(chosen)*

**B. Keep it for claude only.** claude is the host with the most session time on
this machine, so the argument is that the wiring cost falls by two thirds while
most of the benefit is retained.

Rejected. It reintroduces per-host divergence for one host's convenience, which
is the shape this repository exists to remove — and it makes the enforcement
story different depending on which agent you happen to open. It also fails the
standing constraint that there is always more than one agent: a design whose
value depends on one host being dominant is a design that breaks when the mix
changes, and the mix has changed twice already.

**C. Keep all three (status quo).**

Rejected on the measurements in `proposal.md`: it does not enforce
spec-before-code, the condition it does enforce is caught twice more downstream,
and it carries every host-specific line in the repository.

**D. Keep the hook and set `OPENSPEC_GATE_STRICT=1`,** so it blocks edits when
no change is open and becomes genuinely load-bearing.

Rejected, but it is the strongest alternative and deserves its refutation
written down. Strict mode makes the hook enforce something the other surfaces
do not *currently* enforce — but not something they *cannot*. `pre-commit` can
refuse a commit that stages code with no active change using the same
`gate_check` call and the same env var. Choosing the host hook for it buys
earliness and costs three implementations; choosing `pre-commit` buys the same
rule at one. If "no code without a change" is wanted, it should be turned on at
the floor, not used to justify the ceiling.

### What is actually lost

In-session latency, and nothing else. An agent can now write a feature against a
malformed spec delta and learn at `git commit` rather than at the first `Edit`.

This is a real loss and it is accepted rather than argued away. Two things bound
it: the loop runs `openspec validate --all` at step 2, before code, so a
malformed delta is normally caught before an edit is ever attempted; and the
gate is fast, local and deterministic, so the commit-time failure is instant and
legible rather than a delayed CI red.

## Decision 2 — the git floor becomes global

### Alternatives considered

**A. `git config --global core.hooksPath <dir>`, one published hook.** *(chosen)*

**B. Keep the per-repository install (status quo).**

Rejected by measurement. Nine repositories carry the gate's `pre-commit`. They
are **883, 1201, 2270 and 5844 bytes** — four versions of one authority, and
nothing on the machine reports the divergence. A per-repository copy is a fork
that nobody notices has forked, which is the same argument that makes skills
symlinks rather than copies.

**C. Global hooksPath, with per-repository opt-out via a local
`core.hooksPath`.**

Not rejected — this *is* the chosen design, because git already provides it.
Local configuration overrides global, so any repository needing different hooks
sets its own path and is unaffected. It costs nothing to support because it is
not a feature we implement.

**D. Drop the git hook too and rely on CI.**

Rejected. CI is the slowest surface and does not run on most of these
repositories at all. Removing both the host hook and the git hook leaves the
workflow with no local enforcement whatsoever, which is a different and much
larger claim than the one this change makes.

### The displacement risk, measured rather than assumed

`core.hooksPath` **replaces** the hooks directory; it does not add to it.
Verified rather than read: with `core.hooksPath` set, a `pre-commit` in
`.git/hooks/` does not run at all — the global one runs instead, and nothing
reports that the local one was skipped. So a global setting could silently
disable every existing per-repository hook on the machine. That is the objection
that would kill this decision if it held.

It does not hold here. Across `~/Sourcecode`, exactly **nine** repositories have
a non-sample git hook, all nine are `pre-commit`, and all nine are this gate.
There is no husky, no lefthook, no lint-staged, no `pre-push`, no `commit-msg`.
The set displaced by a global binding is empty.

Two honest caveats. The measurement covers this machine, which is the entire
population — but it is a measurement of *now*, and a repository that later
adopts husky would break at that moment rather than at this one. The published
hook therefore has to be composable, which is why the task list requires it to
be a dispatcher rather than a monolith, and why `--check` must report the
binding rather than assume it.

## Decision 3 — drop `--project`

`--project` was deferred from `core-installer-one-entry-point` because it turned
out to be two things: a project-shim installer, and an instruction-file
provisioner core does not have.

Decisions 1 and 2 remove the first of those. Once the gate's `pre-commit` is
bound machine-wide, there is no per-repository hook for `--project` to install.

What remains is the provisioner — writing a workflow section into a project's
`AGENTS.md`. That is not dropped by this change so much as **exposed as the only
thing `--project` was ever going to be**, and it is deliberately left
unaddressed, because whether that section should exist at all is now an open
question rather than a settled requirement (below).

Dropping `--project` also **releases the sequencing constraint** recorded in
`core-installer-one-entry-point`: that `--project` had to land before Phase 5b
deleted the archived checkouts. It no longer does. Phase 5b's remaining blocker
is the codex adapter and opencode plugin — which this change deletes.

## The question this change refuses to answer by implication

`host-neutral-instruction-files` requires a project's `AGENTS.md` to carry
exactly one workflow section whenever an agent is provisioned, and calls a repo
that lists an agent without one "broken: its agents are pointed at a workflow
the file does not describe".

If the trigger skill carries the workflow, is globally installed, and
self-activates, that premise is weaker than when it was written — the agents are
pointed at a workflow the *skill* describes.

This change does not touch that requirement. Repealing a requirement as a
side effect of a change about hooks is how a rule disappears without anyone
deciding it should. It is named here as the most likely next change, and it
needs its own evidence: whether the skill actually loads on every host, and what
a project file is for once behaviour lives elsewhere.

Note the live counter-evidence, which is why this is not a formality: the skill
that loaded in this very session was the 402-line copy from an **archived**
checkout, not core's 235-line v4.0.0. A workflow that lives only in a skill is a
workflow whose delivery is exactly as reliable as skill resolution, and skill
resolution demonstrably picked the wrong file today.

## Risks

| Risk | Mitigation |
|---|---|
| A future repo adopts husky and the global path silently disables it | The published hook is a dispatcher; `--check` reports the binding and whether it is current; git's own local override is the escape |
| An operator has a global `core.hooksPath` already set to something else | The installer refuses to overwrite a foreign binding and reports it, the same posture `install-core-git-hooks.sh` already takes toward a foreign hook |
| Removing the host hook is felt as "the workflow got weaker" | It is weaker in latency and identical in enforcement. `--check` and the run summary should say which surfaces are active rather than leaving it to be inferred |
| Nine stale per-repository copies remain | They become **inert**, not competing — verified: with `core.hooksPath` set, `.git/hooks/` is not consulted at all. They are still removed, because an executable hook on disk that never runs is read by the next person as the one that does |
