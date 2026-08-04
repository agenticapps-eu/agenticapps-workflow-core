# Session Handoff — 2026-08-04 (sixth session of the day)

## Accomplished

- **8.4 closed: core PR 2 (#74) independently reviewed** in this cleared session
  (§07 — a cleared session, never a subagent). `CODE-REVIEW-PR2.md` holds it.
  **Approved.**
- **8.5b closed: #74 squash-merged as `e69e471`.** The change is shipped. All
  eight PRs are merged — core #73, the seven fleet PRs, core #74.
- Two findings from the review, both fixed on the branch before it merged.

### The review re-ran the evidence rather than reading the diff

PR 2 carries no executable change; its content is a claim. So every table in
`PROPAGATION-EVIDENCE.md` that could be re-run, was:

| Claim | Re-run |
|---|---|
| fleet reports 0 | `OK — no known vector found` |
| 21 binders, 7/7/6 per hook | 21 `MARKER` lines, 20 current, opt-out reads `no shim file` |
| core reports 33, composed 2/2/29 | exact |
| 7.4 across all seven repos | benign `Edit` 0, `DROP TABLE` 2, `migrations/*` 0 |
| 1.2.0 three matched calls | exit 1/1/1, stderr 4/1/1 |
| 1.1.0, same three | exit 1/1/1, stderr 4/**0/0** — the defect reproducing |
| occupied shared path | 1.2.0 exit 1 with the sentence; 1.1.0 exit **126** |
| suites | 64/64, 60/60, 12/12, validate 5/5 |
| the fold-in | all 6 requirements landed verbatim; spec 17 → 21 |

It reproduced to the exit code and the bash error string. The 3.1 isolation
claim held too — the real marker's mtime never moved.

### The two findings — both a number answering a narrower question than its sentence

1. **The archive exemption was credited with 29 of core's 33 findings.** Only 14
   of the 29 are under `openspec/changes/archive/`. The exemption takes core
   33 → **19**, not → 4. The true sentence (*29 of 33 are override-vector*) sat
   three lines above, which is how the two fused.
2. **The 29's composition called all of them documents.** Five are the
   mechanism: the published shim template the fleet vendors,
   `install-core-git-hooks.sh`, the gate reference README twice, and
   `project-hook-conformance.sh` — **the instrument reports its own override
   vector**, and the row did not say so.

Finding 2 widens an open question. *"Documenting the contract inside a fleet
repo costs a permanent finding"* is the narrow version; **implementing** it
costs one too, and no exemption scoped at documentation reaches that.

## Decisions

- **The merge was asked for, not assumed.** The review had just changed the
  branch, so the user had not read what was about to land. Confirmed, then
  squash-merged.
- **8.5b ticked in a follow-up PR rather than left open.** An archived change
  whose last task still reads "ship" is the same fiction-about-itself that 4.4
  existed to close.
- **Both findings fixed by the reviewer**, because each is a number correction
  verifiable against command output recorded in the same file — not a judgement
  that needs a second opinion.

## The theme, now at nineteen

19. **The instrument is inside its own blast radius.** `project-hook-conformance.sh`
    is one of the 29 override vectors it reports against core. That is the scan
    working — it names the variable because it implements the mechanism — but
    the composition row filed it under "tests, ADRs, change docs and spec
    files", where a reader would never look for it. Same shape as 17 and 18: not
    a wrong number, a number answering a question nobody asked.

## Files modified

Merged in #74 (branch deleted):

- `…/archive/…/CODE-REVIEW-PR2.md` — new, the PR 2 review
- `…/archive/…/PROPAGATION-EVIDENCE.md` — 7.2's composition row corrected; the
  exemption's actual yield stated
- `…/archive/…/tasks.md` — 8.4 + 8.4b closed
- `session-handoff.md` — the 29/14 correction

On `chore/close-shipped-task` (this PR):

- `…/archive/…/tasks.md` — 8.5b closed
- `session-handoff.md` — this file

## Next session: start here

**The change is done.** Nothing remains in
`2026-08-04-shim-suppressed-report-and-fleet-propagation`; every task is ticked
and every PR merged.

The next piece of work is the one this change kept deferring and the review
flagged again: **the instrument change**. Propose it as a new OpenSpec change.
Its scope is now three items, all recorded with evidence:

1. **`--fleet` must report each project's checkout state** beside its findings
   (ahead/behind, or at minimum HEAD date and fetch staleness). It misread the
   fleet twice in opposite directions — 46 findings that were one laptop, then
   7 that were one branch.
2. **Core declares its two non-bindings in `OPT-OUTS`** — `database-sentinel`
   and `normalize-claude-md`, which core hosts but does not bind. Clears 4 of
   core's 33.
3. **The override-vector scan exempts `openspec/changes/archive/`** — worth 14,
   taking core 33 → 19. It does **not** clear the 5 implementation files, and
   should not.

Start with `/opsx:propose`. Until it lands, do not quote a `--fleet` number
anywhere without saying which checkouts produced it.

## Open questions

- **Documenting *or implementing* the contract costs a permanent finding.**
  `agents-task-viewer`'s `bin/README.md` omits the override variable's name for
  exactly this reason; core's own shim template cannot. Whether the scan should
  distinguish "names the variable" from "sets the variable" is unanswered, and
  is probably the real fix behind item 3.
- **7.1's "0" is reachable only because no fleet repo has docs prose naming an
  override variable.** Add one file that does and 0 stops being reachable.
- **Two local merge commits sit unpushed on `main`**: `callbot` (`ea23f9c`) and
  `fbc-platform`'s feature branch. Neither is mine to push.
- **27 branches carry genuinely unmerged content**, still unjudged for worth.
- The convergence rule is still unwritten — fourteenth session.
- **Two neuroflash PRs remain open** (api-docs #14, terraform #185) — different
  family, untouched.
