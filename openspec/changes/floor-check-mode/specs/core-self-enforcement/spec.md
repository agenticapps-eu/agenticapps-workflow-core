## MODIFIED Requirements

### Requirement: Core's local hooks binding is declared, and the fleet sweep does not remove it

Core sets `core.hooksPath` locally to its own `.git/hooks` so that it resolves
its working-tree gate rather than the published copy (ADR-0028). That binding is
redundant-looking and real, so it SHALL be declared where the sweep reads its
exclusions, and the sweep SHALL NOT remove a declared binding.

Where the declaration is absent the binding is at risk, and that condition SHALL
be reportable rather than discovered by its consequences.

#### Scenario: The declaration is missing

- **WHEN** core carries a local `core.hooksPath` that is not declared
- **THEN** `--check` SHALL report the binding as undeclared and at risk of being
  swept
- **AND** SHALL NOT report core as correctly bound
