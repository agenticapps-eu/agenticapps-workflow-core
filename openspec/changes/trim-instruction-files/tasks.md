# Tasks

## 1. The section — tests first

- [x] 1.1 RED: in `tools/init-project.test.sh` section M, replace the
      "names the glossary" assertion with: the section does **not** name
      `CONTEXT.md`; it names the skill and decision-record work; it states that
      merged records are append-only; it forbids copies of workflow skills, hooks
      and host config; it carries `section-version: 1.2.0`.
- [x] 1.2 RED: a 1.1.0 fixture (M10) re-rendered to 1.2.0 with every byte outside
      the markers unchanged.
- [x] 1.3 `render_block()` in `init-project.sh` renders the design's text;
      `SECTION_VERSION` 1.1.0 → 1.2.0; `init-project-version` 2.2.0 → 2.3.0.
- [x] 1.4 GREEN: `tools/init-project.test.sh` all pass.

## 2. The skill, and the gate wording at its owner

- [x] 2.1 Skill "What the gate actually blocks": an edit on one condition, a
      commit on that and the instruction pair.
- [x] 2.2 Same sentence in `docs/WORKFLOW.md` and `docs/HOW-IT-FITS-TOGETHER.md`.
- [x] 2.2a Same sentence in `reference-implementations/openspec-change-gate/README.md`,
      and a MODIFIED `project-hook-binding` delta: an absent gate loses validation,
      the pair check and the reporting.
- [x] 2.3 Skill sentence: `/gsd-*`, `gitnexus` and `.planning/` in a document are
      stale text — never run them or go looking for them; correct the document
      or report it; never delete residue on sight.
- [x] 2.4 `docs/workflow.mmd` → `workflow.mmd`.
- [x] 2.5 Skill `version` minor bump.

## 3. Core's instruction pair

- [x] 3.1 Trim the hand-written part per the phase-1 table; keep title, scope rule,
      and "nothing under `skills/` may name a host".
- [x] 3.2 Re-render core's section with the new initializer; `AGENTS.md` and
      `CLAUDE.md` byte-identical.

## 4. Verify

- [x] 4.1 `openspec validate --all` green.
- [x] 4.2 `tools/agents-md-conformance.sh` on core's `AGENTS.md`: 0 failed.
- [x] 4.3 Full `tools/*.test.sh` suite: no new failures against the baseline.
- [x] 4.4 Pre-commit gate passes on each commit.
