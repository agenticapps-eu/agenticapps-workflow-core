# Session Handoff — 2026-08-04

## Accomplished

- **The axes-table Currency contradiction is fixed** — the change the last
  handoff named as next. The table's `stale` clause now scopes to a declared,
  **present** artifact, matching the qualifier its own `current` clause already
  carried. Not a judgement call in the end: the requirement prose, the scenario,
  and `provisioning-check.sh:422` (`[ -f "$art" ] || continue`) all already
  agreed against the table. Three sources including running code.
- **A second, worse defect was found and fixed in the same change.** The archive
  fold at `09f829e` had **torn a paragraph in half across two requirements** —
  first half ending mid-clause at `:861`, second half filed ~66 lines away
  inside a different requirement at `:927`. Intact in the pre-fold delta at
  `db02493`, so the fold caused it, not the split in #70. Restored byte-for-byte.
- **PR #71 is open and green.** Both defects, plus a CI guard.
- **`tools/spec-placement.test.sh` is committed and wired into CI.** It landed
  RED (`f96b5a6`) and went GREEN after the fold (`6cb2e7e`) — a real RED/GREEN
  pair. It sweeps every spec, not just this one.
- **All five specs are now swept for tears. The other four are clean.** So
  `project-hook-binding` carried the only one, and there is no backlog to file.

## Decisions

- **Bundled the normative fix and the placement repair into one change** — you
  chose this. Not a reversal of last session's refusal: that forbade *concealing*
  a normative change inside a refactor advertised as semantics-free. Here both
  are advertised, labelled separately in the delta, and they touch the same
  requirement, so splitting would have meant editing one requirement twice
  across two lifecycles.
- **Fixed the table, not the requirement or the code.** The alternative would
  have required editing `provisioning-check.sh` to *add* a finding that says
  nothing new, contradicting the requirement's own stated rationale.
- **Declined two reviewer objections with reasoning.** codex's `current`/`unknown`
  precedence claim is wrong — the spec specifies it twice (`:986-987`, `:998`)
  and the implementation matches. And a Stage-2/Stage-3 relabelling that comes
  from a real vocabulary collision in the workflow doc, not from a defect.
- **Left the EOF trailing newline alone.** It is `openspec archive`'s own output;
  two other specs end the same way. Hand-editing would fight the tool.

## The theme, now at seven instances — and one of them was mine

Every failure in this lineage is a **check that lied**. Two more this session:

6. **`openspec validate --all` was green on both defects the whole time**, and so
   was the line-multiset diff. It proved every line survived — which was *true*
   and useless. Every line did survive, in the wrong requirement.
7. **I wrote the guard with a bug that blinded it to its own motivating case.**
   The first version excluded lines opening with a backtick from the
   "paragraph ends mid-sentence" signature; the torn line opens on
   `` `CLAUDE.md` ``. It still reported RED — because the *other* signature
   caught the orphan. A test passing for the wrong reason, inside the change
   about tests that pass for the wrong reason.

codex then caught an eighth in review: the guard's success message claimed
"every paragraph is whole", which it cannot know. It now states scope, not
conclusion — the same rule the spec already imposes on the override scan
(*no known vector found*, never *the repository is clean*).

## Files modified

- `openspec/specs/project-hook-binding/spec.md` — both repairs (2 MODIFIED reqs)
- `tools/spec-placement.test.sh` — **new**, the CI guard
- `.github/workflows/openspec-gate.yml` — new step, runs the guard on every change
- `openspec/changes/archive/2026-08-04-repair-currency-axis-table-and-fold-tear/`
  — incl. `REVIEW-RESPONSE.md` (two rounds) and `REVIEWS.md`
- `tools/provisioning-check.sh` — **deliberately unchanged**, verified byte-identical

## Next session: start here

**PR #71 needs the independent code review in a cleared session** — `/clear`,
then review the branch. It is the one gate this branch does not carry evidence
for, and it is checked off in `tasks.md` as *scheduled against the PR*, not
performed. Everything else is verified: validate green, guard green in CI across
all five specs, gate `--ci` exit 0, 8/8 placement assertions, 16/16 tasks.

After it merges, the open questions below are unchanged from last session and
none were touched by this work.

## Open questions

- **The guard only detects tears at paragraph boundaries.** A fragment relocated
  as a whole, grammatically intact paragraph passes it. Narrowed, not closed —
  the independent reviewer is still the only thing that reads for sense.
- **`provisioning-check.sh` is still not published to the shared bin.** Currency
  works and defaults on, but only where core is checked out. Nothing prompts
  anyone on a machine without a core checkout to discover their install is stale.
- **The `cmp`-error branch is reasoned, not tested.** Negative evidence.
- **The `PostToolUse` fail-open channel remains unverified** — ninth session.
- **27 branches carry genuinely unmerged content**, classified for reachability
  and never for worth. Nobody has judged whether any of it is wanted.
- The convergence rule is still unwritten — ninth session.
- **Two neuroflash PRs from last session are still open** (api-docs #14,
  terraform #185) — outside this family's context boundary, untouched here.
