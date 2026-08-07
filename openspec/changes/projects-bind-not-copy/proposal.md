## Why

Core publishes one trigger skill — `agentic-apps-workflow`, 235 lines, v4.0.0 —
and `core-installer-one-entry-point` bound it into all five host directories on
2026-08-06. **Eight fleet repositories still carry their own committed copy in
`.claude/skills/`**, and a project-local skill sits in front of the host one. The
change that was supposed to end "two files claiming to be the same skill" ended
it for hosts and left it standing for projects.

The copies are not merely old. They are inconsistent with each other:

| Repo | family | copy |
|---|---|---|
| agenticapps-dashboard | agenticapps | 331 lines, v3.2.0 |
| agenticapps-roadmap | agenticapps | 324 lines, v3.2.0 |
| agents-task-viewer | agenticapps | 324 lines, v3.2.0 |
| agenticapps-dashboard-add-agent-board | agenticapps | **415 lines, v3.0.0** |
| callbot | factiv | 324 lines, v3.2.0 |
| cparx | factiv | 324 lines, v3.2.0 |
| fbc-platform | factiv | **346 lines, v3.2.0** |
| fx-signal-agent | factiv | 324 lines, v3.2.0 |

Four byte-sizes, two claimed versions, and `fbc-platform` differs from its three
v3.2.0 siblings while claiming to be them. This is the exact condition core's own
`CLAUDE.md` describes — *"which one loads is down to loader ordering"* — measured
in eight repositories rather than argued about.

It matters now because the host bindings just moved. Until 2026-08-06 the host
copy was also stale, so a project copy shadowing it changed little. Today the
host resolves to v4.0.0 and the project copy does not, so every one of those
eight repositories is the only place on this machine still running the old
workflow.

## What Changes

- **BREAKING for those repositories:** `.claude/skills/agentic-apps-workflow/` is
  deleted from all eight. Work in them resolves the host-bound skill instead, the
  way every other directory on this machine already does.
- **A capability states that a project does not carry its own copy of a
  core-owned skill**, so this is a rule with a home rather than a cleanup that
  happens once and decays.
- **A fleet check enforces it**, in the shape core already uses for hooks: a
  declaration that does not shrink when the thing it describes goes missing, and
  a check that reports a repository it cannot find rather than passing silently.
  `tools/check-shims.sh` is the model.
- **No installer mode is added.** Projects are not bound; they are *unbound*, and
  they see the skill because the host binding covers every directory on the
  machine. `--project` was superseded by `one-enforcement-floor` and this change
  does not revive it.
- **Out of scope, deliberately: the six `openspec-*` skills** each repo also
  carries. Those are upstream OpenSpec's, MIT-licensed, declaring *"Requires
  openspec CLI"*, and installed per-project by that tool. They are not ours to
  collapse, and deleting them would break `/opsx:*` in every repo.

## Capabilities

### New Capabilities

- `project-skill-binding`: what a consuming project may and may not carry in
  `.claude/skills/`, how it obtains a core-owned skill, and how the fleet is
  checked for copies. The counterpart to `project-hook-binding`, which already
  says the equivalent thing about hooks.

### Modified Capabilities

- `workflow-installation`: the "skills are bound by symlink and never copied"
  requirement currently scopes itself to host skill directories. The prohibition
  on copies is stated as a general principle — *"a copied skill is a second
  version that no update reaches"* — and then enforced only for hosts. It should
  say which surfaces it governs, and name the project surface as governed by
  `project-skill-binding` rather than leaving the reader to infer that projects
  were considered.

## Impact

- **Eight repositories across two families**, four of them in `factiv`
  (`callbot`, `cparx`, `fbc-platform`, `fx-signal-agent`) and four in
  `agenticapps`. Cross-family work, so it needs saying out loud: this touches
  repositories outside the family the change lives in.
- `agenticapps-dashboard` is **retired** (2026-08-05) and
  `agenticapps-dashboard-add-agent-board` is a worktree of it. Whether a retired
  repository is worth a PR is a judgement this change has to make rather than
  discover halfway through.
- **`tools/`** gains a check; the `FLEET` declaration already lists seven of the
  repositories and is the natural place to resolve them from.
- **No change to `install.sh`.** Its budget, its modes and its tests are
  untouched, which is the main reason this is a separate change and not an
  amendment to a spec archived yesterday.
- **The removals are only safe because the host binding landed first.** If
  `core-installer-one-entry-point` were reverted, deleting these copies would
  leave those repositories with no workflow skill at all. The ordering is a
  dependency, and it is stated in `design.md`.
