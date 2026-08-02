# Deletion record — the five hooks

Produced at implementation for tasks 5.0, 5.0a, 5.0a-i, 5.0b, 5.0c, 5.0c-i and
5.0d. Measured on this machine on 2026-08-02 across all eleven repos in the two
families (the seven hook-carrying projects, `agenticapps-workflow-core`,
`claude-workflow`, `codex-workflow`, `pi-agentic-apps-workflow`).

**Three separate tests, run against every applicable specification.** A hook
clears only if it fails all three. Filename absence is not an argument in either
direction — §02 makes a gate's binding host-specific data in the host
instruction file, so a hook named after nothing in §02 could still be a gate's
binding, and one named after a gate need not be.

1. **Binding** — is this hook the documented binding of any gate?
2. **Production** — does it write any gate's required evidence artifact?
3. **Enforcement** — does it make any gate harder to pass *by any means*: a
   proxy (sentinel, marker, naming convention), a result from elsewhere (exit
   status, API response, CI verdict), or any condition standing in for the gate
   being satisfied?

Clause 3 is the broadened one, and it matters: **a sentinel is a proxy, so
gating on one *is* enforcement.** That reverses the argument for one of the five
— see `design-shotgun-gate` below.

## Scope of the specification check (task 5.0b)

A §02-only test could authorise deleting a hook that §17, §18, a capability spec
or a project's own policy depends on. Checked: **§02, §17, §18, and every
capability spec under `openspec/specs/`** — `change-gate-enforcement`,
`conformance-harness-reporting`, `core-self-enforcement`,
`plan-review-production`.

```
$ grep -rl "<hook>" spec/ openspec/specs/
architecture-audit-check   — not named in any spec
design-shotgun-gate        — not named in any spec
phase-sentinel             — not named in any spec
session-bootstrap          — not named in any spec
skill-router-log           — not named in any spec
```

Absence from the spec text is clause 1's *starting point*, not its conclusion.
Each hook is checked below against what the host instruction file actually binds
for the gates it could plausibly serve.

## The §02 gates whose bindings could plausibly be one of these hooks

| §02 gate | Documented binding (host instruction file) | Required evidence |
|---|---|---|
| `brainstorm-ui` | `superpowers:brainstorming` | ≥2 UI alternatives in CONTEXT.md |
| `brainstorm-architecture` | `superpowers:brainstorming` | ≥2 architectural alternatives |
| `design-shotgun` | gstack `/design-shotgun` | ≥3 rendered variants referenced from CONTEXT.md / UI-SPEC.md |
| `design-critique` | `impeccable:critique` | a critique document |
| `plan-review` | `run-plan-review.sh` + the programmatic gate | `REVIEWS.md` |

Every binding is a **skill or script named in the host instruction file**. None
of the five hooks appears in that map, and none writes any of the evidence
above.

---

## `phase-sentinel.sh`

- **Binding** — no. `Stop` event, no gate binds it.
- **Production** — no. Writes nothing.
- **Enforcement** — no. Gates on `.planning/current-phase/checklist.md`, which
  exists in **no repo in either family** (verified: `checklist.md=no` in all
  seven). Permanently inert; it cannot make any gate harder to pass because it
  never fires a decision.
- **Consumers** — `.claude/settings.json` in all seven. Nothing else in the
  fleet.

**Cleared.**

## `architecture-audit-check.sh`

- **Binding** — no. `SessionStart`, no gate binds it.
- **Production** — no.
- **Enforcement** — no. Reads `.planning/audits/`, which exists in **no repo in
  either family** (verified: `audits-dir=no` in all seven). Permanently inert.
- **Consumers** — `.claude/settings.json` in all seven; `claude-workflow`'s
  templates, snapshot and migration 0004. Nothing reads its output because it
  produces none.

**Cleared.**

## `design-shotgun-gate.sh` — re-argued on unreachability (task 5.0a-i)

**The old argument no longer clears it, and would now convict it.** That
argument was "the sentinel it checks is not §02's required evidence for the
`design-shotgun` gate, so it was never that gate's enforcement". Under the
broadened clause 3 a sentinel *is* a proxy and gating on one *is* enforcement,
so that reasoning now argues for keeping the hook.

- **Binding** — no. §02's `design-shotgun` gate binds the gstack
  `/design-shotgun` **skill**, per the host instruction file. This
  `PreToolUse` hook merely shares the name.
- **Production** — no. It writes no rendered variants and no CONTEXT.md.
- **Enforcement** — **it gates on a proxy, and the proxy is unreachable.** It
  fails *closed* against `.planning/current-phase/design-shotgun-passed`, a
  sentinel only GSD-era preflight ever wrote. GSD was removed 2026-07-28, so no
  surviving tool can write it. The check can therefore never *pass*: it does not
  enforce a gate, it blocks unconditionally wherever the stale file is absent.

**That is what clears it — unreachability, not evidence-mismatch.**

Measured: five repos still hold a leftover `design-shotgun-passed` file and are
unaffected; **`callbot` and `fbc-platform` do not**, so in those two every
`Edit`/`Write` to a `.tsx` or `.css` file is blocked at the tool boundary today,
and the remedy the hook prints names a command that no longer exists.

`agenticapps-dashboard` already deleted this file itself on 2026-08-01 (its PR
#88, "it blocks every fresh clone") — this change's argument, made
independently by someone else.

**Confirmed: no other deletion here rests on the superseded argument.** The
other four are cleared on inertness or on policy, not on evidence-mismatch.

**Cleared, on unreachability.**

## `skill-router-log.sh`

- **Binding** — no.
- **Production** — no gate's evidence. It writes session telemetry.
- **Enforcement** — no. It observes and appends; no code path returns a
  blocking exit.
- **Policy** — it writes into `.planning/`, which this fleet's own policy
  designates frozen archive, "never write to them".

**Cleared.**

## `session-bootstrap.sh`

- **Binding / Production / Enforcement** — no, no, no. It reads telemetry back
  into session context at `SessionStart`.

**Cleared.**

---

## Transitive consumers (task 5.0c) — and a refuted claim (task 5.0c-i)

The proposal said `session-bootstrap` "is the only consumer *known*" of
`skill-router-*.jsonl`, and flagged that this was inferred from proximity rather
than from a search — the same move this change indicts elsewhere. The search was
run. **The claim is wrong as stated, and the conclusion survives for a different
reason.**

### The search

```
grep -rl 'skill-router-'     <11 repos>   # the log filename prefix
grep -rl 'skill-observations' <11 repos>  # the directory
```

Within the seven projects, `skill-router-` appears only in `.claude/settings.json`,
`skill-router-log.sh` and `session-bootstrap.sh`. So far, the claim holds.

### The second reader

`skill-observations` surfaced an entire product surface in
**`agenticapps-dashboard`** that the prefix search could not see:
`packages/agent/src/lib/phaseDetail.ts`, `packages/shared/src/schemas/observations.ts`,
`packages/spa/src/components/panels/HookFirings.tsx`, and
`openspec/specs/filesystem-access-policy/spec.md`.

`readSkillObservations()` globs **`.planning/skill-observations/*.jsonl`** — all
`.jsonl` files in the directory, which *includes* `skill-router-<date>.jsonl`.
So the dashboard **is** a second reader of those files. "The only consumer is
`session-bootstrap`" is false about readers.

### Why the conclusion survives anyway

It is a reader of the files but **not a consumer of the data**:

```ts
export const HookFiringSchema = z.object({
  ts: z.string(), skill: z.string(), hook: z.string(),   // `hook` REQUIRED
}).passthrough()
```

```sh
jq -nc --arg ts "$TS" --arg skill "$SKILL" --arg phase "$PHASE" --arg tool "$TOOL" \
  '{ts: $ts, skill: $skill, phase: $phase, tool: $tool}' >> "$LOG_FILE"
```

`skill-router-log` writes `{ts, skill, phase, tool}` and **never writes `hook`**,
so every record it produces fails `HookFiringSchema` and is discarded. The
`HookFirings` panel displays `meta-observer`'s records only.

**Therefore:** deleting the producer removes nothing the dashboard displays, and
the decision not to relocate the feature stands — now on evidence rather than on
proximity. Had the schema accepted these records, the panel would have silently
lost rows in six repos.

### Consumers that DO break

| Consumer | Hook(s) | What happens |
|---|---|---|
| each project's `.claude/settings.json` | all five | the registration is removed in the same edit |
| `claude-workflow/bin/check-hooks.sh` | 4 of 5 | **not in the task list — see below** |
| `claude-workflow/templates/claude-settings.json` | all five | **not in the task list — see below** |
| `claude-workflow/tests/hooks/*.bats` | 2 of 5 | task 4.10 removes them |
| `claude-workflow/migrations/00{04,22,23,26,27}` + fixtures | various | historical replay; `check-snapshot-parity.sh` (4c.4) is the guard |

## Waived project dependencies (task 5.0d)

None found. No repo depends on one of the five in a way the fleet does not
require: the two inert hooks produce nothing to depend on, the telemetry pair's
only in-fleet data consumer discards their records, and `design-shotgun-gate`'s
sentinel is unwritable.

`agents-task-viewer`'s `normalize-claude-md` opt-out **is** such a dependency,
but on a *surviving* hook, and it is preserved by shipping that repo no file at
all (task 4.3).

## Gaps this record found in the task list

Two `claude-workflow` files reference the deleted hooks and are named in no
task. Section 4c covers `templates/.claude/hooks/`, `setup/snapshot/hooks/` and
`setup/snapshot/claude-settings.json` — but not:

- **`claude-workflow/bin/check-hooks.sh`** — references `design-shotgun-gate`,
  `phase-sentinel`, `session-bootstrap` and `skill-router-log`. A checker that
  looks for hooks this change deletes will report every conformant project as
  broken.
- **`claude-workflow/templates/claude-settings.json`** — a *second* settings
  template beside `setup/snapshot/claude-settings.json`, carrying the same five
  registrations and the pre-change matcher.

Both are added to `tasks.md` as 4c.7 and 4c.8.

---

# Baseline: does the existing matcher fire today? (task 4.8a)

**Yes. Measured, not assumed.** 2026-08-02, Claude Code 2.1.220.

A headless session was driven against a scratch project carrying the
**unmodified** `Bash|Edit|Write` matcher and the **unmodified**
`database-sentinel.sh` from `agenticapps-dashboard`, and asked to `Write` a
`.env` file.

```
The write was **blocked** by a PreToolUse hook, which reported:
`❌ Database Sentinel: blocked edit to env file … env files contain secrets`
```

The file was unchanged afterwards.

This settles what round-8 opencode's objection left open. That objection
inferred from this design's markdown-escaped table that the on-disk matcher
might be `Bash\|Edit\|Write` and therefore inert everywhere; the escaping is the
document's and the JSON holds real pipes, which refuted the *syntax* premise
only. A well-formed matcher is not a firing hook, and every statement that
unprovisioned machines "lose" protection presumed a baseline nobody had
measured.

**The baseline is real: the control runs today, and blocks.** So the fail-open
cost analysis is about a live control, and the proposal's behaviour-change list
needs no correction on this point.
