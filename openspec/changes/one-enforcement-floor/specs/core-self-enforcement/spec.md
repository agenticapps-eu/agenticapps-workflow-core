## MODIFIED Requirements

### Requirement: Core provides and registers the gate against its own repository

The core repository SHALL provide and register the §18 change gate against
itself at two interposition points it owns — a git `pre-commit` hook and a CI
job — and SHALL be governed by the machine-level enforcement floor for
everything else. Publishing an enforcement artifact SHALL NOT be accepted as a
substitute for running it.

**The `PreToolUse` hook is removed, and this requirement is amended rather than
left to contradict the change that removes it.** The unamended text mandated
three points, the first of which was "a `PreToolUse` hook registered in
`.claude/settings.json`" — precisely what this change deletes across the fleet,
core included. A durable requirement that mandates what an active change removes
is not a tension to be noted in prose; one of the two is wrong, and it is the
requirement, because the reason the hook went is that a per-host session hook
cannot gate the session that installs it and does not exist for a human with an
editor.

**"Provides and registers", not "runs".** The `pre-commit` hook is written by an
installer and is absent until that installer is run, so a requirement that core
*runs* the gate would be unsatisfiable in any fresh clone — and would contradict
this capability's own "the installer was never run" scenario, which explicitly
blesses that state. The obligation is on what the repository ships and wires,
which is what core controls.

**§18 requires an interposition point, and no surface SHALL claim it requires
these two.** §18's requirement is a `PreToolUse` hook (or host equivalent); it
mentions `pre-commit` and CI only as *evaluating contexts* whose reviewer
identity must come from the trailer rather than the environment. With the host
hook removed, core satisfies §18 through the host-equivalent floor, and the two
points named here are core's own additions, adopted because core authors the
gate and wants drift caught at commit time and on the pull request.

**Neither is a guarantee, and the requirement SHALL NOT claim otherwise.** The
`pre-commit` hook is delivered by an installer and is absent until that
installer runs. The CI job's verdict blocks a merge only where a repository
setting requires the check, and core's `main` carries no branch protection and
no rulesets — so the CI job **reports** rather than enforces. Whether a verdict
blocks a merge is a repository setting outside this capability's scope.

**What the removal costs is stated rather than netted out.** The `PreToolUse`
hook gated an edit before it was written, regardless of any commit flag. Both
remaining local points are commit-time, and `git commit --no-verify` bypasses
one of them. Core keeps CI, so core is the best-covered case; a repository
without CI is left with one surface and a documented bypass, which is the
trade this change makes and does not conceal.

#### Scenario: Both owned interposition points run the gate

- **WHEN** the core repository is inspected for gate wiring
- **THEN** a CI workflow exists that runs the gate on pull requests and on pushes to `main`
- **AND** an installer exists that writes the `pre-commit` hook into the repository's resolved hooks directory
- **AND** no `PreToolUse` hook SHALL be required in `.claude/settings.json`

#### Scenario: A host session hook is present anyway

- **WHEN** a `PreToolUse` hook registered against the gate is found in core
- **THEN** it SHALL be reported as a surface this capability no longer requires
- **AND** its presence SHALL NOT be treated as satisfying any part of this
  requirement, since a surface nothing specifies is a surface nothing maintains

#### Scenario: The CI verdict does not block a merge

- **WHEN** the CI job fails on a pull request against `main`
- **THEN** the failure SHALL be visible on the pull request
- **AND** the merge SHALL NOT be prevented by this capability
- **AND** no surface SHALL describe the CI job as an enforced floor

#### Scenario: Publishing is not running

- **WHEN** core ships a gate, a wrapper or a CI template for other repositories to consume
- **THEN** that act SHALL NOT discharge this requirement
- **AND** core SHALL still run the gate against itself

#### Scenario: The gate does not observe every edit path

- **WHEN** a file is modified through `Bash` — by `sed -i`, `tee`, a redirect or a script
- **THEN** the commit-time points SHALL still observe it, because they read the index rather than the tool call
- **AND** the capability SHALL NOT describe its interposition points as complete coverage

### Requirement: Core resolves its own reference implementation

Core's three interposition points SHALL resolve
`reference-implementations/openspec-change-gate/openspec-change-gate.sh` from
the working tree, and SHALL NOT prefer the shared install at
`~/.agenticapps/bin/openspec-change-gate.sh`.

Core is the source of truth for that file. Gating core with a published copy
would prove nothing about the bytes core ships, and in CI no shared install
exists at all. This resolution order is deliberately the inverse of the one
every consuming project uses, and SHALL be documented in
`adrs/0028-core-gates-itself.md` and in `docs/WORKFLOW.md`.

**The machine-level floor does not reach core, and that is deliberate.** The
enforcement floor is now published once and bound through a global
`core.hooksPath`. One file serving every repository necessarily resolves the
shared install, which is exactly what this requirement forbids for core. Core
SHALL therefore set a **local `core.hooksPath`**, which git prefers over the
global binding, and SHALL keep a `pre-commit` in that directory resolving the
working-tree gate.

This is not an exception carved out for convenience. It is the same mechanism
the floor already offers every repository that needs different hooks — core is
simply the repository whose different hook is a documented invariant rather than
a preference. What changes is that the binding becomes **load-bearing**: before
the global floor existed, core's local resolution happened by default and no
configuration expressed it. It must now be explicit, because the default has
moved.

An explicit `OPENSPEC_GATE` override is retained and is **not** a violation of
the above: the prohibition is on *silently preferring* the published copy, which
is what a resolution-order fallback does. Setting an environment variable is a
deliberate operator act, it is required to test the fail-open path, and §18
requires the gate be demonstrable by direct invocation. The override SHALL be
documented wherever the resolution order is documented.

**Its weakness SHALL be disclosed rather than argued away.** "A deliberate
operator act" describes setting the variable, not every occasion it is read: an
`OPENSPEC_GATE` exported once in a shell profile is ambient thereafter, and
silently redirects core's local gate to a foreign copy on every subsequent
session — which is the same class of silent divergence the resolution inversion
exists to remove, re-entering by a door this capability holds open. It is kept
because removing it would leave the fail-open and direct-invocation paths
untestable, and because a local override cannot affect CI, where no such
environment exists and the verdict that gates the pull request is produced. That
is a trade accepted with its cost named, not a property the override lacks.

#### Scenario: An explicit override is honoured

- **WHEN** `OPENSPEC_GATE` names an executable and a local interposition point runs
- **THEN** that executable SHALL be used
- **AND** this SHALL NOT be treated as preferring the shared install, which is reached only by a fallback the resolution order does not contain

#### Scenario: The working-tree copy is preferred over a present shared install

- **WHEN** an executable gate exists at `~/.agenticapps/bin/openspec-change-gate.sh` whose behaviour differs from the working-tree copy
- **THEN** both the `PreToolUse` hook and the `pre-commit` hook SHALL execute the working-tree copy
- **AND** the shared install SHALL NOT be consulted

#### Scenario: The machine is bound by the global floor

- **WHEN** `core.hooksPath` is bound globally to the published hooks directory
- **THEN** core SHALL set a local `core.hooksPath` that git prefers
- **AND** a commit in core SHALL run the working-tree gate, not the published one

#### Scenario: Core's local binding is absent

- **WHEN** a commit is attempted in core while the global binding is in force and
  core has no local `core.hooksPath`
- **THEN** the published hook runs and core is gated by the shared install
- **AND** core's CI job SHALL fail, because it is the only surface whose verdict
  someone is obliged to look at
- **AND** `--check` SHALL also report it, as the local diagnosis
- **AND** the condition SHALL NOT be reported only by `--check`, which nobody
  runs until they already suspect something

#### Scenario: The shared install is absent

- **WHEN** the gate runs in CI, where `~/.agenticapps/` does not exist
- **THEN** the gate SHALL still resolve and run from the working tree
- **AND** the job SHALL NOT fail for want of a shared install

#### Scenario: The resolution order is inverted relative to projects

- **WHEN** core's resolution order is compared with a consuming project's shim
- **THEN** core SHALL prefer the working-tree copy and the project SHALL prefer the shared install
- **AND** core SHALL record the reason for the inversion in the two documents named above

The repository root SHALL NOT be derived from the process working directory.
A `PreToolUse` hook runs in whatever directory the session currently holds, and
that directory changes during a session; deriving the root from it meant one
`cd` outside the repository made resolution fail, which the fail-open branch
then reported as an ungated edit. The wrapper SHALL resolve the root from a
fixed point — the host-provided project directory, falling back to the
wrapper's own location — so that resolution does not depend on session state.

Silent ungating is the one outcome this wrapper SHALL NOT have. Failing open on
genuinely absent tooling is deliberate; failing open because the wrapper could
not work out where it was is a defect.

#### Scenario: The session's working directory has moved

- **WHEN** an edit is attempted while the session's working directory is outside the repository
- **THEN** the wrapper SHALL still resolve and execute core's working-tree gate
- **AND** SHALL NOT report the edit as ungated

### Requirement: The pre-commit installer resolves the real hooks directory

Because the hooks directory is not tracked by git, core SHALL provide an
installer that writes the `pre-commit` hook, and the installer SHALL resolve the
destination rather than assume it.

The installer SHALL obtain the hooks directory from `git rev-parse --git-path
hooks`. It SHALL NOT write to a literal `.git/hooks/` path: in a linked git
worktree `.git` is a file rather than a directory, so that path does not exist,
and the real hooks directory belongs to the main checkout.

`git rev-parse --git-path hooks` **honors `core.hooksPath`**: with that setting
configured the command returns the configured directory, not the default. The
installer SHALL therefore rely on the resolver rather than inspect the setting.
It SHALL NOT refuse merely because `core.hooksPath` is present — a hook written
to the resolved path fires normally, so such a refusal would be a false
positive, including in the degenerate case where the setting names the default
directory.

**One new refusal is required, and it exists because the resolver is now a
hazard.** Since the enforcement floor is bound machine-wide, a resolver that
honours `core.hooksPath` will, in a repository with no local binding, return the
**machine-level published directory**. Writing there would either be refused
permanently — the published hook carries a different ownership marker and is
correctly read as foreign — or, if the markers ever coincide, would publish
core's working-tree-resolving hook to every repository on the machine. The
second outcome is severe and silent: every repository would begin gating against
whatever happens to be in core's checkout.

The installer SHALL therefore refuse when the resolved hooks directory lies
outside the repository's **git common directory** — `git rev-parse
--path-format=absolute --git-common-dir` — report the global binding as the
cause, and name the local `core.hooksPath` that would fix it. This is a refusal
about *destination ownership*, distinct from the containment refusal below,
which is about writing into repository content.

**The predicate is the common directory, not the working tree, and the two must
not be confused.** An earlier revision of this delta said "outside core's own
git directory" while the requirement below says the installer SHALL install when
`core.hooksPath` names a directory *outside the working tree* — and `.git/hooks`
is outside the working tree, so the two read as contradictory. The common
directory resolves it: `.git/hooks` is inside it and installs normally; the
machine-level published directory is outside it and is refused. It is
specifically the **common** directory rather than the git directory because in a
linked worktree the real hooks directory belongs to the main checkout, and a
predicate using `--git-dir` would refuse every legitimate install performed from
a worktree.

One case does warrant refusal: when the resolved hooks directory lies **inside
the working tree**, installing would write into repository content rather than
local, untracked configuration. Placing a hook into the repository is a
different act with different consequences, so the installer SHALL report and
exit non-zero rather than make that decision silently.

The predicate SHALL be **path containment**, and nothing adjacent to it. Two
adjacent predicates have each already produced this bug:

- *Tracking status.* `git ls-files --error-unmatch` fails for an untracked
  in-tree directory, which the installer read as permission to write. An
  untracked path inside the tree is still repository content.
- *Existence.* Containment SHALL be decided for a directory that does not yet
  exist, since the installer creates missing parents. Canonicalising by
  `cd`-ing to the path cannot resolve one that is absent, and resolving only
  its immediate parent fails when that is absent too — which yielded a path
  outside the tree and installed a hook inside it.

The installer SHALL therefore canonicalise by resolving the deepest **existing**
ancestor and re-appending the remaining components.

#### Scenario: The resolver returns the machine-level published directory

- **WHEN** the installer runs in core while a global `core.hooksPath` is bound
  and core has no local binding
- **THEN** it SHALL refuse and exit non-zero
- **AND** SHALL report that the global floor redirected the resolver
- **AND** SHALL NOT write into the machine-level published directory

#### Scenario: The installer runs from a linked worktree of core

- **WHEN** the installer runs in a linked worktree whose hooks directory belongs
  to the main checkout
- **THEN** the destination is inside the git **common** directory and installs
  normally
- **AND** SHALL NOT be refused as foreign on the grounds that it lies outside
  the worktree's own git directory

#### Scenario: Core carries its own local binding

- **WHEN** the installer runs in core where a local `core.hooksPath` names
  core's own hooks directory
- **THEN** it SHALL install normally
- **AND** SHALL NOT refuse on the grounds that a global binding exists

#### Scenario: Installation inside a linked worktree

- **WHEN** the installer runs in a linked worktree, where `.git` is a file
- **THEN** it SHALL resolve the hooks directory via `git rev-parse --git-path hooks`
- **AND** SHALL NOT attempt to create or write a literal `.git/hooks/` path
- **AND** SHALL report that the hook it installs is shared with the main checkout

#### Scenario: core.hooksPath points outside the working tree but inside the git common directory

- **WHEN** the installer runs where `core.hooksPath` names a directory outside
  the working tree and inside the repository's git common directory — of which
  `.git/hooks` is the ordinary case
- **THEN** it SHALL install into the directory the resolver returns
- **AND** SHALL NOT refuse on the grounds that the setting is present

> **Narrowed deliberately.** This scenario previously said "outside the working
> tree" with no upper bound, which contradicted the refusal above: the
> machine-level published directory is *also* outside the working tree, and this
> scenario would have required installing into it while the refusal required
> declining. The prose already named the common directory as the predicate; the
> scenario had not been narrowed to match, so a reader following scenarios alone
> would have implemented the defect.

#### Scenario: core.hooksPath names the default directory

- **WHEN** `core.hooksPath` is set to the same directory the resolver would return by default
- **THEN** the installer SHALL install normally
- **AND** SHALL NOT report a conflict

#### Scenario: The resolved hooks directory is inside the working tree

- **WHEN** the resolved hooks directory lies inside the working tree
- **THEN** the installer SHALL report this and exit non-zero
- **AND** SHALL NOT write a hook into repository content
- **AND** SHALL refuse whether or not that directory is tracked by git

#### Scenario: The resolved hooks directory is inside the tree but does not exist

- **WHEN** `core.hooksPath` names a path inside the working tree whose directory
  and whose parent are both absent
- **THEN** the installer SHALL still recognise it as inside the tree and refuse
- **AND** SHALL NOT create the missing parents and report success

#### Scenario: The hooks path re-enters the tree through an absent `..` segment

- **WHEN** `core.hooksPath` begins outside the working tree and returns into it
  through a `..` segment whose preceding directory does not exist
- **THEN** the installer SHALL normalise the path before deciding containment
- **AND** SHALL refuse, rather than accepting the unnormalised string as outside
  the tree and then creating the absent segment

## ADDED Requirements

### Requirement: Core's local hooks binding is declared, and the fleet sweep does not remove it

The installer's sweep of redundant local `core.hooksPath` settings SHALL NOT
unset core's.

The sweep's rule is that a local binding naming the directory git would resolve
anyway grants no behaviour and is safe to remove. **Core is the one repository
where that reasoning is false.** Its binding names its own default hooks
directory and is therefore syntactically redundant, but removing it hands core
to the machine-level floor and breaks the resolution inversion this capability
exists to protect. A rule that reads only the *value* of the setting cannot tell
the two cases apart.

Core's binding SHALL therefore be **declared** rather than inferred, so that the
sweep excludes it by name and not by accident, and so that a reader can see it
is intentional. A binding that is load-bearing and looks redundant is exactly
the thing a future cleanup removes with a good conscience.

**The binder establishes it, in the same act that creates the hazard.** Setting
the global binding is the moment core's own hook stops being preferred; the
binder is the only thing that knows both facts at once, and it runs from inside
core's checkout by construction. So it SHALL set core's local binding and its
declaration **before** setting the global one, and SHALL NOT set the global
binding if establishing core's fails.

Every other candidate owner disclaims this in its own contract, which is why the
gap existed rather than being an oversight in one place:

| Candidate | Why not |
|---|---|
| `install.sh` | writing hooks into whatever repository the shell is standing in is the category error Decision 4 removed |
| `init-project.sh` | "no skills, no hooks, no host configuration — those are the machine's business" |
| `fresh-clone-needs-nothing` | a repository carries `openspec/` and one instruction file, "nothing else. No hooks, no shims" |
| core's CI | detects the absence; a detector is not an establisher |

This is **not** Decision 4's category error returning. That error was a machine
installer reaching into an arbitrary repository it happened to be standing in.
This is the binder repairing the single, known, deterministic casualty of its
own act, in the one repository it is by definition running from. The
displacement and the repair are one act, for the same reason "publish, then
bind" is one act: the orders are not symmetric and the safe one costs nothing.

#### Scenario: The binder runs before any global binding exists

- **WHEN** the binder is about to set the global `core.hooksPath`
- **THEN** it SHALL first set core's local `core.hooksPath` to core's resolved
  default hooks directory, together with `agenticapps.hooksbinding=declared`
- **AND** it SHALL NOT set the global binding if either write fails
- **AND** a commit in core afterwards SHALL run core's working-tree gate

#### Scenario: Core's binding is already established

- **WHEN** core already carries a declared local binding naming its default
  hooks directory
- **THEN** the binder SHALL report it satisfied and rewrite nothing
- **AND** SHALL proceed to the global binding

#### Scenario: The sweep encounters core

- **WHEN** the sweep evaluates core's local `core.hooksPath`
- **THEN** it SHALL leave the binding in place
- **AND** SHALL report it as declared rather than as redundant

#### Scenario: The declaration is missing

- **WHEN** core carries a local `core.hooksPath` that is not declared
- **THEN** `--check` SHALL report the binding as undeclared and at risk of being
  swept
- **AND** SHALL NOT report core as correctly bound
