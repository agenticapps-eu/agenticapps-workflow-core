# Claude Code prompt — migrate a product repo (cParx and other factiv/agenticapps projects)

**Run with Claude Code inside a product repo** that uses the workflow (cParx, and each
other factiv/agenticapps product project). Run AFTER the host it uses is on v2 (prompt
01) and the pilot proved the recipe. This is the full, non-sandbox migration; do it on a
branch and PR it.

---

## Paste to Claude Code:

You are migrating this product repo to the AgenticApps v2 workflow (OpenSpec +
Superpowers + Linear). Work on a branch `openspec-migration`; open a PR at the end; do
not push to main. **Guardrails:** never delete `.planning/` (it is backup); only
*product-capability* prose moves to specs, *process* stays in the host file; when a
capability boundary is ambiguous, flag `> [GAP: …]` and ask rather than invent.

### 1. Preserve history (Tier 0)
`git mv .planning docs/legacy-planning` (keep it in-repo, read-only). Nothing is lost.

### 2. Initialize + reconstruct specs (Tier 2, supervised)
`openspec init --tools claude,codex,opencode,pi` (put context in `openspec/config.yaml`
under `context:`; see OPENSPEC-CLI-AND-MULTIHOST.md, adopt the OPSX Core profile). Build
the **capability map** first: read
`docs/legacy-planning/{REQUIREMENTS,ROADMAP,PROJECT}.md`, the milestone audits, and
phase folder names, and propose `specs/<capability>/` by MERGING related phases into
capabilities (many-phases → one-capability; do NOT mirror phase numbers). Present the
map for human ratification before writing specs. Then reconstruct each
`specs/<capability>/spec.md` as current truth (post-supersession), OpenSpec
`### Requirement:` / `#### Scenario:` format, SHALL/MUST, ≥1 scenario each. Flag every
ambiguity as `> [GAP: …]`. For cParx, the reconstructed `analysis-pipeline`,
`observability`, `case-management`, `document-processing`, and `eligibility-report`
specs already exist in the migration packet — reuse them, extend to the remaining
capabilities. Run `openspec validate --all` until green.

### 3. Archive completed phases (Tier 1, mechanical)
For each completed `docs/legacy-planning/phases/<slug>/`, create
`openspec/changes/archive/<date>-<slug>/` with proposal.md (from CONTEXT/SUMMARY),
tasks.md (from PLAN checklists, all `[x]`), and spec-delta.md (which requirements it
contributed). Script this; it is deterministic.

### 4. Convert OPEN GSD work → active changes
Scan `docs/legacy-planning/STATE.md`, unchecked items in `ROADMAP.md`, and open
`docs/briefs/*` for not-yet-done work. Each open item becomes an **active**
`openspec/changes/<name>/` (proposal + spec delta + tasks) — NOT archived. For cParx
that is the v0.4.0.0 ERM milestone (phases 17–23, all "Pending" in REQUIREMENTS
traceability): create changes like `add-erm-core-schema`, `add-nda-workflow`, etc., each
referencing its Linear ID. Do not implement them; just stage them as the new backlog.

### 5. Extract product-spec out of CLAUDE.md
Go through CLAUDE.md. Every sentence asserting product behavior/invariants/architecture
(e.g. scoring invariant, response shapes, RLS rules, data-model constraints) → ensure it
is a requirement in the right `specs/<capability>/`, then replace it in CLAUDE.md with a
one-line `See openspec/specs/<capability>/spec.md`. Keep ALL process/discipline prose.
Produce a diff list of what moved.

### 6. Bind host workflow + remove gitnexus + retarget hook
Run this repo's host `update-…-agenticapps-workflow` (now v2) to install OpenSpec, the
validated-change hook, and the collapsed gate set; remove any `.gitnexus/` in this repo;
point CLAUDE.md's workflow section at `docs/WORKFLOW.md`.

### 7. Open a PR
Title: `chore: migrate to OpenSpec + Superpowers workflow`. Body: the capability map,
the CLAUDE.md → spec move list, the open-changes backlog created, and the list of
`> [GAP: …]` items needing human answers. Do not merge; leave for review.

### Acceptance criteria
- `.planning` preserved as `docs/legacy-planning/` (untouched content).
- `openspec validate --all` green; capability map ratified.
- Every completed phase archived; every open phase staged as an active change.
- CLAUDE.md carries process only; product-spec lives in specs/ with pointers.
- gitnexus gone; validated-change hook active; PR open with GAP list.
