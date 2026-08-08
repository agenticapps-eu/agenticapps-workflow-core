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
| omp | `~/.omp/agent/skills` | `~/.agents/commands` | **its own source names both** — see below |

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
and not symlink-bindable** — after the omp finding below, the only host left in
that state. Reaching it would mean publishing a pi package, which is a different
mechanism and a separate decision.

*Aside, out of scope:* that packages list still names
`git:github.com/agenticapps-eu/pi-agentic-apps-workflow`, an archived repository.

**codex has a machine-level prompt directory but nothing to put in it.**
`~/.codex/prompts` is real and populated, yet `openspec init --tools codex`
generates no command files at all. The absence is on the *generator* side, not
the host side — which is why §9.5 records it rather than reporting a partial
install. Worth keeping distinct from pi's case: codex could be bound if the CLI
ever emitted codex commands; pi could not, without a package.

## omp is establishable after all, and this repeals "unverified"

Measured 2026-08-07 from `@oh-my-pi/pi-coding-agent`'s own `dist/cli.js`. Two
strings settle it:

```
NEVER edit user-authored skills under ~/.omp/agent/skills or .omp/skills
Load commands from .agent/commands and .agents/commands (project walk-up + user home)
```

That is evidence about what the host loads, from the host, which is exactly what
the evidence requirement asks for — not a directory's existence, and not
symmetry with pi. The earlier "unverified" verdict came from looking only for a
directory: `~/.omp/agent/skills` did not exist, so nothing was concluded. Absence
of a directory was treated as absence of evidence, when the evidence was in the
binary the whole time.

Two consequences:

**omp was never mis-bound.** It also loads `.agents/skills` from user home, so
`omp:.agents/skills` — the mapping this change was preparing to call unverified —
is correct, and `~/.agents/skills/agentic-apps-workflow` has been resolving for
omp since 6 August. Only pi was wrong about that directory. The two hosts shared
a mapping and only one of them was a defect.

**omp reads other hosts' command directories too** — `~/.claude/commands`,
`~/.config/opencode/commands`, `~/.codex/prompts`. So it would inherit opsx from
whichever neighbour happened to be installed. It is bound into `~/.agents/commands`
regardless, because a host that works only when a *different* host is also
present is not bound, it is lucky.

The CLI's tool name for it is `oh-my-pi`, not `omp`, and it writes `.omp/`.

## Consequence

§9 binds skills for five hosts, and commands for **three** — claude, opencode and omp.
codex is recorded as having nothing to bind, and **pi alone** is left unverified.
Any implementation that binds five hosts uniformly is wrong on two of them.

Four distinct outcomes across five hosts, and no two hosts alike: one nested
directory link, two flat file sets at different paths, one host with a real
directory and nothing to put in it, one host reachable only through a package
system. That is the argument for measuring — a uniform binder would have looked
correct and silently done nothing for pi and codex.
