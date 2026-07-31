# Migration prompt packet — run order

Confirmed decisions: Linear **loose** (change references an ID, no sync) · OpenSpec bound
**upstream/linked** (not re-ported) in all four hosts · **pilot cParx first**, then core,
then hosts, then products · Go/quality skills on a **measured trial** (keep db-sentinel).
`.planning/` is always kept as backup; only *product-capability* prose moves to specs.

These are prompts you paste into **Claude Code inside each repo** (you run them; nothing
here edits your repos remotely). Suggested sequence:

| # | Prompt | Where you run it | When |
|---|---|---|---|
| 1 | `03-cparx-sandbox-pilot.md` | local cParx repo (creates a throwaway worktree) | **first** — de-risk & prove the loop |
| 2 | `00-core-standard.md` | `agenticapps-workflow-core` | after the pilot works |
| 3 | `01-host-bind-openspec.md` | each host repo (claude, codex, opencode, pi) — set `{{HOST}}` | after core |
| 4 | `02-product-repo-migration.md` | cParx (for real) + each other product repo | after its host is on v2 |
| — | `MEASUREMENT.md` | reference for the Go/quality-skill trial | during host/product step |
| — | `../WORKFLOW-EXPLAINED.md` | copy into each repo as `docs/WORKFLOW.md` | every repo |

## Notes
- **Pilot is disposable.** Prompt 03 works entirely in a `git worktree` you trash at the
  end (`git worktree remove … --force`). Your main tree and `.planning/` never move.
- **Run these on your computer**, not from the cloud session — git write-ops on a
  cloud-mounted folder can leave `.lock` files. Claude Code (or Cowork "on your computer")
  is the right place.
- **The reconstructed cParx specs already exist** in this packet
  (`openspec/specs/*/spec.md`, 5 capabilities, all pass `openspec validate --all`) and in
  the archived-change folders — the prompts reuse them so you don't re-derive.
- **Each migration step is itself an OpenSpec change / PR** — traceable and reversible.
- Read `../WORKFLOW-EXPLAINED.md` first; it is the "how the new workflow works" doc you
  asked for and the thing to internalize before running anything.
