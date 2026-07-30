# Claude Code prompt — cParx OpenSpec pilot in a throwaway worktree

**Run this with Claude Code inside the local cParx repo** (`~/Sourcecode/factiv/cparx`).
It sets up the new OpenSpec + Superpowers workflow in a disposable git **worktree**,
migrates ONE capability, runs a real task through the new loop to prove it triggers,
then tells you how to trash the sandbox. Nothing touches your main working tree or any
branch you keep.

---

## Paste to Claude Code:

You are piloting a workflow migration in a disposable sandbox. Read
`docs/WORKFLOW.md` intent from the migration packet if present; otherwise follow this
exactly. **Guardrails — do not violate:**
- Work ONLY in the worktree sandbox you create below. Never edit the main working tree.
- NEVER delete or move `.planning/` — it is permanent backup. You may read it.
- Only *product-capability* statements move into specs. *Process/discipline* stays in
  CLAUDE.md. If unsure whether a sentence is product or process, leave it and note it.
- Do not push, do not open a PR, do not touch `main`. This is a local, throwaway test.

### 1. Create the sandbox worktree
```bash
git worktree add -b openspec-pilot ../cparx-openspec-sandbox HEAD
cd ../cparx-openspec-sandbox
```
Confirm you are in `cparx-openspec-sandbox` on branch `openspec-pilot` before any edit.

### 2. Initialize OpenSpec  (see OPENSPEC-CLI-AND-MULTIHOST.md for the current CLI)
```bash
npx -y @fission-ai/openspec@latest init --tools claude,codex,opencode,pi
```
Adopt the OPSX **Core** profile (`openspec config profile` → `openspec update`). Put
cParx context in `openspec/config.yaml` under `context:` (stack ADR-0002/0003; scoring
invariant ADR-0008; observability behind a vendored wrapper); a `project.md` is optional.
Run `openspec --help` and use the installed verbs (`openspec new change`, `validate --all`,
`show`, `archive -y`) — the schema is CLI-driven now.

### 3. Seed one capability from the reconstructed spec
Copy the already-reconstructed capability spec and its archived changes from the
migration packet into place (the packet's `openspec/specs/analysis-pipeline/spec.md`
plus the three `changes/archive/2026-04-20-03*` folders). If you don't have the packet,
reconstruct `openspec/specs/analysis-pipeline/spec.md` from
`.planning/phases/03-llm-pipeline-api`, `03.5-quality-scoring`, `03.6-extraction-extensions`
SUMMARY/VERIFICATION files: merge them into one capability spec of current truth
(post-3.5 two-axis scoring), OpenSpec `### Requirement:` / `#### Scenario:` format.
Then:
```bash
npx -y @fission-ai/openspec@latest validate --all
```
It must pass before continuing.

### 4. Extract product-spec out of CLAUDE.md (analysis-pipeline slice only)
Scan CLAUDE.md for sentences that assert *product behavior* of the analysis pipeline
(e.g. "LLM never produces scores", the D-18 response shape, weights, blocker rules).
For each: confirm it is represented as a requirement in
`specs/analysis-pipeline/spec.md` (add if missing), then in CLAUDE.md replace the
prose with a one-line pointer: `See openspec/specs/analysis-pipeline/spec.md`. Leave
all *process/discipline* content in CLAUDE.md untouched. List every line you moved.

### 5. Install the retargeted gate (validate + multi-AI review)
Add a `PreToolUse` gate (mirroring the existing plan-review hook mechanism) that blocks
code-editing tool calls unless: (a) an **active** OpenSpec change exists and
`openspec validate --all` passes, AND (b) that change has a `REVIEWS.md` with ≥2
reviewers — this preserves your multi-AI adversarial review (ADR-0018), just retargeted
from `PLAN.md` to the change. For the sandbox, if you don't have ≥2 other-vendor CLIs
handy, use the existing escape hatch (`GSD_SKIP_REVIEWS=1`) and note it in the report —
do not silently drop the check. Wire it the way this host wires hooks (codex:
`.codex/hooks.json`; claude: the settings hook block).

### 6. Run a REAL task through the new loop
Task (small, real cParx tech-debt from the v1.0 audit): **"The OBS-04 classifier log
omits the `model` field (classify.go). Add `model` to the structured classifier log
event."**

Drive it through the workflow, narrating each step so the human can see the loop fire:
1. `openspec` propose a change `add-model-to-classifier-log` — write proposal.md
   (Why/What/Impact + a placeholder `Linear: <none-pilot>`), a spec delta MODIFYING the
   relevant requirement in `analysis-pipeline` (the classifier log's fields), and
   tasks.md.
2. `openspec validate --all` — must pass.
2b. plan-review: run the multi-AI adversarial review over the change (proposal + delta),
   writing `changes/add-model-to-classifier-log/REVIEWS.md` (≥2 reviewers, or the
   documented escape hatch). Show the gate BLOCKS edits before this and PERMITS them after.
3. Execute with Superpowers discipline: write the failing test first (RED) asserting
   the log carries `model`, then implement in `classify.go` (GREEN), then run
   verification-before-completion against the tasks + delta.
4. Archive the change: fold the delta into `specs/analysis-pipeline/spec.md`, move the
   change folder to `changes/archive/`.
5. ship (thin, kept): make the conventional commit + a changelog line from `proposal.md`
   (skip PR/tag in the sandbox) — to demonstrate that `archive` ≠ ship and the release
   mechanics survive as a separate step.
Report at each step whether the trigger skill / gate behaved as intended.

### 7. Report, then STOP
Write `PILOT-REPORT.md` in the sandbox covering: did the workflow trigger cleanly; did
the validate gate block edits pre-validation and permit them post-validation; what in
CLAUDE.md was spec vs process; time taken; and any friction. **Do not delete anything.**

### 8. Teardown (human runs this after reviewing)
```bash
cd ~/Sourcecode/factiv/cparx
git worktree remove ../cparx-openspec-sandbox --force
git branch -D openspec-pilot
```
`.planning/` and your real tree are untouched — only the sandbox is gone.

---

## Acceptance criteria (what "the pilot worked" means)
- `openspec validate --all` green for the seeded capability and the new change.
- The gate demonstrably blocked an edit before validate, allowed it after.
- The OBS-04 task shipped via propose → validate → TDD → archive, and
  `specs/analysis-pipeline/spec.md` now reflects the `model` field as current truth.
- `.planning/` untouched; only product-spec (not process) left CLAUDE.md.
- `PILOT-REPORT.md` exists and is honest about friction.
