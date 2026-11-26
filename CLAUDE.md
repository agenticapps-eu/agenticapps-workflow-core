# agenticapps-workflow-core

This repository publishes the workflow: `skills/` and `reference-implementations/`
hold the sources every host and fleet project resolves, so the section below
forbids copies of them elsewhere, not editing them here. Nothing under `skills/`
may name a host: every host resolves the same files.

If a thing is not on `workflow.mmd` and is not required to make a step on it
work, it does not belong in this repo.

<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->
<!-- section-version: 1.2.0 -->

## The AgenticApps workflow

Code, spec and decision-record work here follows the `agentic-apps-workflow`
skill. Add no copies of workflow skills, hooks or host config: `install.sh`
provides them machine-level.

Decision records live in `adrs/` and nowhere else, whatever directory an
installed skill defaults to. Once merged, a record is append-only: correct it
with a new record.

<!-- END: agentic-apps-workflow sections -->
