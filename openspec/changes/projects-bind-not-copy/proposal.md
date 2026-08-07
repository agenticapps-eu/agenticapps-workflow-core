## Why

Core publishes one trigger skill — `agentic-apps-workflow`, 235 lines, v4.0.0 —
and `core-installer-one-entry-point` bound it into all five host directories on
2026-08-06. **Eight fleet repositories still carry their own committed copy in
`.claude/skills/`**, and a project-local skill sits in front of the host one. The
change that was supposed to end "two files claiming to be the same skill" ended
it for hosts and left it standing for projects.

The copies are not merely old. They are inconsistent with each other:

| Repo | family | copy |
|---|---|---|
| agenticapps-dashboard | agenticapps | 331 lines, v3.2.0 |
| agenticapps-roadmap | agenticapps | 324 lines, v3.2.0 |
| agents-task-viewer | agenticapps | 324 lines, v3.2.0 |
| agenticapps-dashboard-add-agent-board | agenticapps | **415 lines, v3.0.0** |
| callbot | factiv | 324 lines, v3.2.0 |
| cparx | factiv | 324 lines, v3.2.0 |
| fbc-platform | factiv | **346 lines, v3.2.0** |
| fx-signal-agent | factiv | 324 lines, v3.2.0 |

Four byte-sizes, two claimed versions, and `fbc-platform` differs from its three
v3.2.0 siblings while claiming to be them. This is the exact condition core's own
`CLAUDE.md` describes — *"which one loads is down to loader ordering"* — measured
in eight repositories rather than argued about.

It matters now because the host bindings just moved. Until 2026-08-06 the host
copy was also stale, so a project copy shadowing it changed little. Today the
host resolves to v4.0.0 and the project copy does not, so every one of those
eight repositories is the only place on this machine still running the old
workflow.

## What Changes

- **BREAKING for those repositories:** `.claude/skills/agentic-apps-workflow/` is
  deleted from all eight. Work in them resolves the host-bound skill instead, the
  way every other directory on this machine already does.
- **A capability states that a project does not carry its own copy of a
  core-owned skill**, so this is a rule with a home rather than a cleanup that
  happens once and decays.
- **A fleet check enforces it**, in the shape core already uses for hooks: a
  declaration that does not shrink when the thing it describes goes missing, and
  a check that reports a repository it cannot find rather than passing silently.
  `tools/check-shims.sh` is the model.
- **No installer mode is added.** Projects are not bound; they are *unbound*, and
  they see the skill because the host binding covers every directory on the
  machine. `--project` was superseded by `one-enforcement-floor` and this change
  does not revive it.
- **Out of scope, deliberately: the six `openspec-*` skills** each repo also
  carries. Those are upstream OpenSpec's, MIT-licensed, declaring *"Requires
  openspec CLI"*, and installed per-project by that tool. They are not ours to
  collapse, and deleting them would break `/opsx:*` in every repo.

## The project hook surface is host-specific, and that is the whole argument

`core-installer-one-entry-point` deleted the host hook for three reasons: with no
active change the gate returns satisfied so it never enforced spec-before-code;
the condition it did enforce is caught again at `git commit` and in CI; and it
was every host-specific line in the repository. The gate's own header makes the
case against itself — a `PreToolUse` hook "cannot gate the session that installed
it, and it does not exist at all for a human with an editor."

**All three reasons apply verbatim to the project hook**, because
`.claude/settings.json` is Claude-only whether it sits in `$HOME` or in a
repository. Codex, opencode, pi and omp read nothing from it. The change deleted
the host-specific surface and left an identical one committed in nine
repositories.

Measured in `cparx` on 2026-08-07, and it is worse than redundant:

- no `.git/hooks/pre-commit`
- `core.hooksPath` unset, globally and locally
- the **only** invoker of the gate shim is the `PreToolUse` entry

So the gate fires at neither of the two surfaces `docs/HOW-IT-FITS-TOGETHER.md`
claims for it. In that repository the "two surfaces" are zero, and a Claude-only
hook that returns satisfied whenever there is no active change is the entire
enforcement story. The doc is also internally inconsistent — it says one gate,
two surfaces, then describes projects binding it at a third.

**A git hook is not a host hook, and this change does not touch it.**
`one-enforcement-floor`'s machine-wide `core.hooksPath` binding fires for all
five hosts and for a human with an editor; it is host-agnostic by construction
and it is the floor. What goes is `.claude/settings.json`.

### `database-sentinel` is removed, and this is the decision

An earlier revision of this section said the hook "is decided rather than
assumed either way, and the change states which" — and then stated neither.
Both plan reviewers caught it. It is decided here: **the hook is removed with
the surface.**

The reasoning, arm by arm, because the three do not have the same answer:

- **The `.env` arm is redundant and largely ineffective.** It blocks
  `Edit`/`Write`/`MultiEdit` against a `.env` path, but the likeliest way an
  agent writes that file is `cat > .env` through `Bash`, which presents no
  `file_path` for the arm to match. What it does catch, `cso`'s secrets
  archaeology finds and the host's own permission prompts intercept.
- **The `DROP TABLE` / `TRUNCATE` / `DELETE`-without-`WHERE` arms are the real
  loss**, and the change SHALL NOT pretend otherwise. They are the only
  interception of an **irreversible** action anywhere in this workflow, and the
  argument that retired the host hook — "the condition it enforces is caught
  again at `git commit` and in CI" — is simply **false** for them. Destructive
  SQL never enters git. No downstream surface sees it.

It is removed anyway, for the reason that outweighs that: it protects Claude
sessions only. Codex, opencode, pi and omp get nothing from it, and multi-agent
is a permanent condition rather than a phase. A guard that covers one of five
hosts is not a floor, and keeping it would leave the host-specific surface alive
for a single hook while this change calls that surface closed. Its own header
already declines the credit — *"THIS IS NOT a security boundary… `psql -f
script.sql` never presents the SQL to the regex… a speed bump, not a control."*

**What replaces it is named rather than left implicit.** The destructive-SQL
protection belongs at the host's own permission layer — a Bash deny rule in the
operator's configuration — which is host-specific by nature and therefore the
operator's to hold, not core's to ship. This change SHALL record that as the
mitigation and SHALL NOT claim the protection survives the removal.

**One consequence looked like a free improvement and is not free. Corrected.**

An earlier revision said `SHIMMED-HOOKS` "declares exactly two hooks", so
removing `database-sentinel` alongside the gate's project binding would leave it
empty and dissolve the objection that `OPT-OUTS` can sanction a *missing*
binding but never an *extra* one.

**On `main` it declares three** — `database-sentinel`, `normalize-claude-md`,
`openspec-change-gate`. The two-entry reading came from this branch's working
tree, which is **stacked on `chore/retire-normalize-claude-md`** (PR #87) and
already carries that removal. A post-#87 state was presented as the pre-change
state, which made the argument circular: the empty declaration depends on #87
landing, and this document twice forbids #87 from landing first.

The end state is still empty and still worth having. What is not true is that it
arrives for free from this change alone. It requires #87, and #87's ordering
constraint has to be restated as a **coordinated landing** rather than a
sequence — see the sequencing section below, which an earlier revision also got
wrong.

## The same shape, in the wiring

The skill copies are one instance of a general condition: **a project holds
something core does not sanction, and nothing looks.** The other instance is
live.

Six fleet repositories bind `normalize-claude-md` — a `PostToolUse` hook that
rewrites `CLAUDE.md` on every edit. On `main` that is correct; the hook is
declared. The change retiring it removes it from `ARTIFACTS` and `SHIMMED-HOOKS`
**and leaves all six bindings in place**, so the moment that retirement merges,
six repositories are binding a hook the fleet no longer declares.

> **The count was seven in an earlier revision and it was wrong.** Measured
> 2026-08-07: `agenticapps-dashboard`, `agenticapps-roadmap`, `callbot`,
> `cparx`, `fbc-platform` and `fx-signal-agent` bind it; **`agents-task-viewer`
> does not**. The seventh was the worktree — which this change is the one
> declaring is not a fleet member, so reaching seven required breaking its own
> rule. Corrected here and in `session-handoff.md`.

It does not stop running when that happens. `install-project-hooks.sh` carries
forward manifest rows outside the declared set by design, so the implementation
stays in `~/.agenticapps/bin/` and the shim keeps resolving it — a retired hook,
published by nothing and attested by nothing, editing the instruction file every
host reads. If the file is ever pruned, the shim fails open and reports hourly,
advising an installer run that would re-publish an implementation deliberately
withdrawn.

**The conformance check cannot see any of this**, because it iterates the
declaration: for each declared hook, is it bound with the authority's bytes. That
detects a missing member, which is what `ARTIFACTS` was written to detect. It is
blind to an extra one. A conformance run inspected those same six repositories
on 2026-08-06 and reported "every declared hook is bound with the authority's
bytes" — true, complete, and silent about the extra binding in each of them.

So this change covers both surfaces. Skills and hooks are the same rule wearing
two names, and splitting them would leave the second one to be rediscovered.

## Capabilities

### New Capabilities

- `project-skill-binding`: what a consuming project may and may not carry in
  `.claude/skills/`, how it obtains a core-owned skill, and how the fleet is
  checked for copies. The counterpart to `project-hook-binding`, which already
  says the equivalent thing about hooks.

### Modified Capabilities

- `project-hook-binding`: gains the requirement that **the workflow binds no
  host-specific hook surface** — `.claude/settings.json` is Claude-only wherever
  it sits, and the enforcement floor is the machine-level git hook, which is not.
  Plus: a project binds no hook the declaration does not name; retiring a hook and
  removing its bindings are not separated across releases; and the fleet check
  walks **both** directions, one pass asking whether anything declared is
  missing, one asking whether anything held is undeclared. The capability governs
  shims thoroughly and never said what happens to a binding whose declaration
  goes away, nor why a surface deleted at `$HOME` was kept in the repository.
- `workflow-installation`: the "skills are bound by symlink and never copied"
  requirement currently scopes itself to host skill directories. The prohibition
  on copies is stated as a general principle — *"a copied skill is a second
  version that no update reaches"* — and then enforced only for hosts. It should
  say which surfaces it governs, and name the project surface as governed by
  `project-skill-binding` rather than leaving the reader to infer that projects
  were considered.

## Impact

- **Eight repositories across two families**, four of them in `factiv`
  (`callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`) and four in
  `agenticapps`. Cross-family work, so it needs saying out loud: this touches
  repositories outside the family the change lives in.
- `agenticapps-dashboard` is **retired** (2026-08-05) and
  `agenticapps-dashboard-add-agent-board` is a worktree of it. Whether a retired
  repository is worth a PR is a judgement this change has to make rather than
  discover halfway through.
- **`tools/`** gains a check; the `FLEET` declaration already lists seven of the
  repositories and is the natural place to resolve them from.
- **No change to `install.sh`.** Its budget, its modes and its tests are
  untouched, which is the main reason this is a separate change and not an
  amendment to a spec archived yesterday.
- **This change SHALL NOT land before `one-enforcement-floor`.** Its own
  measurement is the argument: `cparx` has no `pre-commit` and no
  `core.hooksPath`, so the `PreToolUse` entry this change deletes is the *only*
  gate that repository has. Removing it first leaves `cparx` with nothing rather
  than with something better. The requirement text asserts "the enforcement floor
  SHALL be the machine-level git hook" as though that floor already existed in
  `cparx`; it does not until `one-enforcement-floor` binds it. An earlier
  revision recorded the dependency on `core-installer-one-entry-point` for the
  skill half and omitted this one for the hook half.
- **The removals are only safe because the host binding landed first.** If
  `core-installer-one-entry-point` were reverted, deleting these copies would
  leave those repositories with no workflow skill at all. The ordering is a
  dependency, and it is stated in `design.md`.
- **PR #87 and this change land together, and an earlier revision had this
  wrong.** It said #87 "SHALL NOT merge before the hook sweep here lands" — a
  strict ordering. But `feat/projects-bind-not-copy` is **stacked on**
  `chore/retire-normalize-claude-md`: #87's commits are ancestors of this
  branch's HEAD, verified with `git merge-base --is-ancestor`. So this change
  cannot merge unless #87 merges first or with it, which is precisely what the
  document forbade. The git topology contradicted the spec.

  It is a **coordinated landing**, not a sequence, and the reason the original
  framing failed is worth keeping: whichever lands alone, the fleet goes red in
  one direction or the other. #87 first leaves six repositories binding an
  undeclared hook — the reverse pass fails, which is this change's whole point.
  The sweep first leaves a declared hook unbound — the forward pass fails. There
  is no ordering that is green throughout, which is why "retirement and removals
  SHALL NOT be separated across releases" cannot be satisfied by ordering alone.

  Two ways to discharge it, and the change SHALL pick one rather than leave the
  interim undefined: land #87 and the sweep in a single merge, or sanction the
  interim explicitly with a transition entry the check honours. The second is
  the `OPT-OUTS` axis this change was happy to dissolve, which is an argument
  for keeping that mechanism rather than removing it.
- **`tools/check-shims.sh` gains a second pass** and therefore a second way to
  fail. Repositories that pass today may not after, which is the point.
