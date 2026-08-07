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

### The displacement risk, measured — and the first measurement was wrong

`core.hooksPath` **replaces** the hooks directory; it does not add to it.
Verified rather than read: with `core.hooksPath` set, a `pre-commit` in
`.git/hooks/` does not run at all — the global one runs instead, and nothing
reports that the local one was skipped. So a global setting could silently
disable every existing per-repository hook on the machine. That is the objection
that would kill this decision if it held.

**An earlier revision of this section said it did not hold, and that was false.**
It claimed exactly nine repositories, all `pre-commit`, all this gate, and "no
husky, no lefthook, no lint-staged, no `pre-push`, no `commit-msg`". Re-measured
2026-08-07 across `~/Sourcecode`, resolving each repository's hooks directory
with `git rev-parse --path-format=absolute --git-path hooks`:

- **11 repositories** carry a `pre-commit`, over 10 distinct hooks directories —
  `agenticapps-dashboard-add-agent-board` is a linked worktree sharing the
  dashboard's.
- **15 hook types** are present, not one: `pre-push`, `commit-msg`,
  `post-checkout`, `post-commit`, `post-merge`, `post-rewrite`,
  `prepare-commit-msg`, `pre-rebase` and more.
- **husky ^9.1.7 with lint-staged ^17.0.7** is installed in `fbc-platform`,
  hooks dated 15 July — they predated the original measurement.
- Sizes are **1376, 1201, 2270, 5844 and 39**. Nothing is 883 bytes.

The correction is recorded rather than quietly applied, because this change's
stated virtue is being measured rather than assumed, and on its central safety
claim it was assumed.

### Why the decision survives the correction — for a different reason

Husky is not displaced, and the reason is not that it is absent. `fbc-platform`
sets a **local** `core.hooksPath` of `.husky/_`, and git resolves local before
global. Alternative C — per-repository opt-out via local configuration — is
already doing the work, unprompted, for the one repository that needed it.

So the design is right and its stated grounds were wrong. The premise it
actually rests on is *local overrides global*, not *the set displaced is empty*.

### What that premise costs, which the earlier version did not see

Six repositories already set a local `core.hooksPath`: `claude-workflow`,
`callbot`, `fx-signal-agent`, `agenticapps-dashboard` and its linked worktree at
their own `.git/hooks`, and `fbc-platform` at `.husky/_`.

Local beats global, so **the global binding reaches none of them** — including
three of the five repositories currently carrying the 1201-byte gate. The
override was framed above as a rare escape for a repository that wants different
hooks. It is the majority condition among repositories that carry hooks at all,
and five of the six point at their own *default* directory, which is a no-op
setting that reads as tool-written rather than chosen.

Two consequences follow, and they point in opposite directions:

1. A repository can opt out of the enforcement floor by accident, and nothing
   reports that it has. This is the mirror image of the displacement risk and it
   is the more likely failure, because it is already true.
2. Those five redundant bindings are **safe to unset** — they name the directory
   git would resolve anyway — so the sweep restores global reach without
   changing behaviour in any of them today. `fbc-platform`'s is a real opt-out
   and stays.

The remaining caveat is unchanged and now better founded: a repository that
later adopts a hook manager sets its own path and leaves the floor silently,
so `--check` must report the **effective** binding per repository rather than
assert the global one.

### The composition contract

The published hook must be composable, and the two reviewers who raised this
disagreed about how. One asked that it exec the repository's original
`.git/hooks/`; the other objected that doing so re-enables execution of
repository-controlled code at commit time, which is precisely what `hooksPath`
takes away. Both are right about their own half.

The contract is therefore: the published `pre-commit` dispatches to the gate and
then to an **operator-owned, machine-level `hooks.d`** alongside the published
directory. It SHALL NOT exec anything resolved from inside a repository. That
buys composition for the operator, who is the party that actually wanted it,
without making a clone's contents executable at commit time. A repository that
needs its own hooks has git's local override, which is the supported answer and
costs us nothing to support.

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

## The scope predicate — open, and the reviewers found it

A global binding means the published hook runs in **every repository on this
machine**, including every repository that never opted into this workflow. Two
reviewers raised this independently; it was measured on 2026-08-07 rather than
argued, by installing the reference `pre-commit` into throwaway repositories and
committing staged code:

| Repository shape | Result |
|---|---|
| No `openspec/` directory at all | exit 0, no output |
| `openspec/` present, unrelated content, empty `specs/` and `changes/` | exit 0 |
| `openspec/` containing anything that fails `openspec validate --all` | **exit 1 — commit blocked** |

The first two are the reassuring cases and they behave correctly. **The third is
the defect.** A repository acquires a blocking commit hook by the accident of
containing a directory called `openspec` — a test fixture, a vendored example,
an abandoned experiment, a sample copied from documentation. Nobody in that
repository opted in, and the failure arrives as `commit BLOCKED` with a message
about spec deltas that will mean nothing to them.

This is the difference between the floor being *reachable* everywhere and being
*imposed* everywhere, and the change currently specifies only the first.

### Decided 2026-08-07 — an explicit opt-in marker

A repository is in scope when it carries a local git config key,
`agenticapps.workflow.enrolled`. The published hook checks it first and exits 0
otherwise:

```sh
git config --get agenticapps.workflow.enrolled >/dev/null 2>&1 || exit 0
exec "$GATE" --pre-commit
```

The third row above becomes exit 0, because a fixture repository has no marker.
An enrolled repository with a malformed delta still blocks, which is the whole
point of the floor.

**Alternatives rejected.** *An ownership check on the `openspec/` tree* — in
scope if the tree looks like ours — needs no enrolment step and works on
existing repositories immediately, but it infers intent from shape, so a
vendored example that happens to match still blocks. It makes the failure rarer
without making it impossible, and the failure is silent for the person hit by
it. *A declared repository list* is auditable in one file but is state that
drifts: a new repository is ungated until someone remembers to add it, so it
fails open silently, which is the one posture the floor exists to remove.

The marker wins because enrolment is an act, not an inference. It also makes
`--check` honest — "not enrolled" is a fact it can report, where "does not look
like ours" is a guess.

**What it costs, named rather than discovered later.** Enrolment is a step, so
a repository that should be governed and is not enrolled is silently ungated —
the same failure the declared-list option was rejected for. The difference is
where it can be caught: enrolment happens at project initialisation, which is
already a deliberate act with an owner, and `--check` can name an unenrolled
repository that carries `openspec/`. That check is required, not optional; it is
what keeps the marker from becoming the drifting list under another name.

**Its owner is `init-project.sh`, and that amends the script's stated
contract.** Today its header promises it writes "exactly two things:
`openspec/`, and one instruction file ... No skills, no hooks, no host
configuration." A local git config key is none of those, but it is a third
write, so the header is wrong the moment enrolment lands. The contract is
amended deliberately — to two files and one local git config key — rather than
left to read as a guarantee the script no longer keeps. Recorded as task 2.8b.

## Decision 4 — the floor supersedes core's per-repository hook installer

`install.sh` calls `tools/install-core-git-hooks.sh` on every run, and that call
is what puts a `pre-commit` into whatever repository the installer happens to be
run from. Once the floor is bound machine-wide, that call is the collision
described in the risk table: the helper resolves its destination with
`git rev-parse --git-path hooks`, which honours `core.hooksPath`, so a globally
bound machine redirects it into the published directory.

### Alternatives considered

**A. Supersede: `install.sh` stops calling it.** *(chosen)*

The floor binder takes the helper's variable and its call site — one variable
for one variable, one call for one call. `install-core-git-hooks.sh` is not
deleted. It survives as **core's own tool**, invoked by core rather than by the
machine installer, and the refusal added in the `core-self-enforcement` delta
covers a by-hand run on a globally bound machine.

This is the right shape independent of the budget. Installing a *per-repository*
hook from the *machine-level* installer was always a category error: it wrote
into whichever repository the operator's shell happened to be sitting in, which
is not a property of the machine. The floor is the machine-level act; the local
hook is core's business.

**B. Retarget: keep both call sites.**

Rejected. It preserves the category error, keeps two surfaces writing hooks with
no arbitration between them, and grows the installer by roughly three lines
against zero headroom — so it also forces a budget raise, which A does not.

### The measured consequence

The installer is at **217** with a budget of 217. Under A the arithmetic is
217 → 217 and no raise is claimed. Under B it is 217 → ~220 and the escape
clause would have to be invoked. The budget did not decide this, but it is the
cheaper option on the axis the specification actually constrains.

### What A costs, and it is not nothing

Nothing then establishes core's own local binding. `install.sh` was doing it as
a side effect, and `core-self-enforcement` now *requires* core to carry a local
`core.hooksPath` and makes its absence a CI failure. The delta says core SHALL
have one; it does not say who creates it. That is a real gap this decision
opens, and it is recorded as task 3.5 rather than assumed to resolve itself.

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

The counter-evidence this section used to cite has since been overtaken, and the
correction matters in both directions. It read: *the skill that loaded in this
very session was the 402-line copy from an archived checkout, not core's
235-line v4.0.0*. That was true when written. It is **false as of 2026-08-07**:
`~/.claude/skills/agentic-apps-workflow` now resolves to core's v4.0.0, the
hyphenless 402-line duplicate no longer exists on this machine, and
`fresh-clone-needs-nothing` fixed it — `LEGACY_DIRS` in `install.sh` removes the
copied duplicate, and the sweep rebinds the archived link.

So the delivery risk was real and is now closed on this machine. What it does
**not** license is repealing the requirement by implication, and the reason has
changed rather than disappeared: one machine resolving correctly after a
targeted fix is evidence about one machine, not about skill resolution as a
delivery mechanism. Open question 9.7 records that `scan_archived` walks skill
directories only and structurally cannot see command directories — two links
into an archived checkout survived every install that way. The deferral
therefore stands on its original grounds, with its evidence bar unchanged:
whether the skill actually loads on every host, and what a project file is for
once behaviour lives elsewhere.

## Risks

| Risk | Mitigation |
|---|---|
| A repo adopts husky and the global path silently disables it | Already the case in `fbc-platform`, and already handled: husky sets a local `core.hooksPath`, which git prefers over the global one. `--check` reports the effective binding per repository so the opt-out is visible rather than inferred |
| A repository leaves the floor by accident, via a local `core.hooksPath` nothing reports | The more likely failure and already true in six repositories. Five are redundant and are unset by the sweep; `--check` names any repository the floor cannot reach |
| Core's own git-hook installer collides with the global binding | `tools/install-core-git-hooks.sh` resolves via `git rev-parse --git-path hooks`, which honors `core.hooksPath` — so once bound globally it writes into the machine-level directory, either refusing forever on a foreign marker or publishing core's working-tree-resolving hook to every repository. **Decision 4 removes the collision at its source: `install.sh` no longer calls it**, so the machine installer never triggers the redirect. The `core-self-enforcement` delta's refusal — destination outside the git *common* directory — covers a by-hand run on a bound machine, which is now the only way to reach it |
| Nothing establishes core's local binding once the installer stops calling the helper | Opened by Decision 4 and tracked as task 3.5. `core-self-enforcement` requires the binding and makes its absence a CI failure, so the gap is loud rather than silent — but it is unassigned until 3.5 names an owner |
| An operator has a global `core.hooksPath` already set to something else | The installer refuses to overwrite a foreign binding and reports it, the same posture `install-core-git-hooks.sh` already takes toward a foreign hook |
| Removing the host hook is felt as "the workflow got weaker" | It is weaker in latency and identical in enforcement. `--check` and the run summary should say which surfaces are active rather than leaving it to be inferred |
| Nine stale per-repository gate copies remain — 10 distinct hooks directories, less `fbc-platform`'s husky | They become **inert**, not competing — verified: with `core.hooksPath` set, `.git/hooks/` is not consulted at all. They are still removed, because an executable hook on disk that never runs is read by the next person as the one that does |
