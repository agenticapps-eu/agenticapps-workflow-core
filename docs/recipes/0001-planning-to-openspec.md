---
id: 0001
slug: planning-to-openspec
title: Migrate a .planning/ (GSD) repo to the OpenSpec + Superpowers front end
from_version: "0.x (GSD front end)"
to_version: "1.0.0 (OpenSpec front end)"
applies_to:
  - .planning/            # read-only; moved to docs/legacy-planning/ (never deleted)
  - openspec/             # created: specs/, changes/, changes/archive/
  - docs/legacy-planning/ # created: the retained .planning/ history
  - <host-instruction-file> # CLAUDE.md / AGENTS.md — product prose relocated per §19
  - .claude/hooks/ | .codex/hooks.json | <host hook wiring> # the §18 change-gate
requires:
  - tool: openspec
    verify: "openspec --version"
    install: "<host openspec install command>"
  - tool: reviewer-clis
    verify: "gemini --version && codex --version"
    install: "<install the ≥2 external-vendor reviewer CLIs the §18 gate calls>"
optional_for:
  - tag: db
    detect: "test -d supabase || test -d migrations/sql || grep -rqi 'rls' ."
    note: "If no database surface is detected, the database-security gate stays unbound (§17 conditional)."
  - tag: ui
    detect: "test -d frontend || test -d src/components"
    note: "If no UI surface is detected, the design gates stay unbound (§17 conditional)."
---

# Recipe 0001 — planning → OpenSpec

> **This is a reference recipe, not a shipped migration.** `agenticapps-
> workflow-core` is spec-only prose and ships no runnable `migrations/`
> chain (README: "not a library… no application code"). This document
> conforms to the §08 migration format so an adopting **host or app repo**
> can drop it into its own `migrations/` directory, wire its own
> `run-tests.sh` fixture (§ Test fixture below), and apply it. The cParX
> app repo is the first adoption target; `PILOT-REPORT.md` is the proof
> this recipe works end-to-end.

Migrating to the OpenSpec front end is **two tiers of work plus a
do-no-harm rule**, in this order:

- **Tier 0 (do no harm):** the `.planning/` history is *moved*, never
  deleted.
- **Tier 1 (mechanical, scripted):** each completed `.planning/phases/<slug>/`
  becomes a completed `changes/archive/<date>-<slug>/`. Fully automatable.
- **Tier 2 (supervised):** `specs/<capability>/` is reconstructed by a
  human-supervised merge of related phases into capabilities. **Not** an
  unattended script — it requires judgment and ratification.

## Pre-flight

```sh
# Fail closed if the tools the front end needs are absent.
openspec --version           || { echo "install openspec first"; exit 1; }
git rev-parse --is-inside-work-tree || { echo "run inside a git repo"; exit 1; }
test -d .planning/phases     || echo "note: no .planning/phases — this may be a greenfield adopt (skip Tier 1)"
```

Do this migration on a branch. Nothing here pushes or opens a PR; that is
the host's `branch-close` / ship step, run after Tier 2 is ratified.

## Steps

### Step 1 (Tier 0): Move `.planning/` to `docs/legacy-planning/` — never delete

**Idempotency check:** `test -d docs/legacy-planning && ! test -d .planning`
**Pre-condition:** `test -d .planning` (there is a planning tree to preserve)
**Apply:**

```sh
mkdir -p docs
git mv .planning docs/legacy-planning
# Leave a breadcrumb so old references still resolve.
printf '%s\n' \
  '# Legacy planning' '' \
  'The GSD-era `.planning/` tree was moved here on migration to the OpenSpec' \
  'front end (spec v1.0.0, recipe 0001). It is retained as effort history' \
  '(§19 Tier 0) and is never deleted. Current product truth now lives in' \
  '`openspec/specs/`.' > docs/legacy-planning/README.md
```

**Rollback:** `git mv docs/legacy-planning .planning && git checkout -- docs/legacy-planning/README.md 2>/dev/null; true`

> Config files some hosts keep at `.planning/config.json` (knowledge
> capture §15, gate bindings) are host-specific: if the host's runtime
> still reads that path, keep a copy at the original location or update
> the host's pointer. That decision is the host's; the **history** moves
> regardless.

### Step 2 (Tier 1, scripted): Each completed phase → an archived change

**Idempotency check:** `test -d openspec/changes/archive && [ "$(ls -A openspec/changes/archive 2>/dev/null)" ]`
**Pre-condition:** `openspec --version >/dev/null && test -d docs/legacy-planning/phases`
**Apply:** run the mechanical converter below. It reads each
`docs/legacy-planning/phases/<slug>/` and writes a *completed*
`openspec/changes/archive/<date>-<slug>/` — proposal reconstructed from
CONTEXT/SUMMARY, tasks from PLAN checklists (marked `[x]` since the phase
already shipped), and evidence carried across. It does **not** touch
`specs/` (that is Tier 2) and does **not** commit.

```sh
#!/usr/bin/env bash
# tier1-phases-to-archive.sh — mechanical, idempotent, no commit.
set -euo pipefail
PHASES="docs/legacy-planning/phases"
OUT="openspec/changes/archive"
mkdir -p "$OUT"
[ -d "$PHASES" ] || { echo "no phases to convert"; exit 0; }

for dir in "$PHASES"/*/; do
  slug="$(basename "$dir")"
  # Date the archive from the phase's own history, not wall-clock:
  # newest git commit touching the phase dir, else the SUMMARY mtime.
  date="$(git log -1 --format=%ad --date=short -- "$dir" 2>/dev/null || true)"
  [ -n "$date" ] || date="$(date -r "$dir" +%F 2>/dev/null || echo 0000-00-00)"
  target="$OUT/$date-$slug"
  if [ -d "$target" ]; then echo "skip (exists): $target"; continue; fi
  mkdir -p "$target"

  # proposal.md — reconstructed from CONTEXT.md + SUMMARY.md
  {
    echo "# $slug (migrated from GSD phase)"
    echo
    echo "> Reconstructed by recipe 0001 Tier 1 from \`$dir\`. This change"
    echo "> already shipped; it is recorded here as history."
    echo
    for f in CONTEXT.md SUMMARY.md; do
      [ -f "$dir$f" ] && { echo "## From $f"; echo; cat "$dir$f"; echo; }
    done
  } > "$target/proposal.md"

  # tasks.md — PLAN checklist items, all marked done (phase shipped)
  {
    echo "# Tasks (migrated — completed)"
    echo
    if ls "$dir"*PLAN.md >/dev/null 2>&1; then
      # normalise any [ ] to [x]; keep existing [x]; pass other lines through
      grep -hE '^\s*[-*]\s*\[[ xX]\]' "$dir"*PLAN.md 2>/dev/null \
        | sed -E 's/\[[ ]\]/[x]/' || true
    else
      echo "- [x] (no PLAN.md found; phase recorded as complete)"
    fi
  } > "$target/tasks.md"

  # Carry evidence verbatim.
  for f in VERIFICATION.md REVIEW.md REVIEWS.md SECURITY.md; do
    [ -f "$dir$f" ] && cp "$dir$f" "$target/$f"
  done
  echo "wrote: $target"
done
echo "Tier 1 complete. Review, then Tier 2 (specs) — do not archive-fold yet."
```

**Rollback:** `rm -rf openspec/changes/archive/*` (Tier 1 output only; it
created nothing else).

### Step 3 (Tier 2, SUPERVISED — not a script): Reconstruct `specs/<capability>/`

This step is **procedure, not automation.** A human (with an agent's help)
reconstructs the durable spec by **merging related phases into
capabilities** — the merge-not-mirror rule (§19). One phase ≠ one spec.

1. `openspec init` if the slot does not exist yet (creates `specs/`,
   `changes/`, `changes/archive/`, config).
2. Cluster the archived changes from Step 2 into **capabilities** — a
   coherent product surface, e.g. phases `03`, `03.5`, `03.6` →
   `specs/analysis-pipeline/spec.md`. Name capabilities by product
   surface, not by phase number.
3. For each capability, write `specs/<capability>/spec.md` as the set of
   requirements the product satisfies **today**, drawing product truth
   from the clustered phases' CONTEXT/SUMMARY/VERIFICATION. **Exclude**
   what was never a product guarantee — operational logging, unbuilt
   plumbing, scaffolding (§19).
4. Relocate any **product guarantee** still living in the instruction
   file (`CLAUDE.md`/`AGENTS.md`) into the relevant spec as a requirement,
   leaving a pointer (§19 placement test). Leave process and the ADR/
   decision ledger where they are.
5. Where the phase record is ambiguous or contradictory, **do not guess**
   — write the gap inline as a blockquote flag:

   ```markdown
   > [GAP: phase 04.5 CONTEXT says analysts self-register; phase 04.6
   > SUMMARY says invite-only. Which is current truth? Needs ratification.]
   ```

6. `openspec validate --all` until green.
7. **Human ratification gate.** A human reviews every `> [GAP: …]`,
   resolves it in the spec, and explicitly ratifies the reconstructed
   `specs/` before anything is archive-folded. Tier 2 is **not** complete
   while any `[GAP: …]` remains.

**Idempotency check:** `openspec validate --all && ! grep -rq '\[GAP:' openspec/specs`
**Pre-condition:** Step 2 output reviewed; `openspec` available.
**Rollback:** `rm -rf openspec/specs/*` (regenerate; specs are derived, not source).

### Step 4: Wire the retargeted change-gate (§18)

**Idempotency check:** host-specific — e.g.
`test -x .claude/hooks/openspec-change-gate.sh` (Claude) or
`jq -e '.hooks.PreToolUse' .codex/hooks.json` (Codex).
**Pre-condition:** `openspec/` exists.
**Apply:** install the host-agnostic change-gate **shell script** (the
real enforcement surface, §18) implementing the exit-code truth table —
allow out-of-change; exempt `openspec/**` writes; block an active change
that lacks validate-green **and** `REVIEWS.md` ≥2 reviewers; documented
escape hatch; fail-open on garbage stdin. Then wire it into the host's
`PreToolUse` interposition point. Wrap reviewer-CLI calls with a timeout
and `</dev/null` (the pilot's `codex exec` stdin-hang).
**Rollback:** remove the hook wiring and the script.

## Post-checks

- `openspec validate --all` is green.
- `grep -rq '\[GAP:' openspec/specs` returns nothing (all ratified).
- `.planning/` no longer exists at root; `docs/legacy-planning/` does.
- The change-gate blocks a simulated code edit under an active,
  un-reviewed change (exit 2) and allows it once `REVIEWS.md` has ≥2
  reviewers (exit 0) — demonstrated by **direct invocation** (a hook
  can't gate its own session).
- No product guarantee remains stranded in the instruction file (§19).
- ADR opportunity: prompt whether to draft a host ADR recording the
  adoption and its `implements_spec: 1.0.0` bump.

## Skip cases

- No `.planning/` at all → greenfield adopt: skip Tier 0 and Tier 1, run
  `openspec init`, author `specs/` directly, wire the gate (Step 4).
- Host already at `implements_spec: 1.0.0` → skipped silently.
- OpenSpec CLI absent → skip with a note directing the user to install it
  (pre-flight fails closed).

## Test fixture (host deliverable)

§08 asks each non-baseline migration to ship a before/after fixture and a
`run-tests.sh`. For this recipe the adopting host builds it as a
**git-ref fixture** (the style used across the fleet's migration suites):

- **before-state:** a git ref (tag or frozen commit) of a repo with a
  representative `.planning/phases/` tree and product prose in
  `CLAUDE.md`.
- **expected-after:** assert that Tier 1 produced one
  `changes/archive/<date>-<slug>/` per phase with `proposal.md` +
  `tasks.md` (all items `[x]`) + carried evidence; that Tier 2's
  `specs/<capability>/spec.md` exists and `openspec validate --all` is
  green with no `[GAP:]` left; that `.planning/` is gone and
  `docs/legacy-planning/` present; and that the change-gate returns
  exit 2 before review and 0 after (the §18 truth table).
- The runnable `run-tests.sh` and its fixture refs live **in the
  adopting host repo**, not here — this recipe specifies the contract they
  assert. cParX's live `openspec/` (per `PILOT-REPORT.md`) is the first
  such fixture source.
