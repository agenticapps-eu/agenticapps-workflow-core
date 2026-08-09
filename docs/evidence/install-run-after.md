# install.sh — the real run, 2026-08-06T17:36Z

Task 8.4. The before state is `install-check-before.md`; `./install.sh --check`
matched it byte for byte immediately before this run.

> **This is a dated record and parts of it no longer describe the installer.**
> The project-hook publisher, its `ARTIFACTS` declaration and the `manifest.tsv`
> this run wrote were all retired on 2026-08-09, so §8.6 below attests a file
> that no longer exists and a hook that is no longer published. Kept unedited:
> an evidence file that is corrected to match the present stops being evidence.

`./install.sh --host auto --replace-unrecognised`

## What it did

15 rebindings, 11 removals, and one legacy copy removed — 26 bindings into
archived checkouts, which is the whole set `design.md` measured. Afterwards
`--check` reports every host bound into core and nothing resolves into
`claude-workflow`, `codex-workflow` or `opencode-workflow`.

The handoff predicted "13 rebinds, 7 removes". That prediction was wrong; the
measured 26 is the number `design.md:231` records and the number the run moved.

```
detected hosts: claude codex opencode pi omp
publishing to /Users/donald/.agenticapps/bin
  published openspec-change-gate.sh
  published run-plan-review.sh
  published reviewer-cli.sh
  published and attested the project-hook set
installing core's git pre-commit hook
binding hosts: claude codex opencode pi omp
  /Users/donald/.claude/skills (read by claude)
  preserved /Users/donald/.claude/skills/agenticapps-workflow -> /Users/donald/.agenticapps/pre-install/.claude/skills/agenticapps-workflow.pre-install.1
  restore:  rm -rf /Users/donald/.claude/skills/agenticapps-workflow; mv /Users/donald/.agenticapps/pre-install/.claude/skills/agenticapps-workflow.pre-install.1 /Users/donald/.claude/skills/agenticapps-workflow
  removed legacy skill agenticapps-workflow (a copy, not a link)
  rebound agentic-apps-workflow (was /Users/donald/Sourcecode/agenticapps/claude-workflow/skill) -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  removed setup-agenticapps-workflow (was /Users/donald/Sourcecode/agenticapps/claude-workflow/setup) — no host-neutral equivalent is installed
  removed update-agenticapps-workflow (was /Users/donald/Sourcecode/agenticapps/claude-workflow/update) — no host-neutral equivalent is installed
  /Users/donald/.codex/skills (read by codex)
  rebound agentic-apps-workflow (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/agentic-apps-workflow) -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  rebound codex-cso (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-cso) -> /Users/donald/.claude/skills/cso
  rebound codex-database-sentinel-audit (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-database-sentinel-audit) -> /Users/donald/.claude/skills/database-sentinel
  removed codex-design-critique (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-design-critique) — no host-neutral equivalent is installed
  rebound codex-design-shotgun (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-design-shotgun) -> /Users/donald/.claude/skills/design-shotgun
  rebound codex-impeccable-audit (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-impeccable-audit) -> /Users/donald/.agents/skills/impeccable
  rebound codex-openspec-change-review (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-openspec-change-review) -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/openspec-change-review
  rebound codex-qa (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-qa) -> /Users/donald/.claude/skills/qa
  removed codex-spec-review (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-spec-review) — no host-neutral equivalent is installed
  removed codex-ts-declare-first (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/codex-ts-declare-first) — no host-neutral equivalent is installed
  removed setup-codex-agenticapps-workflow (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/setup-codex-agenticapps-workflow) — no host-neutral equivalent is installed
  removed update-codex-agenticapps-workflow (was /Users/donald/Sourcecode/agenticapps/codex-workflow/skills/update-codex-agenticapps-workflow) — no host-neutral equivalent is installed
  /Users/donald/.config/opencode/skills (read by opencode)
  rebound agentic-apps-workflow (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/agentic-apps-workflow) -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  rebound opencode-cso (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-cso) -> /Users/donald/.claude/skills/cso
  rebound opencode-database-sentinel-audit (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-database-sentinel-audit) -> /Users/donald/.claude/skills/database-sentinel
  removed opencode-design-critique (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-design-critique) — no host-neutral equivalent is installed
  rebound opencode-design-shotgun (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-design-shotgun) -> /Users/donald/.claude/skills/design-shotgun
  rebound opencode-impeccable-audit (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-impeccable-audit) -> /Users/donald/.agents/skills/impeccable
  rebound opencode-openspec-change-review (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-openspec-change-review) -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/openspec-change-review
  rebound opencode-qa (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-qa) -> /Users/donald/.claude/skills/qa
  removed opencode-ts-declare-first (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/opencode-ts-declare-first) — no host-neutral equivalent is installed
  removed setup-opencode-agenticapps-workflow (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/setup-opencode-agenticapps-workflow) — no host-neutral equivalent is installed
  removed update-opencode-agenticapps-workflow (was /Users/donald/Sourcecode/agenticapps/opencode-workflow/skills/update-opencode-agenticapps-workflow) — no host-neutral equivalent is installed
  /Users/donald/.agents/skills (read by pi, omp)
  no host configuration was written — the gate runs at git commit and in CI
done.
```

## After: `./install.sh --check`

```
artifacts in /Users/donald/.agenticapps/bin
  openspec-change-gate.sh 2.0.0 current
  run-plan-review.sh 1.2.0 current
  reviewer-cli.sh 1.2.0 current
hosts
  claude bound -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  codex bound -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  opencode bound -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  pi bound -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
  omp bound -> /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/skills/agentic-apps-workflow
```

## Tasks 8.5–8.7

- **8.5** `tools/check-shims.sh ~/Sourcecode` — every declared hook in all seven
  fleet repositories bound with the authority's bytes; core itself `present`
  (self-hosting, ADR-0028) and opted out of `database-sentinel`. The published
  `openspec-change-gate.sh` is byte-identical to
  `reference-implementations/openspec-change-gate/openspec-change-gate.sh`
  (sha256 `4ad996cb…6780`).
- **8.6** `manifest.tsv` carries `database-sentinel.sh` — the whole declared set
  in `ARTIFACTS` — at the reference implementation's hash (`c908d3ba…3652c`).
  The retired `normalize-claude-md.sh` row **survives**, as predicted: rows
  outside the declared set are carried forward by design.
- **8.7** No host configuration file was created or modified. `settings.json`
  (2026-07-29), `~/.claude/CLAUDE.md` (2026-08-05), `config.toml` (2026-08-06
  11:15) and `opencode.json` (2026-07-01) all predate the run, and nothing under
  the four host config directories was written in the run's window except the
  skill directories themselves.

## Restore

Everything replaced is under `~/.agenticapps/pre-install/`. The run printed the
restore command for the one preserved directory:

```
rm -rf /Users/donald/.claude/skills/agenticapps-workflow
mv /Users/donald/.agenticapps/pre-install/.claude/skills/agenticapps-workflow.pre-install.1 /Users/donald/.claude/skills/agenticapps-workflow
```
