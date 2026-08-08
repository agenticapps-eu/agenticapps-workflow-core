## 1. Fix the arbiter first

The diagram is the test every removal below is judged against. It states two
things that are false, so it is corrected before it is used. Per the capability,
the correction is argued from ADR-0027 and `change-gate-enforcement`, not from
"the code does something else".

- [ ] 1.1 `workflow.mmd` line 7 — the hook node reads *"no code edits until
      validate GREEN and REVIEWS ≥ 2"*. Restate it as the one condition that
      blocks: `openspec validate --all` not green
- [ ] 1.2 `workflow.mmd` line 13 — **do not remove the db-sentinel arm.** An
      earlier revision did, on the assumption it named the removed
      `PreToolUse` hook. It does not: `spec/17-lifecycle-and-gate-mapping.md`
      lines 99–100 make `database-security` and `db-pre-launch-audit`
      **Conditional (db-sentinel)** gates, and
      `skills/agentic-apps-workflow/SKILL.md` lines 110–119 bind
      `database-sentinel` as an **upstream skill** whose Critical/High findings
      block branch close. The hook and the skill gate are different things with
      the same name — removing the hook does not retire the gate.
      Disambiguate the arm so it plainly names the skill gate, or leave it
      unchanged. Retiring the gate would need its own normative change against
      §17 and ADR-0012
- [ ] 1.3 `workflow-diagram.mmd` **duplicates** `workflow.mmd` and carries the
      same stale statements. It is the same class of defect as `gate/` — a second
      copy nothing reconciles. Determine which is canonical, delete the other, and
      record which readers were being served by the duplicate
- [ ] 1.4 Re-render or re-check the diagram so the corrected source is what
      readers see, and record where the rendered copy lives if one is published
- [ ] 1.5 Confirm no other shipped text asserts "REVIEWS ≥ 2" as blocking —
      including `SIMPLIFICATION-PLAN.md` and
      `docs/recipes/0001-planning-to-openspec.md`, which describe review blocking
      and were missed by an earlier revision. Handoff open question 6

## 2. Remove `gate/` — the largest single item

An entire published gate, pre-2.0.0, that nothing resolves. It defaults
`MIN_REVIEWERS=2`, returns a blocking exit on insufficient reviewers, treats
`GSD_SKIP_REVIEWS=1` as a live bypass of that live block, and its README
documents this as contract.

- [ ] 2.1 Read `reference-implementations/shared-install/resolve-core-artifact.sh`
      and record the mapping verbatim. It maps the shared install to
      `reference-implementations/openspec-change-gate/openspec-change-gate.sh` —
      assert this rather than assume it
- [ ] 2.2 Compare `~/.agenticapps/bin/openspec-change-gate.sh` against both
      candidates by digest. Measured 2026-08-07: it matches the reference
      implementation (`bc947e37…`), not `gate/` (`23310b7d…`). Re-verify
- [ ] 2.3 Grep the repository and the fleet for anything resolving `gate/`.
      Record what was searched, and state that other machines were not — this
      machine is the only one running the workflow, which bounds the claim
      rather than proving it universally
- [ ] 2.4 Remove `gate/openspec-change-gate.sh`, `gate/README.md`,
      `gate/pre-commit` and `gate/hooks/`
- [ ] 2.5 Update `install.sh` and any manifest naming `gate/` as a published path

## 3. The gate says what it does

- [ ] 3.1 Correct the gate header's `MIN_REVIEWERS` entry. It reads *"blocking
      floor (spec 1.1.0 MUST)"*; the code applies it only to selecting which NOTE
      prints, under a comment reading `REPORTED, NOT BLOCKED`
- [ ] 3.2 Correct `PREFERRED_REVIEWERS` if it carries the same overstatement, and
      the two further wrong lines at 85 and 173
- [ ] 3.3 Check the header's other entries against their code. Several were
      wrong; the failure mode is not specific to these

## 4. Remove GSD_SKIP_REVIEWS from every surface

The hatch escapes nothing since 2.0.0. Its only remaining effect is suppressing
the review NOTE lines — hiding evidence that is present, under a name promising to
proceed without evidence that is absent.

- [ ] 4.1 RED: a test asserting `GSD_SKIP_REVIEWS` does not occur in the gate's
      source or documentation. The requirement is **absence**, verified by
      reading the source — not behaviour-when-set, which would keep the name in
      the interface
- [ ] 4.2 Remove the hatch branch from
      `reference-implementations/openspec-change-gate/openspec-change-gate.sh`
      and its header documentation
- [ ] 4.3 **`reference-implementations/run-plan-review/run-plan-review.sh:677`**
      tells the operator to `use GSD_SKIP_REVIEWS=1 for a logged emergency
      override` when too few reviewers respond. Replace it with what actually
      follows: reviews do not block, so the operator may proceed.
      *This refutes an earlier claim in this change that the conformance rows
      were the flag's only live consumers. They were not*
- [ ] 4.4 `spec/18-retargeted-change-gate.md` — remove the truth-table row at
      line 104 and the prose at line 235 stating the gate keeps the hatch
- [ ] 4.5 Remove the conformance rows asserting hatch behaviour in
      `tools/change-gate-conformance.sh`. They assert an interface that will not
      exist. Do **not** replace them with a row asserting the variable is
      ignored — that re-establishes it as a name the gate knows
- [ ] 4.6 **The full remaining surface**, measured 2026-08-07 — this list was five
      entries in an earlier revision and was completed by a reviewer, so treat it
      as a floor rather than a ceiling:
      `skills/agentic-apps-workflow/SKILL.md` (core's own trigger skill),
      `.claude/hooks/openspec-change-gate.sh`,
      `reference-implementations/openspec-change-gate/README.md`,
      `reference-implementations/openspec-change-gate/hooks/openspec-gate.ci.yml`,
      `reference-implementations/project-hooks/openspec-change-gate.shim.sh`,
      `CLAUDE.md`, `docs/HOW-IT-FITS-TOGETHER.md`, `WORKFLOW-EXPLAINED.md`,
      `GATE-INVENTORY.md`, `PILOT-REPORT.md`,
      `docs/instruction-file-audit-2026-08.md`,
      `prompts/03-cparx-sandbox-pilot.md`,
      `OpenSpec-Change-Cheatsheet.html`, `publish/index.html`
- [ ] 4.7 The global `~/.claude/CLAUDE.md` §18 paragraph and the fleet's
      `.claude/claude-md/workflow.md` and `workflow-config.md`
- [ ] 4.8 `codex-workflow`'s `codex-openspec-change-review` skill advertises it.
      Out of this repository — record it for that repo rather than editing across
      the family boundary
- [ ] 4.9 Re-verify no shell profile, `settings.json`, or repository *sets* it.
      Measured 2026-08-07: every real assignment is a test row or a document.
      Record what was searched and what was not

## 5. Finish the removals already decided

- [ ] 5.1 Delete `reference-implementations/project-hooks/database-sentinel.sh`.
      **Hard block, and the block is unconditional.** Precondition, objectively
      checkable: `database-sentinel` absent from
      `reference-implementations/project-hooks/SHIMMED-HOOKS` on the merge base.
      `projects-bind-not-copy` owns that edit and is unmerged with no PR.
      **If it stalls, this task drops** — it does not acquire the declaration
      edit. An earlier revision offered that as a fallback, which would have made
      this change edit `project-hook-binding`, the exact surface its Capabilities
      section declines to delta. One owner, no conditional second owner
- [ ] 5.1a **Delete `~/.agenticapps/bin/database-sentinel.sh`** in the same
      change. It exists right now (5.2k, 6 Aug) and it is the copy the shims
      actually invoke, so deleting only the repository implementation leaves the
      hook running with its source gone. Redacted evidence, as §6
- [ ] 5.1b **`~/.agenticapps/bin/normalize-claude-md.sh` is still installed**
      after PR #87 retired it — the same defect, one removal earlier, undetected.
      Report it and remove it, or record why it stays. Found while verifying 5.1a
- [ ] 5.1c Enumerate `~/.agenticapps/bin/` against what the repository still
      publishes and report every orphan. Current contents: `reviewer-cli.sh`,
      `openspec-change-gate.sh`, `normalize-claude-md.sh`, `run-plan-review.sh`,
      `database-sentinel.sh`
- [ ] 5.2 Delete core's own `.claude/skills/gitnexus/` — six skills, still loading
      in this repository. Handoff open question 9
- [ ] 5.3 Leave `adrs/0012` unedited; it records `database-sentinel`'s reasoning

## 6. Machine-level, outside version control

Not shipped artifacts, so they are steps with recorded evidence. Evidence is
**redacted** — unescaped `/Users/donald` paths in published records are handoff
open question 7, deferred four times, and this change will not repeat it.

- [ ] 6.1 Remove `~/.claude/skills/ts-declare-first` — a dangling symlink into
      `~/.claude/skills/agenticapps-workflow`, which no longer exists. Record the
      target with the home path redacted.
      **Note:** this symlink's absence is *not* evidence §13 is unused. Three
      hosts bind §13; an earlier revision drew the opposite conclusion from
      exactly this file and was wrong
- [ ] 6.2 Remove the `gitnexus` MCP server entry from
      `~/.config/opencode/opencode.json`. Back up the file first, make a targeted
      JSON edit rather than a rewrite, record the entry's *structure* with paths
      redacted, and confirm opencode starts and loads config afterwards
- [ ] 6.3 Correct the global `~/.claude/CLAUDE.md` warning that two skills claim
      the `agentic-apps-workflow` name. One of the two is gone, so the warning
      sends readers after a conflict that does not exist

## 7. The fleet sweep

- [ ] 7.1 Delete the four stale `SKILL.md.pre-0034` files — `agenticapps-roadmap`,
      `agents-task-viewer`, `callbot`, `fx-signal-agent`
- [ ] 7.2 Record a directory listing before and after each deletion. The check
      that would catch a mistake is `projects-bind-not-copy`'s, which does not
      exist yet, so the evidence is manual
- [ ] 7.3 Sweep for `workflow.md.pre-0034` under `.claude/claude-md/` — the same
      backup pattern, in at least three repositories

## 8. Record what was found, not just what was done

- [ ] 8.1 Write the ADR recording these removals and the test applied. ADRs are
      append-only, so this is a new record rather than an edit to 0012 or 0027.
      Redact home paths
- [ ] 8.2 Record `agenticapps-dashboard-add-agent-board` — a stray worktree
      carrying its own gate and conformance harness, and the likeliest source of
      the repeated fleet miscounts. **Recording only**; its disposition is design
      open question 2
- [ ] 8.3 Note in the ADR that every completed removal left surface behind and
      none of it failed anything. That is the argument for the capability existing
- [ ] 8.4 Record why **§13 is not in this change**: an earlier revision proposed
      retiring it on the claim that no host bound it, derived from one dangling
      symlink in `~/.claude/skills`. Three hosts bind it, and pi reached `full`
      conformance at host v0.6.0 by binding it. The machine-level absence was read
      as a fleet-wide one

## 9. Verify

- [ ] 9.1 `openspec validate --all --strict` green
- [ ] 9.2 The conformance harness passes with the hatch rows removed
- [ ] 9.3 Task 4.1's test green: `GSD_SKIP_REVIEWS` absent from the gate's source
      and documentation
- [ ] 9.4 Grep for `GSD_SKIP_REVIEWS`, `gitnexus` and `database-sentinel`. Every
      surviving hit is in `adrs/`, `openspec/changes/archive/`, `CHANGELOG.md`, or
      a change document describing the removal. **This is a backstop, not
      coverage** — the surface list in 4.6 was incomplete twice
- [ ] 9.5 `ts-declare-first` still resolves: `spec/13-ts-declare-first.md` present,
      the three host bindings intact. This change removes a dangling symlink and
      nothing else about §13
- [ ] 9.6 The gate still runs from `~/.agenticapps/bin/` after `gate/` is removed,
      and a fleet repository's hook still resolves it
- [ ] 9.7 **A conformance assertion, not a one-time grep.** `gate/` drifted for a
      month because nothing checked for it, and this change's own thesis is that
      unenforced rules fail silently. Add a check that fails when a second copy of
      the gate exists in the repository, and when
      `~/.agenticapps/bin/` holds an artifact the repository no longer publishes.
      Without it this capability documents its rule exactly the way the stale
      docs documented theirs
- [ ] 9.8 Reconcile the Impact section against task 4.6 — Impact omits root
      `CLAUDE.md` (= `AGENTS.md`), `.claude/hooks/openspec-change-gate.sh`,
      `docs/instruction-file-audit-2026-08.md` and
      `prompts/03-cparx-sandbox-pilot.md`. Renumber the design's Migration Plan
      references, which cite steps 7 and 9 for what this file numbers 6 and 8
