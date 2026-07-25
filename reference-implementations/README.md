# Reference Implementations

Host repos that adopt (or will adopt) the AgenticApps workflow spec — and, as of
2026-07-25, the artifacts this repo publishes *for* them to adopt.

## Published implementations

| Directory | Satisfies | Conformance |
|---|---|---|
| [`openspec-change-gate/`](openspec-change-gate/) | [§18](../spec/18-retargeted-change-gate.md) | `tools/change-gate-conformance.sh` — 37/37 |
| [`reviewer-cli/`](reviewer-cli/) | [§18](../spec/18-retargeted-change-gate.md) (review production) | `tools/reviewer-cli-conformance.sh` — 14/14 |
| [`shared-install/`](shared-install/) | the shared-path install contract | `tools/shared-install-conformance.sh` — 12/12 |

The gate **consumes** review evidence; `reviewer-cli` **produces** it. Both
install to the shared `~/.agenticapps/bin/`, and both therefore carry a version
marker that installers MUST arbitrate on — `# gate-version:` and
`# reviewer-cli-version:` respectively. An unmarked file is `0.0.0`.

`shared-install/` is **how** that arbitration must be performed. Refusing to
downgrade is necessary and not sufficient: the compare and the write have to be
serialised, or two installers each deciding correctly against the same observed
state still let the later writer win. Per-host arbitration does not compose into
machine-wide monotonicity, so the arbiter is published once and called by all
four hosts rather than reinvented in each.

Offered, not mandated: §18's normative text is unchanged and a host may still
ship its own. But the same failure has now happened twice — five divergent gate
copies before this directory existed ([#32](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/32),
ADR-0022), then three divergent `reviewer-cli` copies that silently dropped a
vendor arm at the shared path
([#41](https://github.com/agenticapps-eu/agenticapps-workflow-core/issues/41)).
Both went unnoticed because a drifted artifact reports clean. The burden of proof
sits with a host that writes its own. Score it either way:

```bash
tools/change-gate-conformance.sh  --family
tools/reviewer-cli-conformance.sh --family
```

**Current spec version:** 1.0.0 (released 2026-07-24) — the first major,
replacing the GSD-engine front end with the **OpenSpec + Superpowers** front
end (§16–§19, ADR-0021). **No host cites 1.0.0 yet:** it coexists with the 0.x
line (§09 "Two front ends coexist"), the fleet below remains valid at
**0.10.0**, and the first adoption target is the cParX app repo (pilot recorded
in `PILOT-REPORT.md` / `MEASUREMENT.md`, migrated via
`docs/recipes/0001-planning-to-openspec.md`). See `CHANGELOG.md`
in the spec root for the host-implementer actions required to move a
host row between versions. Host rows below move via the
host's own adoption PR, not via this file.

| Host repo | Type | Spec version implemented | Conformance level | Notes |
|---|---|---|---|---|
| [claude-workflow](https://github.com/agenticapps-eu/claude-workflow) | Workflow scaffolder for Claude Code | 0.9.0 | `full` | Source of canonical prose. Audited 2026-07-14 (host ADR-0040); `skill/SKILL.md` carries `implements_spec: 0.9.0`. §10 observability and §14 prompt-injection **delegated** to the standalone [`agenticapps-observability`](https://github.com/agenticapps-eu/agenticapps-observability) skill (0.13.0) and its `injection-guard` sub-skill — *satisfied* MUSTs per §09, not deltas; migrations `0022`/`0023` fail closed if the skill is absent. The `add-observability` skill this row previously credited was removed from this host at its 2.0.0 (`217baec`) and now lives in that standalone repo. §15 knowledge capture wired at all three ritual triggers, config-routed (no hardcoded vault path), guarded by `check-snapshot-parity.sh`. Setup installs via **snapshot, not replay** (host ADR-0036) — conformant under §08 **as amended at 0.9.0** (ADR-0018), with end-state equivalence guarded by `migrations/check-snapshot-parity.sh` in CI. Spec deltas listed in the host's `skill/SKILL.md`: §13's implicit GSD trigger is unwired (§13's Conformance is SHOULD/MAY and the host is not a TS project); a divergent §04 copy ships in the host's vendored CLAUDE.md payload (the canonical block is byte-identical in the host's own instruction file, so §09 item 1 holds). |
| [codex-workflow](https://github.com/agenticapps-eu/codex-workflow) | Workflow scaffolder for OpenAI Codex CLI | 0.10.0 | `full` | Adopted **0.10.0** at scaffolder v0.9.0 (migration `0012`), which did two things at once. **§12 instruction-surface economy:** `AGENTS.md` slimmed 269 → 120 lines to the §11 block plus a trigger-skill pointer and a session-handoff pointer; the §02 gate table, task-size routing, the session-handoff protocol, the §15 ritual tail and the plan-review *procedure* moved into the lazily-loaded trigger skill. Gate **enforcement** did not move — the `PreToolUse` plan-review hook (`.codex/hooks.json`, `hook-wrapper-plan-review.sh`, `check-plan-review.sh`) is untouched, pinned by a test. The installer template is deliberately left heavy: this host installs by **replay**, so the template is an *input to the chain* and migrations `0007`/`0008`/`0010` read their sections out of it — slimming it would break their replay and regress the D-06 defect `0010` exists to heal. **Citation reconciled:** `implements_spec` had been stale at 0.4.0 while the repo already satisfied 0.5.0 (§02 plan-review), 0.7.0 (§15), 0.8.0 (§04) and 0.9.0 (§08, by replay). The one real gap was **§14 (0.6.0) — a *declaration* gap**: no LLM prompt-building surface exists, but §09 requires the host to say so, and it never had. Migration step 5 refuses to advance the claim unless the declaration landed first. Only the trigger skill's `implements_spec` moves; gate/GSD-entry/lifecycle skills keep `0.4.0` because they cite a gate contract, not the host claim (pinned by a test). Suite 453 → 468 PASS. Native Codex skill re-author of the gate stack (1 trigger + 14 gate + 5 GSD entry-points + 2 lifecycle = 22 skills). v0.2.0 absorbs the 0.2.0→0.4.0 deltas: §11 Coding Discipline (verbatim in `AGENTS.md` behind a provenance anchor), §13 declare-first TS (`codex-ts-declare-first`, strengthens the `tdd` gate), §12 surgical Mermaid, and §10 observability **delegated** to the standalone `agenticapps-observability` skill (consumed via its Codex install surface — a *satisfied* §10 MUST per §09, not a delta; migration `0003`). Migration chain `0000`–`0004`. 8 spec/02 gates remain documented Spec Deltas in `docs/ENFORCEMENT-PLAN.md` (triggers cannot occur in a UI-less/DB-less scaffolder) — full conformance preserved per spec/09. |
| [opencode-workflow](https://github.com/agenticapps-eu/opencode-workflow) | Workflow scaffolder for opencode | 0.10.0 | `full` | Forked from `codex-workflow`, then **rebound to upstream rather than re-ported**: GSD and Superpowers are consumed as upstream skills instead of re-authored as `opencode-*` copies, so the stack is 11 skills (1 trigger + 8 gate + 2 lifecycle) against codex's 22, and gates bind `superpowers:*` directly. §11 Coding Discipline verbatim in `AGENTS.md` behind a provenance anchor; §13 declare-first TS (`opencode-ts-declare-first`, strengthens the `tdd` gate); §10 observability **delegated** to the standalone `agenticapps-observability` skill (a *satisfied* §10 MUST per §09, not a delta; migration `0003`, ADR-0005). Installs from a **snapshot, not a migration replay** (ADR-0007) — `check-snapshot-parity.sh` keeps snapshot ≡ chain end-state. Migration chain `0000`–`0006`. Spec deltas documented in `docs/ENFORCEMENT-PLAN.md` — full conformance preserved per spec/09. Adopted **0.10.0** at scaffolder v0.6.0 (migration `0010`): §12's instruction-surface economy SHOULD — `AGENTS.md` slimmed 250 → 129 lines to the §11 block plus a trigger-skill pointer and a session-handoff pointer, with the §02 gate table, task-size routing, the session-handoff protocol and the §15 ritual tail moved into the lazily-loaded `skills/agentic-apps-workflow/SKILL.md`. Enforcement unmoved (`.planning/config.json`, CI, parity guard untouched); §11 bytes unchanged. Earlier, absorbed 0.4.0 → **0.9.1** at scaffolder v0.4.0 (migration `0007`): §02 `plan-review` bound to the upstream `/gsd-review` command; §14 declared *trivially conformant* (builds no LLM prompts from non-self-authored values — trigger cannot occur, §09 requires only that the host say so; downstream delegated to `injection-guard`); §08's guard named in the instruction file per v0.9.0. §15 shipped earlier at v0.3.0 (`0005`, ADR-0008). Note the §08 history: this host's guarded-snapshot install was non-conformant under pre-0.9.0 §08 for as long as it cited 0.4.0 — the v0.9.0 amendment (written citing this host and claude-workflow) is what made the strategy legitimate, so absorbing *retired* a violation rather than adding obligations. |
| [pi-agentic-apps-workflow](https://github.com/agenticapps-eu/pi-agentic-apps-workflow) | Workflow scaffolder for pi.dev | 0.10.0 | `full` | **Revived at host v0.2.0** after being retired in [ADR-0019](../adrs/0019-drift-report-prose-set-scoping.md) — see *Retired hosts* below for why it was removed and what changed. §01/§03/§04/§05 were already verbatim in `skills/agentic-apps-workflow/SKILL.md` (12/12 canonical phrases); the revival added **§11**, vendored at `templates/spec-mirrors/11-coding-discipline-0.4.0.md` byte-identical to codex's and opencode's mirrors and injected into a new `AGENTS.md` behind a provenance anchor, plus the `implements_spec: 0.10.0` citation the host had never carried. **Built to §12's instruction-surface economy rather than migrated to it** — `templates/pi-md-sections.md` went 179 lines → the §11 block plus a trigger-skill pointer and a session-handoff pointer, in the same change that gave it a §11 block; baseline migration `0000` steps 5–6 rewritten accordingly (`to_version` 0.1.4 → 0.2.0), with step 5 asserting §11 byte-identity and a single anchor and refusing a hand-pasted §11 that carries none. `partial` rather than `full`, with deltas named per §09 in the skill's *Spec deltas* section: §10 observability unsatisfied, §14 undeclared (likely trivially conformant but unaudited, so not assumed away), §15 unwired, §02 `plan-review` unbound, and the session handoff not host-scoped (it collides with the Claude host's root `session-handoff.md`). **Host v0.3.0 (PR #4) rebound the discipline layer to upstream**, the same move opencode made: `obra/superpowers` v6.1.1 supports pi natively, so the stale `pi-superpowers-plus` port (npm 0.4.1, a ~v3-era snapshot) is dropped for `pi install git:github.com/obra/superpowers` — a git install, hence deliberately absent from `depends_on`, with the command and its verify carried in the migrations' `requires:` blocks. `pi-gsd` and `pi-gstack` stay ports because their upstreams (`gsd-build/get-shit-done`, `garrytan/gstack`) are still Claude-first; the design gate binds to **impeccable** and the DB gate to **database-sentinel** natively, retiring migration `0001`'s plan to author `pi-impeccable`/`pi-database-sentinel` ports that were never needed. The rebind's non-obvious finding, verified by reading upstream's pi extension rather than its description: **upstream ships no subagent, plan-tracker, or workflow-monitor on pi** — the extension only registers the skills dir and injects the `using-superpowers` bootstrap ("Subagent and task-list tools remain optional Pi companion packages"). Since `pi-superpowers-plus` had bundled all three, the rebind adopts `pi-subagents` for the `subagent` tool and ships `implementer`/`spec-reviewer`/`code-reviewer` in the host's own `agents/`, **inverting** the pre-flight guard that previously refused to install alongside `pi-subagents`. This *adds* deltas rather than closing any: **enforcement is observe-only** (pi has no native blocking hook — the host's watcher logs, it does not block), **plan tracking** and **runtime workflow monitoring** are lost with no upstream replacement, and the browser-dependent gates (`qa`, `ui-preview`, `design-shotgun`) stay unbound. Every gate claim is evidenced in migration `0002`'s Notes from a real pi 0.71.1 run — upstream install, all six discipline skills resolving, two-stage review catching distinct defect classes, and TDD RED/GREEN verified independently of the agent's self-report. **Host v0.4.0 (PR #7) closed three of the deltas above** — the first net reduction since the revival. §15 knowledge capture is wired at all three ritual triggers (handoff, plan, phase) with the destination read from a `knowledge_capture` block in the shared, host-neutral `.planning/config.json` (`config-knowledge-capture.json` byte-identical to codex's and opencode's; note template differs only in `hosts: [pi]`), placed in the trigger skill from the start rather than in `AGENTS.md` — the post-0.10.0 shape both siblings migrated *to*, adopted here without the round trip. §02 `plan-review` is bound to `/gsd-review {N}` with `<NN>-REVIEWS.md` evidence, plus codex's `check-plan-review.sh` **ported** (a standalone `{0,2}` CLI with no dependency on codex's hook engine), giving a real implementation of §02's resolution order and grandfather rule; the self-review exclusion was re-anchored from `^codex$` to `^pi$`, which makes codex a valid external reviewer here — verified as behaviour (`[pi, claude]` blocks, `[codex, claude]` allows). The session handoff is host-scoped to `.pi/session-handoff.md`, matching `.codex/`/`.opencode/`, with migration `0003` moving an existing root file only when it is this host's and leaving the Claude host's in place. **Honestly scoped**: §02 splits into a MUST (bind) and a SHOULD (enforce programmatically); the MUST is met, the SHOULD only partly — the verifier is agent-invoked, not runtime-interposed, because pi has no native blocking hook, and the skill/ADR/migration all say so rather than claiming codex-style enforcement. That leaves **seven** deltas: §10 observability, §14 prompt-injection (declaration gap), observe-only enforcement, lost plan tracking, lost workflow monitoring, unbound browser gates, conditional DB gates. Migration harness `migrations/run-tests.sh` (added host v0.3.0, PR #5) passes **95/0** across the `0.1.4 → 0.4.0` chain. **Host v0.5.0 (PR #8) re-scoped the delta list to what §09 actually treats as a delta**: those "seven" were mostly not deltas. §10 observability is *satisfied by delegation* to the standalone `agenticapps-observability` skill (a host-neutral `SKILL.md` consumed natively like `impeccable`/`database-sentinel`, documented not fail-closed — opencode's lighter model); §14 is *trivially conformant* (no LLM prompt-building surface, declared per §09); observe-only enforcement is an §09-*allowed extension* not a gap (line 126); lost plan-tracking/workflow-monitoring were never §09 obligations (ADR-0001); browser and DB gates are *trigger-cannot-occur* omissions §09 says do not downgrade (the basis opencode lists its UI-less gates under `full`). That left **one** genuine, §09-sanctioned delta — §13 declare-first, omittable for a language-neutral host (ADR-0003). **Host v0.6.0 (PR #9) bound §13 and reached `full`** — the operator confirmed pi is used for TypeScript projects, settling §13's applicability. `pi-ts-declare-first` (the Pi copy of the canonical §13 skill, host-neutral body + Pi-adapted frontmatter/invocation) ships **in the package's `skills/` dir, auto-discovered from the manifest** — no npm, no port, and unlike the siblings' global skill dirs no per-project symlink; discovery verified live via `pi -e .`. Bound to the `tdd` gate as a `strengthened_by` layer (`declare(ts):`→`test(ts):`→`feat(ts):`), alongside not over the base TDD binding (migration `0005`; post-check asserts both survive). ADR-0004 records the trade-off plainly: this *reverses* v0.5.0's minimal-host framing by adding a TS-specific gate, accepted because the premise changed. `full` is honest per §09 — canonical prose verbatim, every applicable declarative MUST satisfied (directly, by delegation, or trivially), every occurrable gate bound; the residual omissions are all §09-compatible with `full`, same as opencode. Harness **134/0** across the `0.1.4 → 0.6.0` chain. Scored by `tools/drift-report.sh` again as of this change: **15/15 OK**. |
| [agenticapps-dashboard](https://github.com/agenticapps-eu/agenticapps-dashboard) | Workflow artifact viewer | 0.1.0 (target — adoption pending) | TBD (consumer) | Reads workflow artifacts produced by hosts; does not author them. |

## Retired hosts

- **pi-agentic-apps-workflow** (workflow scaffolder for pi.dev) — retired
  2026-07-15, **un-retired 2026-07-19**; it is listed in the active table above
  again. It had been listed as "0.1.0 (target — adoption pending)"; adoption was
  never pursued, it carried `implements_spec` in no file (per §09 item 4 it
  therefore never held a conformance claim to withdraw), and it shipped no §11
  block, so the row was removed rather than left as a permanent pending claim
  (ADR-0019). Both defects were fixed at host v0.2.0 — the `implements_spec`
  citation and the §11 canonical block — which is what makes a row possible
  again. The removal from `tools/drift-report.sh` still stands for now; see
  below.

## Which repos the drift report checks

`tools/drift-report.sh` scores only the rows above that **author** canonical
prose: claude-workflow, codex-workflow, opencode-workflow, and — as of
2026-07-19 — pi-agentic-apps-workflow. The
agenticapps-dashboard row is a consumer — it reads workflow artifacts and
authors none — so canonical-prose checks do not apply to it and it is not
scored. See ADR-0019.

## Conformance levels

See section 09 of the spec for the normative definitions.

- **`full`** — every canonical-prose block reproduced verbatim, every
  declarative-contract MUST satisfied.
- **`partial`** — most requirements satisfied; deltas listed in the
  host's own instruction file.
- **`consumer-only`** — reads workflow artifacts; does not author them.

## Adopting the spec

Each host opens its own PR titled "Adopt agenticapps-workflow-core
spec v0.1.0" with its own GSD phase plan. The follow-up issues filed
when v0.1.0 ships are the prompt for that work; this repo does not
do the adoption.

When a host completes adoption, the corresponding row above moves
from "TBD" to `full`, `partial`, or `consumer-only`.
