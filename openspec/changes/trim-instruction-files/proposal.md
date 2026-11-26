# Trim the instruction files to what every turn needs

Linear issue: none (operator brief `PROMPT-core-context-file-trim.md`, 2026-11-26).

Every line of `CLAUDE.md` / `AGENTS.md` is paid for on every turn, on every host.
A phase-1 inventory of the fleet (core, claude-mods, callbot, fbc-platform,
fx-signal-agent) found that most of it is either discoverable from the repository,
already carried by the `agentic-apps-workflow` skill, or stale. In core, 9% of the
hand-written text survives that test.

This change does the part that belongs to core:

1. **The managed section gets shorter.** The template `init-project.sh` renders
   drops from ~130 to ~65 words and carries only what must hold on turns where the
   skill is not loaded:
   - a one-sentence pointer to the skill. Kept, not cut: the skill is
     description-triggered, three of the five hosts' global files carry no
     pointer of their own, and spec §12 asks for one;
   - the two-artifact rule, rephrased as an instruction: add no copies of workflow
     skills, hooks or host config. The operator confirmed this is an every-turn
     guard. Core's own sources are not copies;
   - the decision home, and a new rule that merged records are append-only.
     Records are edited on turns that are not code work, so the rule lives in the
     section and not in the skill.

   The glossary sentence (`CONTEXT.md`) goes. It is a fleet constant, not a fact
   about a repository, and the skill already states it. Three of five fleet
   repositories have no `CONTEXT.md`. `SECTION_VERSION` 1.1.0 → 1.2.0.

2. **The skill takes what the files stop saying.** Two things the core file says
   that the skill does not, so cutting them would lose them:
   - a commit is blocked on **two** conditions — validation and the
     `AGENTS.md`/`CLAUDE.md` pair. The skill says one, copying a sentence in
     `change-gate-enforcement` that contradicts that spec's own pair requirement.
     The sentence is fixed in the spec, and the skill and two docs follow it;
   - removed-tool residue (`/gsd-*`, `gitnexus`, `.planning/`) in a document is
     stale text, never an instruction. GSD was verified gone at package, host and
     project level on 2026-11-26, but its text survives in fleet docs.

   It also corrects a dead path: the skill calls itself `docs/workflow.mmd` in
   prose; the diagram is the root `workflow.mmd`.

3. **Core's own instruction pair is trimmed** to its title, the scope rule (a thing
   not on `workflow.mmd` and not needed by a step on it does not belong here), and
   the re-rendered section. Removed: what README and the tree already say, the
   symlink history (in `docs/HOW-IT-FITS-TOGETHER.md` and the archive), the gate
   explanation (now in the skill), the directory table (in README, and it listed
   the deleted `gate/`), and the "core gates itself through
   `.claude/hooks/openspec-change-gate.sh`" paragraph, which names a hook that is
   deliberately unregistered — core self-gates through `.git/hooks/pre-commit` and
   CI, per ADR-0028.

## Out of scope

Downstream repositories and the global host files. They get hand-off prompts and
pick up the new section by re-running the initializer. No writer would undo a
hand-written cut: `normalize-claude-md.sh` is dead and `init-project.sh` touches
only the bytes between the markers.
