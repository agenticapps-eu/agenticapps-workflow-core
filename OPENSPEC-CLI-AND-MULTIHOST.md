# OpenSpec CLI reality + OPSX workflow + going multi-host / agent-agnostic

Written after the cParx pilot (2026-07-24) surfaced that OpenSpec has moved on from
what the first prompts assumed, and to answer "make it opencode + pi too, ideally
agent-agnostic." Supersedes the CLI/command specifics in prompts 00–03 where they differ.

## 0. Pilot verdict (for the record)

**Pass.** OBS-04 went propose → validate → multi-AI review → TDD → archive → ship in
~30 min in the throwaway worktree. The review **earned its keep on the first real
change**: Codex's reviewer (REQUEST-CHANGES) caught a genuine semantic defect in the
spec — the `model` field is wrong on the *fallback* paths (where the rule, not a model,
produces `general`) — and it was fixed *before any code was written*. That is exactly
the ADR-0018 value, now on OpenSpec. `archive ≠ ship` confirmed; the gate blocked
pre-review and allowed post-review. Keep going.

## 1. The current OpenSpec CLI (what actually exists now)

OpenSpec is now a **CLI-driven, schema-based** tool. Corrections vs the early prompts:

| Early prompt assumed | Reality now |
|---|---|
| `openspec init` | `openspec init --tools claude,codex,opencode,pi` (name your agents) |
| `project.md` for context | project context lives in `openspec/config.yaml` under `context:` (write `project.md` too if you like, but `config.yaml context:` is what the tool surfaces) |
| `/opsx:propose` only | a real CLI verb set: `openspec new change <name>`, `openspec validate --all`, `openspec show`, `openspec archive <name> -y`, `openspec update` |
| `spec …` subcommands | **deprecated** in favour of verb-first `validate` / `show` |
| — | each change is scaffolded with its own `.openspec.yaml`; artifacts are `proposal.md` + `design.md` + spec delta + `tasks.md` |

Rule going forward: **run `openspec --help` in the repo and use the installed verbs.**
The migration *concept* (specs/ + changes/ + archive, delta folded on archive) is
unchanged — only the command surface moved.

## 2. OPSX — the "new workflow" you saw, and what to adopt

OPSX is OpenSpec's new **action-based, non-linear** workflow ("work isn't linear; OPSX
stops pretending it is"). Artifacts + dependencies come from external YAML schemas, so
you can create them individually or update mid-implementation. It ships two **profiles**
(`openspec config profile` → `openspec update`):

- **Core** (default): `/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:archive`.
- **Expanded**: adds `/opsx:new`, `/opsx:continue`, `/opsx:ff`, `/opsx:verify`,
  `/opsx:sync`, `/opsx:bulk-archive`, `/opsx:onboard`.

**Recommendation: adopt OPSX on the Core profile.** It maps 1:1 onto our loop and keeps
things simple, which is your stated goal:

| Our loop step | OPSX core |
|---|---|
| (optional) ideate an open-ended change | `/opsx:explore` |
| 1 · propose (proposal + spec delta + tasks) | `/opsx:propose` |
| 2 · validate | `openspec validate --all` |
| 2b · plan-review (multi-AI) | our gate — **not** an opsx command |
| 3 · build | `/opsx:apply` + Superpowers (TDD etc.) |
| 4–5 · code-review + verification | Superpowers (authority; skip `/opsx:verify`) |
| 6 · archive (fold delta → specs) | `/opsx:archive` |
| 7 · ship | our thin ship step — **not** an opsx command |

Skip the Expanded profile for now: `/opsx:verify` overlaps Superpowers'
verification-before-completion (keep Superpowers as the authority), and `/opsx:ff` /
`continue` add surface you don't need at "simple but effective." Revisit later if a
change type wants finer-grained artifact control.

## 3. Multi-host: opencode + pi are first-class — it was a one-flag miss

OpenSpec supports **28 tools**, and **all four of your hosts are on the list**: `claude`,
`codex`, `opencode`, `pi` (also cursor, gemini-cli, copilot, …). The pilot only said
"claude and codex" because it ran `openspec init --tools claude,codex`. The fix is
literally to name all four:

```bash
openspec init   --tools claude,codex,opencode,pi     # fresh
openspec update --tools claude,codex,opencode,pi     # existing repo
```

OpenSpec then generates each tool's own command files (e.g. `.claude/commands/opsx/…`,
and the opencode / pi equivalents). No per-host re-authoring.

## 4. Agent-agnostic architecture — your goal, and how close it is

Your goal ("install the workflow globally, repo-specific parts in the repo, any agent
can work with it") is **mostly reachable today**, because the workflow's core is already
three agent-agnostic primitives:

1. **The `openspec` CLI** — one global binary; every agent and every human runs the same
   verbs. `npm i -g @fission-ai/openspec`.
2. **The spec files** — `openspec/specs/` + `changes/` are plain markdown. Any agent
   reads them; nothing is agent-specific.
3. **The gate as a shell script** — the pilot proved the enforcement lives in a
   host-agnostic shell script (`openspec-change-gate.sh`: validate green AND `REVIEWS.md`
   ≥2). Install it **globally** (e.g. `~/.agenticapps/bin/openspec-change-gate.sh`); every
   repo/agent points at the same script.

Only two things are genuinely per-agent, and both are thin:

| Per-agent layer | How to handle |
|---|---|
| **Slash-command sugar** (`/opsx:*`) | OpenSpec generates it for all 28 tools incl. your four — `--tools`. An *unsupported* agent simply uses the CLI verbs + AGENTS.md; it loses the shortcut, not the workflow. |
| **Hook wiring** (fires the gate before an edit) | Each agent has a different surface — claude `settings.json` hooks · codex `.codex/hooks.json` · opencode plugin/hook · pi hook. All point at the **one global gate script**. opencode/pi hook surfaces are **unconfirmed** — verify during their host step. |

### The truly agnostic enforcement: a git/CI backstop
The per-agent PreToolUse hook can't even gate its own installing session (pilot friction
#2). So put the same gate script in a **git `pre-commit` hook + CI check**. That enforces
"no change lands without validate + ≥2 reviews" **regardless of which agent — or human —
made the edit.** This is the agent-agnostic enforcement floor; the per-agent hooks are
just faster feedback on top. Recommend: ship the gate as CI/pre-commit first (agnostic,
reliable), add per-agent hooks as a convenience.

### So the split you wanted is:
- **Global (once, agnostic):** the `openspec` CLI · the gate shell script · the multi-AI
  reviewer wrapper (with the `codex exec … </dev/null` fix from pilot friction #3) · the
  discipline prose as a shared AGENTS.md snippet / skill.
- **Repo-specific:** `openspec/` (specs, changes, `config.yaml context:`) · the per-tool
  command files from `--tools …` · the CI/pre-commit gate wiring · per-agent hook wiring
  for whichever agents that repo uses.

"Any agent works" = true today via CLI + files + AGENTS.md; the `/opsx:*` slash sugar is
a per-tool nicety OpenSpec already ships for your four hosts.

## 5. Corrections to apply to the packet prompts

- Everywhere: `openspec init/update` → add `--tools claude,codex,opencode,pi`.
- Context file: `openspec/config.yaml` `context:` (keep `project.md` optional).
- Commands: `openspec new change <name>`, `validate --all`, `show`, `archive <name> -y`;
  drop deprecated `spec …`.
- Adopt OPSX **Core** profile (`openspec config profile` → `update`).
- Gate: author as the **global host-agnostic shell script** + **CI/pre-commit backstop**;
  per-agent hooks (claude/codex/opencode/pi) are thin wiring on top. Add the reviewer
  wrapper that pipes `</dev/null` and time-limits a hanging reviewer CLI.
- Host prompt (01): run for all four hosts; confirm opencode + pi hook surfaces (unknown).
