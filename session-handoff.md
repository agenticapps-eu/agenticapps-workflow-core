# Session Handoff — 2026-08-05 (second session)

## Accomplished

**Everything opened this session is merged. Three PRs, all on `main`.**

| PR | What | Commit |
|---|---|---|
| #79 | §12 0.10.0 → 0.11.0 + conformance harness + 77-assertion suite | `5d74f3e` |
| #80 | `installer-prerequisite-consent` proposed (Part 2a) | `50f6686` |
| #81 | Archive fold — 13 requirements into two durable specs | `f7efcaa` |

`openspec/specs/` gained `host-neutral-instruction-files` (7 requirements) and
`agent-lifecycle-management` (6). `openspec validate --all` 8/8, harness suite
77/77, `spec-placement.test.sh` clean.

**One round of plan review on #79 and #80. Six reviewers, six
REQUEST-CHANGES** — and they were right. Most findings were contradictions the
changes shipped with, not scope the reviewers wanted added. All addressed
before merge.

The two that mattered:

- **#79 had no repair path for stale content.** Adding an agent is a no-op once
  present, and byte-identical *forbade* a later host rewriting the section — so
  a repo provisioned from a GSD-citing template would cite GSD forever. The
  change diagnoses template drift and its own mechanism made drift permanent.
  Fixed: the section carries a content version and a newer host offers an update.
- **#80's central claim was false on its own rule.** It said two installers were
  non-conformant. The delta drew the consent boundary at "outside the target
  repository", and all four write `~/.agenticapps/bin/` unconditionally
  (verified: claude:149, codex:211, opencode:329, pi:148) — so it condemned all
  four and put a prompt in front of `PLAN-lightweight-fleet` step 2's publishing
  mechanism. Boundary rewritten to **ownership, not location**.

Also fixed on #79: removal contradicted itself three ways; the marker literal
existed only in prose so no host could implement from the spec; provisioning
couldn't converge from a half-installed state; the denylist was normative with
contents deferred; the proposal said duplicates "collapse" while the delta
forbade it; a report was required to name a host the file records no provenance
for.

## Decisions

- **Consent boundary is ownership.** Could this write change software the
  operator did not install by running this installer? `~/.agenticapps/bin/`
  cannot — reported, not prompted. `npm i -g` can — acceptance required.
- **A system runtime is never offered** (Donald: "not thinking of npm"). `npm`,
  `node`, `git`, host CLIs — detect and instruct only. What may be offered is a
  package installed *through* a runtime already present. Closed #80 task 1.2.
- **Multi-agent is permanent** (Donald). Step 4 removed as a gating question
  from both changes: only *which* hosts is open. Saved to memory.
- **Links are a frontmatter list carrying paths** (Donald, over a per-agent
  marker pair). Frontmatter sits outside the markers, making the link exemption
  structural rather than a special case.
- **Host *names* warn, host *paths* fail.**
- **`installer-prerequisite-consent` deliberately NOT archived** — proposal
  only; folding its delta would assert a capability nothing implements.

## Files modified

All merged to `main`:

- `spec/12-authoring-conventions.md` — 0.11.0, new subsection
- `CHANGELOG.md` — the 0.11.0 entry
- `tools/agents-md-conformance.sh`, `tools/agents-md-conformance.test.sh` — new
- `.github/workflows/openspec-gate.yml` — two steps
- `openspec/specs/{host-neutral-instruction-files,agent-lifecycle-management}/` — new
- `openspec/changes/archive/2026-08-05-host-neutral-agents-md/` — archived
- `openspec/changes/installer-prerequisite-consent/` — active, proposal only

## Next session: start here

**`/opsx:apply` on `installer-prerequisite-consent`** — the only active change.
Its blocking questions are answered (ownership boundary, opt-in flag name,
runtimes never offered), so start at task group 2: write
`spec/NN-installer-prerequisites.md`, assigning the section number first. Task
1.5 is still open but does not block — what happens to a prerequisite installed
on the operator's behalf when the workflow is removed.

## Open questions

- **CodeRabbit has reviewed none of these PRs.** All three showed a green check;
  #81's body reads "Review limit reached — we couldn't start this review", and
  #79/#80 were PENDING at merge. The state is not the review.
- **The plan reviews predate the merged text.** Both `REVIEWS.md` record 3/3
  REQUEST-CHANGES against versions since rewritten in response. That is the
  honest state of one round plus fixes — the reviewers never saw the corrected
  specs, including #80's ownership boundary, which their sharpest finding forced.
- **Concurrent provisioning** is an accepted limit in
  `host-neutral-instruction-files`.
- **Nothing verifies a linked file is actually read** — the harness can check a
  link resolves, not that a runtime dereferences it.
- **The producer/consumer asymmetry is still unowned.** The section version
  repairs stale *section* prose; nothing checks a correction applied to
  consumers reaches the producer template.
- **`.planning/skill-observations/*` is still being written** despite the freeze
  rule. Unchanged across four handoffs.
