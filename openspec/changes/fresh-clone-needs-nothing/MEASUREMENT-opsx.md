# Where the openspec tooling can actually be bound, per host

Measured 2026-08-07 on this machine, before implementing §9. The point of
measuring rather than reasoning: this change's own new requirement says a host's
directory is established by evidence, and §9 would otherwise be five guesses
derived from one host's layout.

## What `openspec init --tools <host>` writes into a repository

Six skills for every host, at `<host>/skills/openspec-*/SKILL.md`. The command
surface is not uniform:

| host | command surface written into the repo |
|---|---|
| claude | `.claude/commands/opsx/*.md` — nested directory, six files |
| codex | **none** — skills only |
| opencode | `.opencode/commands/opsx-*.md` — flat, hyphenated, six files |
| pi | `.pi/prompts/opsx-*.md` — *prompts*, not commands, six files |

## What exists machine-level, and what establishes it

| host | skills | commands | how it was established |
|---|---|---|---|
| claude | `~/.claude/skills` | `~/.claude/commands` | `aristotle.md` is a symlink into `dotclaude/`, and `/aristotle` resolves in a live session — resolution, not presence |
| codex | `~/.codex/skills` | `~/.codex/prompts` | populated with `gsd-*.md` since 1 July |
| opencode | `~/.config/opencode/skills` | `~/.config/opencode/commands` | populated with symlinks into `opencode-workflow/` |
| pi | `~/.pi/agent/skills` | **none — see below** | 25 per-skill symlinks, 16 July |
| omp | **unverified** | **unverified** | `~/.omp/agent` does not exist at all |

## The two findings that change §9

**pi has no bindable command directory, and inventing one would repeat the
mapping defect this change exists to fix.** There is no `~/.pi/agent/prompts`,
no `~/.pi/prompts`, and no prompt or command path named in
`~/.pi/agent/settings.json`. What pi has instead is a package system:

```json
"packages": ["npm:pi-gsd", "npm:pi-gstack",
             "git:github.com/agenticapps-eu/pi-agentic-apps-workflow",
             "git:github.com/obra/superpowers", "npm:pi-subagents"]
```

`~/.pi/gsd/prompts` exists, but it belongs to the `pi-gsd` package rather than
being a directory pi reads globally. So pi's opsx command surface is **unverified
and not symlink-bindable**, the same state omp's skill directory is in. Reaching
it would mean publishing a pi package, which is a different mechanism and a
separate decision.

*Aside, out of scope:* that packages list still names
`git:github.com/agenticapps-eu/pi-agentic-apps-workflow`, an archived repository.

**codex has a machine-level prompt directory but nothing to put in it.**
`~/.codex/prompts` is real and populated, yet `openspec init --tools codex`
generates no command files at all. The absence is on the *generator* side, not
the host side — which is why §9.5 records it rather than reporting a partial
install. Worth keeping distinct from pi's case: codex could be bound if the CLI
ever emitted codex commands; pi could not, without a package.

## Consequence

§9 binds skills for four hosts, and commands for **two** — claude and opencode.
codex is recorded as having nothing to bind; pi and omp are recorded unverified.
Any implementation that binds five hosts uniformly is wrong on three of them.
