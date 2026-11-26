## ADDED Requirements

### Requirement: The section is a pointer and the rules every turn needs

The section the initializer writes SHALL carry only what must hold on a turn
where the workflow skill is not loaded:

- one sentence pointing at the `agentic-apps-workflow` skill for code, spec and
  decision-record work;
- an instruction not to add copies of what this workflow publishes — skills,
  hooks or host configuration — because `install.sh` establishes them
  machine-level. Tooling a project owns for itself is not affected; and
- the decision-home line (see `decision-records`).

Everything else the workflow says lives in the skill. A rule SHALL live in the
section or in the skill, never both.

The pointer stays although the skill is description-triggered: not every host's
global instruction file points at the workflow, so for those hosts the section
is the only in-file sign that the loop applies. It names decision-record work
because those turns may touch no code, and the skill holds the numbering and
content rules they need.

Core is the publisher and carries the sources of those skills and hooks; the
instruction is about copies in a consuming repository and does not apply to
core's own sources.

#### Scenario: A freshly initialised repository

- **WHEN** the initializer runs in a repository with no section
- **THEN** the section SHALL name the `agentic-apps-workflow` skill
- **AND** SHALL name decision records among the work the skill governs
- **AND** SHALL instruct that no copies of workflow skills, hooks or host config
  be added
- **AND** SHALL NOT restate the loop, the gates or the coding discipline
