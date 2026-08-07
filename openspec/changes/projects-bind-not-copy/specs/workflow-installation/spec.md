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

**What follows from that, stated here because it belongs to the capability and
not to a security appendix: a checkout of this repository is live prompt code
for every bound host.** The symlink resolves through the working tree, so
whatever is checked out at load time is what the agents execute as their
instructions — which is the property that makes editing core reach every host
at once, and the same property that makes `gh pr checkout` of a branch touching
`skills/` arm every host on the machine with unreviewed instructions, before the
review, including the agent performing it. A branch carrying a skill change is
therefore reviewed by reading the diff. A machine that must do both SHALL bind
to a worktree pinned to the reviewed branch rather than to the one it reviews
from. This is a consequence to be stated and lived with, not a reason to copy;
copying trades it for the drift above, which is worse and permanent.

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
