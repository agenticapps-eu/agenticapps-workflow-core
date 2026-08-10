## MODIFIED Requirements

### Requirement: Skills are bound by symlink and never copied

The installer SHALL bind `skills/*` into a host's skill directory by symlink to
the checkout. It SHALL NOT copy a skill into a host directory under any
circumstance, including when a symlink cannot be created.

A copy is the drift this capability exists to remove: a copied skill is a second
version that no update reaches, and the machine then holds two files claiming to
be the same skill.

**This requirement governs host skill directories, and it is not the whole of the
prohibition.** The argument above is about copies, not about hosts, but it was
enforced only where this installer writes — so it read as settled while eight
consuming repositories held their own copies of the same skill at four byte-sizes
and two claimed versions. Project-local skill directories are governed by
`project-skill-binding`, which applies the same reasoning to the surface this
installer does not touch. Naming the boundary is the point: a reader of this
requirement should not have to infer whether projects were considered and
exempted, or simply never reached.

**A consequence of binding by symlink, recorded here and normative nowhere in
this change: a checkout of this repository is live prompt code for every bound
host.** The symlink resolves through the working tree, so whatever is checked
out at load time is what the agents execute as their instructions — the property
that makes editing core reach every host at once, and the same property that
makes `gh pr checkout` of a branch touching `skills/` arm every host on the
machine with unreviewed instructions, before the review, including the agent
performing it.

This is stated and not required, deliberately. It is a real hazard and it wants
its own change: pinning host bindings to a reviewed worktree separate from the
one a pull request is read from is a claim about how this machine is
provisioned, with its own scenarios and its own tests, and it has nothing to do
with whether a *project* carries a skill copy. An earlier revision put a `SHALL`
here with no scenario and no task behind it, inside a requirement about symlinks
— which is how an unenforceable rule enters a spec. It is a consequence to live
with rather than a reason to copy; copying trades it for the drift above, which
is worse and permanent.

#### Scenario: A skill is bound into a host

- **WHEN** the installer binds a host whose skill directory is known
- **THEN** each entry in `skills/` appears in that directory as a symlink
  resolving to the core checkout
- **AND** no regular file or directory with the same name is written there

#### Scenario: A symlink cannot be created

- **WHEN** the installer cannot create a symlink at the target path
- **THEN** it reports the failure for that host and continues with the others
- **AND** it does not fall back to copying

#### Scenario: A project-local skill directory is encountered

- **WHEN** the installer runs on a machine holding consuming projects
- **THEN** it does not write to any project-local skill directory
- **AND** the state of those directories is governed by `project-skill-binding`,
  not by this requirement

## ADDED Requirements

Both requirements below arrive from `project-hook-binding`, which loses them
because its subject is gone, not because their behaviour stopped. They are
stated here in the terms of the installer that has always satisfied them. **An
earlier revision of this change deleted them outright**; a round-2 reviewer
showed live code satisfies both, and a requirement whose implementation still
runs is relocated rather than retired.

### Requirement: Currency is judged against an authority checkout

A published artifact's currency SHALL be judged by comparing it against the
authority checkout, and the comparison SHALL distinguish a stale build from an
altered one. Reporting only that a file is present accepts a copy that is stale,
hand-edited or half-installed.

The check SHALL compare bytes before it compares versions, and SHALL report
these cases separately: byte-identical to the checkout; a differing build older
than the checkout's; a differing build newer than the checkout's; and **the same
version as the checkout with different bytes**, which is the case a
version-only comparison cannot see and the one a hand-edit produces. An artifact
carrying no parseable marker SHALL be reported as version-unknown rather than as
current.

The check SHALL report and SHALL NOT repair. A check that fixes what it finds
cannot be run to find out whether anything is wrong.

#### Scenario: The versions agree and the bytes do not

- **WHEN** a published artifact carries the same version marker as the checkout
  but differs from it byte for byte
- **THEN** it is reported as modified and not current, naming both facts
- **AND** it is not reported as current on the strength of the matching version

#### Scenario: The installed build is older than the one the checkout ships

- **WHEN** a published artifact's marker is lower than the checkout's
- **THEN** it is reported as not current, naming the checkout's version

#### Scenario: The machine carries a build ahead of the checkout

- **WHEN** a published artifact's marker is higher than the checkout's
- **THEN** it is reported as ahead of the checkout rather than as not current,
  because the two are different conditions and only one is a problem

#### Scenario: The check is asked to fix what it found

- **WHEN** the check runs against a machine with a stale or modified artifact
- **THEN** it reports and changes nothing

### Requirement: The implementation version marker is compared, not merely carried

A published artifact SHALL carry `# <artifact>-version: <major>.<minor>.<patch>`
within its first 10 lines, matching `^[0-9]+\.[0-9]+\.[0-9]+$`, and the
authority for that version SHALL be the tracked file in the checkout. The marker
SHALL be bumped whenever the artifact's behaviour changes.

An installer SHALL arbitrate on the marker rather than overwrite unconditionally,
and SHALL refuse to replace a published copy carrying a **higher** version than
the one it holds, treating an unmarked file as `0.0.0`. A marker that is written
and never compared is decoration: it makes a machine look versioned while
allowing an older install to silently replace a newer one.

#### Scenario: An older installer runs against a newer published copy

- **WHEN** an installer holding version 1.2.1 finds a published copy at 1.2.2
- **THEN** it refuses to overwrite it, and says so
- **AND** the refusal is reported rather than passed over in silence

#### Scenario: A published copy carries no marker

- **WHEN** an installer finds a published artifact with no parseable marker
- **THEN** it treats it as `0.0.0` for the comparison, so an unmarked file does
  not win against a versioned one
