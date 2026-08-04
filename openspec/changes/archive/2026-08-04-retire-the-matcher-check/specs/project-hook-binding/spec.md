## MODIFIED Requirements

### Requirement: Registration matches the implementation's tool coverage

When a shared implementation handles a tool, every project binding that hook
SHALL register a matcher that delivers it. An implementation's coverage of a
tool its matcher never delivers is inert.

A matcher composed only of tool names is an **exact-string** comparison on the
supported host: a matcher naming one tool does not deliver another whose name
merely contains it. Coverage therefore cannot be inferred from a matcher that
looks similar to the tool name, and SHALL be established against the host's
documented matcher semantics.

The claim in the other direction — that a matcher naming a tool implicitly
covers related tools — was raised in review and checked against the host
documentation, which contradicts it. It is recorded because it is the reading
that would silently make this requirement unnecessary, and it is wrong.

**The declared coverage is stated here.** It was previously kept in a separate
declaration file read by one tool; that tool was retired on 2026-08-04 and the
file went with it, because a declaration whose only reader is gone is data that
looks maintained and is not.

| Hook | Event | Matcher |
|---|---|---|
| `database-sentinel` | `PreToolUse` | `Bash\|Edit\|Write\|MultiEdit` |
| `openspec-change-gate` | `PreToolUse` | `Edit\|Write\|MultiEdit\|NotebookEdit` |
| `normalize-claude-md` | `PostToolUse` | `Edit\|Write\|MultiEdit` |

A registration is **conformant** when it names the declared event and covers the
declared tool set; **narrow** when it omits any declared tool; **wider** when it
adds tools beyond it; and **absent** when no entry names the hook at all. Narrow
and absent are defects. **Wider is acceptable** — a project may guard more than
the fleet requires, and treating that as non-conformant would push projects
toward removing coverage.

**NOTHING CHECKS THIS, AND THAT IS THE DELIBERATE STATE.** A previous revision
required a conformance tool to evaluate every declared hook in every scanned
project, on the argument that "a requirement with no check makes nothing
detectable". That argument is correct and it is not free: acted on, it produced
an instrument of nearly two thousand lines against the three hundred it
measured, and six of the eight changes archived in the following week were
repairs to the instrument rather than to the fleet. The check is withdrawn and
the cost of withdrawing it is stated rather than hidden:

- A narrow or absent registration is **not** detected. It surfaces when the hook
  does not fire, which is how the defect below was found in the first place —
  before any check existed and by a person, not a tool.
- The failure is real and has happened: five repositories registered
  `database-sentinel` on `Bash|Edit|Write` against a declared
  `Bash|Edit|Write|MultiEdit`, so a `MultiEdit` to a `.env` file invoked nothing.
  Protection absent rather than degraded, and every axis then in existence
  reported those repositories clean.
- The event that can invalidate a registration is a change to an
  implementation's tool coverage. The scenario below already requires such a
  change to update every project's matcher and verify it **per project**. That
  obligation sits on the change, where the knowledge is, rather than on a
  standing instrument.

A future revision may reinstate a check. If it does, it SHALL be reinstated as
a check and not as a capability: a comparison inside an existing script, with no
requirements of its own to be defective in.

**An absent registration is the strongest form of this defect**, not a lesser one.
A hook registered nowhere is one whose every tool is inert — protection absent
rather than degraded — and it is reachable by exactly the edit a contract rollout
performs: rewriting a project's `settings.json`. Treating the narrowed case as
serious while a hook wired to nothing passes unremarked inverts the severity this
requirement already distinguishes, and it is the absence-reads-as-clean shape
ruled out for shim files two requirements above. **Whoever rewrites a
`settings.json` SHALL confirm the hook is still named in it**, which is the whole
of what the retired check did for this case.

A hook a project has **declared** it does not bind is exempt: for it, no
registration is the correct state, and reporting it would leave the opt-out
declaration meaning nothing on this axis.

#### Scenario: A shared implementation gains a tool

- **WHEN** a canonical implementation handles a tool some projects' matchers omit
- **THEN** those projects' matchers are updated in the same change, and the
  update is verified per project rather than assumed

#### Scenario: A tool named in a matcher no longer exists on the host

- **WHEN** a matcher or implementation covers a tool the host no longer provides
- **THEN** the coverage is harmless but inert, and SHALL NOT be reported as a
  delivered protection

#### Scenario: A declared hook is registered nowhere

- **WHEN** a project's settings name no entry for a hook it is declared to bind,
  while its shim file is present, current and byte-identical to the authority
- **THEN** that project is **not bound** for that hook, and the shim's presence,
  currency and byte-identity SHALL NOT be read as coverage — three green facts
  about a file that never runs

#### Scenario: A registration is narrower than the declared coverage

- **WHEN** a project registers a hook on fewer tools than the table above names
- **THEN** the tools it omits are unprotected in that project, and the
  registration is corrected rather than the declaration relaxed

#### Scenario: A registration is wider than the declared coverage

- **WHEN** a project registers a hook on tools beyond the declared set
- **THEN** that is acceptable and is not a defect, because a project may guard
  more than the fleet requires

#### Scenario: A project has declared it does not bind the hook

- **WHEN** a hook is declared as a project's opt-out and that project registers
  no matcher for it
- **THEN** no registration is the correct state for it, on the same terms the
  absent-shim rule applies to the same declaration

#### Scenario: The registration cannot be read

- **WHEN** the settings file is absent, does not parse, or cannot otherwise be
  read
- **THEN** nothing about that project's coverage has been established, and
  whoever could not read it SHALL say so — "not read" is a different statement
  from "read and correct", and it stays different when the reader is a person

