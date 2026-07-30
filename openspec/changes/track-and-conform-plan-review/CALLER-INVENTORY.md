# Producer caller inventory — task 5.8

Taken 2026-07-30, before publishing producer 1.1.0. Removing the
`AGENT_SELF:-claude` default is a breaking interface change; this establishes
what it breaks.

Searched: core, `~/.agenticapps/bin/`, the four hosts, the seven hook-carrying
projects, and the `agenticapps-workflow` skill.

## Result: no executable caller exists

**Nothing in the fleet scripts an invocation of `run-plan-review.sh`.** Every
reference is one of three documentation shapes:

| Shape | Example | Sites |
|---|---|---|
| Install/echo line | `install -m 0755 … ~/.agenticapps/bin/` · `echo " GATE $AA_BIN/run-plan-review.sh"` | `claude-workflow/install.sh:150`, skill `install.sh:150`, `gate/README.md:21`, `gate/hooks/wiring.md:8` |
| Diagram line stating usage | `run-plan-review.sh {slug} -> REVIEWS.md (>= 2 reviewers)` | `workflow-config.md:86` in claude-workflow (template + snapshot), the skill (template + snapshot), and six projects' `.claude/` copies |
| Descriptive JSON string | `"producer": "bin/run-plan-review.sh (installed to ~/.agenticapps/bin/)"` | `planning-config.json` in claude-workflow, the skill, and seven projects' `.planning/` |

The producer is invoked **interactively** — by an operator or an agent typing
the command — and by the workflow skill's prose instructing that command. There
is no wrapper script, no CI step, and no hook that runs it.

## What that means for the migration

1. **Nothing breaks silently.** The failure mode for an un-migrated invocation
   is a usage error naming the missing input (task 5.9), which is what an
   interactive caller needs. There is no unattended job to fail at 3am.
2. **The migration is documentation**, not code. Every site above states the
   *old* usage, and two of them additionally state the stale `>= 2 reviewers`
   floor. A reader following them writes an invocation that now errors.
3. **Scope is unchanged and the claim is checkable.** A reviewer put it that
   "every producer caller SHALL be migrated in this change" is unsatisfiable
   inside a two-repo scope. It is satisfiable because the set of executable
   callers is empty. Core and `claude-workflow` carry the authoritative text;
   the seven projects hold *copies* refreshed at re-vendor, which is the same
   route by which every other stale line in those files is corrected.

## Sites corrected in this change

- `reference-implementations/run-plan-review/README.md` — usage, floor, env
- `reference-implementations/run-plan-review/run-plan-review.sh` — header usage
- `gate/README.md`, `gate/hooks/wiring.md` — the `gate/` copy is deleted by §9
- `claude-workflow`: `templates/workflow-config.md`,
  `setup/snapshot/workflow-config.md`, `setup/snapshot/planning-config.json`,
  `install.sh`

## Sites deliberately left, and why

The seven projects' `.claude/workflow-config.md` and `.planning/config.json`
are scaffolded copies. They are refreshed when each project re-vendors, and
editing them here would put fourteen files outside the change's stated
two-repo scope for text that the next scaffold overwrites anyway. `.planning/`
is additionally frozen GSD history that must not be written to.

`pi-agentic-apps-workflow` and `codex-workflow` carry no usage-stating line —
verified, not assumed.

## Out-of-repo sites that contradict until re-vendor (task 1.10)

Named, not corrected — they live outside this repo and are refreshed when each
host re-vendors. Listing them means the contradiction is known rather than
discovered:

| Site | What it still says |
|---|---|
| `~/.claude/skills/agenticapps-workflow/SKILL.md` | "≥2 independent other-vendor reviewers" as the gate's floor |
| `~/.claude/CLAUDE.md` (operator's global) | "`REVIEWS.md` carries ≥2 other-vendor reviewers" |
| `claude-workflow` templates + snapshot | `run-plan-review.sh {slug} -> REVIEWS.md (>= 2 reviewers)` |
| seven projects' `.claude/workflow-config.md` | the same diagram line, scaffolded |

The operator's `CLAUDE.md` is the one that matters day to day: it is loaded
every session and states a floor the gate has not enforced since gate 1.4.0.
