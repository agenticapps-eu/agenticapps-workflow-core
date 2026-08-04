# Stage-2 code review — core PR 2 (#74)

Run in a cleared session (§07 independence — a cleared session, never a
subagent). The session that wrote #74 could not review it.

This PR carries no executable change. Its content is a claim — *contract 1.2.0
reached the fleet, and the two defects it repairs are gone on the surface they
appeared on* — plus the archive that folds the delta into the spec on the
strength of that claim. So this review is almost entirely re-running the
evidence rather than reading the diff, which is the right shape for a PR whose
subject is an instrument that answered confidently about the wrong thing.

**CodeRabbit's green check on this PR is `pass — Review rate limited`.** It did
not review #74. This review is therefore the only review #74 received.

## Verified first, so the two findings are not the whole picture

Everything below was re-run in this session against the branch, not read out of
the evidence file.

| Claim in #74 | Re-run result |
|---|---|
| 7.1 — fleet reports 0 | `--fleet ~/Sourcecode` → `OK — no known vector found` |
| 21 binders, per-hook 7 / 7 / 6 | 21 `MARKER` lines, 20 `current (1.2.0)`; `agents-task-viewer/normalize-claude-md` = `declared opt-out`, `no shim file` |
| 7.2 — core reports 33, composed 2 / 2 / 29 | 33; `MARKER … ABSENT` 2, `MATCHER … not registered` 2, `OVERRIDE-VECTOR` 29 |
| core's one real binder reads current | `MARKER  .  openspec-change-gate  current (1.2.0)` |
| 7.4 — all seven repos | benign `Edit` → 0 on every bound shim; `DROP TABLE` → 2; `migrations/*` → 0. All seven. `agents-task-viewer` runs two shims, not three |
| 3.1/3.2 — 1.2.0, three matched calls | exit 1 / 1 / 1, stderr 4 / 1 / 1 lines; calls 2–3 say the failure is a repeat |
| the same three under 1.1.0 | exit 1 / 1 / 1, stderr 4 / **0 / 0** — the defect, reproducing at an identical exit code |
| occupied shared path | 1.2.0 → exit 1, *"exists but is not an executable regular file"*; 1.1.0 → exit **126**, bash's own `is a directory` |
| suites | shim 64/64, conformance 60/60, wrapper 12/12, `openspec validate --all` 5/5 |
| archive fold-in | 4 ADDED + 2 MODIFIED, all six landed **verbatim**; main spec 17 → 21 requirements; the 6 deleted lines are all rewordings inside the two MODIFIED bodies |
| `project-hook-conformance.sh:454` strips `FINDING` | it does — `sed 's/  FINDING$//'` |
| `project-hook-conformance.sh:323` exempts byte-identity | it does — `self-hosting — out of profile` |
| 6.5a — the gate copy is load-bearing in CI | `openspec-gate.yml:74` runs `change-gate-conformance.sh` against it, `:96` runs `openspec-gate-ci.sh`, `core-vendor.manifest:27` pins its sha256 — and the pin **currently matches** |
| 6.6 — ADR 0009 recovered and linked | present; `CLAUDE.md:23` links it, and 23 is above the first `GSD:` block at 121 |

The isolation claim in the 3.1 deviation checks out too: the real marker's mtime
is still 09:14, unmoved by this session's re-runs of the same scenario.

Both findings below are the change's own subject applied to the change: a number
that answers a narrower question than the sentence around it. Neither touches
the spec, the instrument, or the archive.

## Finding 1 — the exemption is credited with 29 findings; it would remove 14

`session-handoff.md`, in Open questions:

> core declaring its two non-bindings in `OPT-OUTS`, and the override-vector
> scan exempting `openspec/changes/archive/` (29 of core's 33 findings).

The parenthetical sits on the exemption clause and reads as what the exemption
buys. It does not. Measured:

```
$ tools/project-hook-conformance.sh .          # core, positionally
33 finding(s) reported above.

OVERRIDE-VECTOR total                     29
  … under openspec/changes/archive/       14
  … elsewhere                             15
```

Exempting the archive takes core from 33 to **19**, not to 4. The true sentence
— *29 of the 33 are override-vector* — is also in the text three lines earlier,
which is how the two fused.

This matters more than a stray digit because the handoff is the continuity
mechanism: the next session scopes the instrument change from this line, and it
currently over-states the archive exemption's yield by 2×.

## Finding 2 — the 29's composition omits the five that are not documents

`PROPAGATION-EVIDENCE.md`, 7.2:

> `OVERRIDE-VECTOR` | 29 | core's own tests, ADRs, archived change docs and
> spec files, which **name** the override variables because core is where the
> override mechanism is specified and tested

Five of the 29 are none of those four things:

```
OVERRIDE-VECTOR  .  OPENSPEC_GATE         reference-implementations/openspec-change-gate/README.md
OVERRIDE-VECTOR  .  OPENSPEC_CHANGE_GATE  reference-implementations/openspec-change-gate/README.md
OVERRIDE-VECTOR  .  OPENSPEC_GATE         reference-implementations/project-hooks/openspec-change-gate.shim.sh
OVERRIDE-VECTOR  .  OPENSPEC_GATE         tools/install-core-git-hooks.sh
OVERRIDE-VECTOR  .  OPENSPEC_GATE         tools/project-hook-conformance.sh
```

The description makes the 29 sound like prose about the mechanism. Three of
these are the mechanism: the **published shim template the whole fleet
vendors**, the **installer**, and **the instrument itself**. The instrument
reports itself as an override vector and the composition row does not say so.

It also weakens the open question it sits next to. *"Documenting the contract
inside a fleet repo costs a permanent finding"* is the narrow version; the wide
one is that **implementing** it does too, and no exemption scoped at
`openspec/changes/archive/` reaches that. After the archive exemption, 15
findings stand — 5 tests, 3 spec files, 2 ADRs, and these 5.

## Not findings

- **The baseline's `21 + 21 + 4 = 46`** cannot be re-run — the stale checkouts
  it measured are gone, which is the point of the change. It is internally
  consistent with what is reproducible now: 7 repos × 3 hooks = the same 21
  marker slots that read clean today.
- **The 6.5a counterfactual** (*"with the variable's name, one finding against
  that repo; without it, zero"*) is half-checkable: the zero half reproduces —
  `agents-task-viewer` scores clean today. The other half would require editing
  a fleet repo, which a review should not do.
- **`--fleet` reads working trees and says nothing about their age.** Recorded
  in the PR as deliberately unfixed. Re-flagging it here only because this
  review's own green results inherit the same limitation: they are a statement
  about seven checkouts on this laptop at this moment, which is exactly the
  conflation the PR documents. The instrument change should land before the next
  fleet number is quoted anywhere.

## Verdict

**Approve.** Every reproducible claim reproduced, several of them to the exit
code and the error string. The two findings are prose arithmetic in artifacts
the PR ships, not defects in the spec fold-in, the instrument, or the shims —
and both were corrected on the branch after this review, each against the
command output recorded above.
