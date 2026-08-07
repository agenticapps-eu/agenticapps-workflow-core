## MODIFIED Requirements

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
- **AND** this SHALL be reported as a violation of the inversion rather than
  accepted as a working floor

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
**outside core's own git directory**, report the global binding as the cause,
and name the local `core.hooksPath` that would fix it. This is a refusal about
*destination ownership*, distinct from the containment refusal below, which is
about writing into repository content.

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

#### Scenario: core.hooksPath points outside the working tree

- **WHEN** the installer runs where `core.hooksPath` names a directory outside the working tree
- **THEN** it SHALL install into the directory the resolver returns
- **AND** SHALL NOT refuse on the grounds that the setting is present

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

#### Scenario: The sweep encounters core

- **WHEN** the sweep evaluates core's local `core.hooksPath`
- **THEN** it SHALL leave the binding in place
- **AND** SHALL report it as declared rather than as redundant

#### Scenario: The declaration is missing

- **WHEN** core carries a local `core.hooksPath` that is not declared
- **THEN** `--check` SHALL report the binding as undeclared and at risk of being
  swept
- **AND** SHALL NOT report core as correctly bound
