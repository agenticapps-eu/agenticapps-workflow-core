## ADDED Requirements

### Requirement: A host's skill directory is established by evidence, not assumed

The installer SHALL bind a host's skills into the directory that host actually
reads. That directory SHALL be established by evidence — the host's documented
skill path, or an observed load — and the evidence SHALL be recorded alongside
the mapping.

Where no such evidence is available, the host SHALL be recorded as **unverified**
and its mapping SHALL NOT be asserted as correct.

This capability already requires a host to be *detected* by evidence that it is
installed. It never required the same of the *path*, and the gap is not
theoretical: pi has been bound to a directory it does not read for as long as the
mapping has existed, and nothing failed, because binding into the wrong directory
succeeds. A skill that is not there does not error — it is merely absent, and
absence is what nobody notices.

#### Scenario: A host's skill directory is known from its documentation

- **WHEN** a host documents the directory it loads skills from
- **THEN** the installer SHALL bind into that directory, and the mapping SHALL
  record the source

#### Scenario: A host is bound into a directory it does not read

- **WHEN** the installer binds a host into a directory the host does not load from
- **THEN** this SHALL be treated as a defect, not as a partial success, because
  the install reports success while the host resolves nothing

#### Scenario: No evidence establishes a host's skill directory

- **WHEN** a host is installed but neither documents a skill path nor exposes one
  to observe
- **THEN** the host SHALL be recorded as unverified, and the installer SHALL
  report that its binding is unconfirmed rather than reporting success

#### Scenario: A host's binding is confirmed by resolution

- **WHEN** a binding is claimed correct
- **THEN** it SHALL be confirmed by the host resolving the skill, not by the
  symlink existing — the symlink existing is what was already true for pi

## MODIFIED Requirements

### Requirement: A host is detected by evidence that it is installed

Auto-detection SHALL test for evidence that a host is actually installed — its
executable, or state only that host writes — and SHALL NOT infer a host from the
presence of a directory alone.

A directory can exist for unrelated reasons, and one skill directory in this
layout is shared by two hosts and by unrelated tools, so its presence identifies
no host at all. Binding a host that is not installed creates symlinks nobody
resolves and reports an install that did not happen.

**Detection answers whether to bind; it does not answer where.** Binding a
detected host SHALL use the skill directory established for it by the requirement
above. An earlier revision specified only detection, and the shared-directory
reasoning here proved sharper than the mapping it governed: `~/.agents/skills` is
shared by pi and omp, and the spec noted the sharing without ever asking whether
either host reads it. pi does not. It reads `~/.pi/agent/skills`, a real directory
of per-skill symlinks core did not populate, and core's skill is absent from it —
so pi has been detected correctly and bound nowhere useful for as long as the
mapping has existed.

omp's share of that directory is **unverified**, not corrected. omp is installed,
has no skill directory at `~/.omp/agent/skills` or anywhere else, and names no
skill path in its config, so there is nothing to check the mapping against.
Recording it as unverified is the point: concluding from a single location is the
error this change exists to stop repeating.

#### Scenario: A directory exists but the host does not

- **WHEN** a host's directory exists and that host is not installed
- **THEN** auto-detection does not report that host as present and does not bind it

#### Scenario: A skill directory is shared by more than one host

- **WHEN** a skill directory serves more than one host
- **THEN** the binding is reported once, as a shared binding, naming the hosts
  that read it
- **AND** it is not reported as evidence that any particular one is installed
- **AND** each named host's reading of that directory SHALL be established by
  evidence, because a shared directory is shared by assumption until it is not

#### Scenario: A detected host has an unverified skill directory

- **WHEN** a host is detected and no evidence establishes where it reads skills
- **THEN** the installer SHALL report the binding as unconfirmed and SHALL NOT
  count it toward a successful install
