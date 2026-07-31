# Claude Code prompt — bind OpenSpec in a host repo (claude / codex / opencode / pi)

**Run with Claude Code inside ONE host scaffolder repo.** Repeat for each host. Run
AFTER the core standard (prompt 00). Set `{{HOST}}` = claude | codex | opencode | pi.

---

## Paste to Claude Code:

You are updating the `{{HOST}}` scaffolder repo to the AgenticApps v2 workflow
(OpenSpec + Superpowers + Linear), binding OpenSpec **upstream (linked, not
re-ported)** exactly as the core standard specifies. Guardrails: keep `.planning/` as
backup; supersede ADRs, don't delete; make the smallest change that satisfies each item.

### 1. Bind OpenSpec upstream  (see OPENSPEC-CLI-AND-MULTIHOST.md)
OpenSpec natively supports all four hosts — generate every present host's command files
in one shot: `openspec update --tools claude,codex,opencode,pi` (or just `{{HOST}}` in a
single-host repo). Adopt the OPSX **Core** profile. Do not copy OpenSpec's internals —
the CLI is a standalone binary (agent-agnostic); agents just call it. Update `install.sh`
so the trigger skill, gates, the generated `opsx` commands, and the gate wiring install
into this host's skills dir (`~/.claude/skills` | `~/.codex/skills` | opencode | pi equivalent).

### 2. Remove gitnexus
Delete `.gitnexus/` (including the `lbug` binary), `skills/gitnexus/*`,
`.claude/skills/gitnexus/*` (or host equivalent), and every reference in host files,
setup/update skills, and docs. Record as ADR note.

### 3. Retarget the plan-review gate (KEEP the multi-AI adversarial review)
The existing `plan-review` gate is your multi-AI adversarial review (the
`codex-plan-review` producer that runs ≥2 other-vendor CLIs and writes `REVIEWS.md`, +
the `check-plan-review.sh` verifier). **Keep it** — OpenSpec's `validate` does NOT do
adversarial review, and dropping it re-opens ADR-0018. Retarget it: the reviewers now
critique the active OpenSpec **change** (proposal + spec delta) instead of `PLAN.md`;
the verifier resolves "the active change" instead of "the current phase"; the evidence
file is `changes/<name>/REVIEWS.md`; keep the ≥2-reviewer rule and both escape hatches.
Then set the `PreToolUse` hook predicate to block code edits unless **both**: an active
change exists with `openspec validate` green, AND `REVIEWS.md` has ≥2 reviewers.
Author the gate as ONE **host-agnostic shell script** installed globally
(e.g. `~/.agenticapps/bin/openspec-change-gate.sh`); every host's hook (claude
`settings.json` · codex `.codex/hooks.json` · opencode · pi) just calls it. Also wire the
same script as a **git pre-commit + CI check** — that is the agent-agnostic enforcement
floor (it catches edits from any agent or a human; the per-agent hook is only faster
feedback and can't gate its own installing session). Add a reviewer wrapper that pipes
`</dev/null` and time-limits a hanging reviewer CLI (pilot friction #3). opencode + pi
hook surfaces are unconfirmed — verify them in this step.

### 4. Collapse the gates
Retire only `spec-review`'s *structural* role into `/opsx:validate`. **Keep
`plan-review`** (multi-AI, retargeted per step 3). Keep `cso` (always-on, product repos).
Make `database-sentinel`, `qa`,
`design-critique`, `design-shotgun`, `impeccable` **conditional** — fire only when the
active change touches SQL/RLS (db) or UI (the rest). Demote `ts-declare-first` to a CI
lint. Keep `impeccable` + any Go skills behind the measured trial (see MEASUREMENT.md);
do not remove them yet.

### 5. Host file: process only
In `AGENTS.md`/`CLAUDE.md`, keep the "Coding Discipline" rules, workflow, and
session-handoff (process). Remove any *product-capability* prose (this repo is a
scaffolder, so there is little) into a spec if found. Update the "Development Workflow"
section to describe the OpenSpec loop and point at `docs/WORKFLOW.md`. Keep the
spec-source markers.

### 6. Update setup/update skills + version stamp
`setup-{{HOST}}-agenticapps-workflow` and `update-…` must now scaffold OpenSpec
(`openspec init`, the validated-change hook, the collapsed gate set) and run the
`planning→openspec` migration from the core recipe. Bump `implements_spec` / workflow
version.

### Acceptance criteria
- `openspec init` + validated-change hook + collapsed gates install via `install.sh --dry-run`.
- No gitnexus anywhere; `.planning/` intact.
- Host file contains process only; workflow section points at `docs/WORKFLOW.md`.
- Hook blocks edits until a change validates.

### Per-host notes
- **claude**: `CLAUDE.md`; `~/.claude/skills/`; settings-based hooks; symlink one-level-deep loader.
- **codex**: `AGENTS.md`; `~/.codex/skills/`; `.codex/hooks.json` (`apply_patch` matcher).
- **opencode**: `AGENTS.md` + `opencode.json`; confirm hook mechanism; GLM model config stays.
- **pi**: `AGENTS.md` + `SKILL.md`-native; confirm pi's hook/gate trigger mechanism.
