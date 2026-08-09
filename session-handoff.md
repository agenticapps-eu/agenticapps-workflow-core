# Session Handoff — 2026-08-09 (twenty-sixth session)

Two PRs merged, `projects-bind-not-copy` closed, three of four working repos
repaired, and the gate skills bound on every host instead of one. The next
session's subject is gstack (AGE-523), and it is already researched.

## Accomplished

- **PR #95 merged** — the project-hook publisher retired. RED first: three
  assertions observed failing (56/3 against a 56/0 baseline) before any
  deletion, 55/0 after. Gone: `database-sentinel.sh`, `ARTIFACTS`,
  `install-project-hooks.sh`, `tools/project-hooks.test.sh`, the `PROJHOOKS`
  wiring, and the machine's `manifest.tsv` (preserved in the change dir).
- **PR #96 merged** — `superpowers` bound from **one checkout** at
  `~/.agenticapps/upstream/superpowers` into every host, replacing a Claude
  plugin no other host could read. codex went from **0/4 gate skills to 4/4**.
- **`projects-bind-not-copy` closed with 34 tasks unticked**, marked
  obsolete-by-measurement rather than done. Groups 2 and 2b lifted to Linear.
- **Three of four working repos were unusable and are fixed.** `callbot` and
  `fx-signal-agent` carried a committed `AGENTS.md → CLAUDE.md → AGENTS.md`
  loop — ELOOP on both names, no instruction file readable by any host, for a
  full day. `fbc-platform` had `CLAUDE.md` only, so codex/pi/omp read nothing.
- **Verified on three hosts** in throwaway `cparx` worktrees, twice: claude,
  codex and omp each activated the skill unprompted and emitted the ritual.

## Decisions

- **The `# shim-contract:` marker was NOT bumped**, against task 3.13f. Byte
  drift is caught by `cmp -s` in `check-shims.sh`, which never reads the marker;
  the spec names four triggers and a header comment is none of them.
- **Bind upstreams from a git checkout, never from a plugin cache.** The cache is
  version-pathed and *keeps* old versions, so a link into `6.2.0` never dangles
  when Claude moves to `6.3.0` — it silently serves stale bytes. All 14 skills
  differ between 6.1.1 and 6.2.0. A binding that never breaks and quietly lies is
  worse than one that breaks.
- **The Claude `superpowers` plugin is uninstalled.** Keeping it would leave
  Claude on a different copy from the other four, which is the problem restated.
- **The `superpowers:` prefix is dropped from the gate table.** It was a fact
  about one host's packaging, never part of a skill's name. **omp found this** —
  it resolved all eleven gates and flagged the lookup it had to correct.
- **`database-sentinel` is two artifacts and only one is gone.** The *hook*
  (`database-sentinel.sh`) is retired. The *skill* (`Farenhytee/database-sentinel`)
  is a live gate and stays. Do not let the shared name collapse them.

## Files modified

- `install.sh` — PROJHOOKS removed; `UPSTREAM` added; `bind_dir` takes two source
  dirs in one loop (216/217 line budget)
- `tools/install.test.sh` — 3.13a's three assertions and 2 upstream-binding
  cases in; 4 publisher cases and 16 stubs out
- `skills/agentic-apps-workflow/SKILL.md` — gate table unprefixed, upstream rule
  generalised
- `reference-implementations/project-hooks/{shim-template.sh,SHIMMED-HOOKS,FLEET,README.md}`
- `docs/HOW-IT-FITS-TOGETHER.md`, `docs/evidence/install-run-after.md`
- `openspec/changes/projects-bind-not-copy/{tasks.md,manifest.tsv.retired}`
- `callbot`, `fx-signal-agent`, `fbc-platform` — instruction files, own commits
- Machine: `~/.agenticapps/upstream/superpowers` cloned; Claude plugin removed

## Next session: start here

**AGE-523 — gstack.** Researched, not started. Three findings: (1) `cso`, `qa`,
`database-sentinel` are Claude-only *copies*, `impeccable` a copy on `~/.agents`;
(2) the twelve `codex-*`/`opencode-*` prefixed variants are **byte-identical** to
the neutral ones — zero diff — which is exactly why codex reports `cso` missing;
(3) `~/.claude/skills/gstack` is a **1.1 GB checkout inside the skills directory**
with 552 `SKILL.md` files and **54 of 54 top-level names colliding** with existing
top-level skills. The fix is PR #96's shape and `bind_dir` already takes a second
source. **Answer the open question first: bind only the four gate skills, or all
54? Recommend four.** The operator asked to discuss this before work starts.

## Open questions

1. **gstack — bind four gate skills or all 54?** Blocks AGE-523.
2. **AGE-510** — nothing detects an unreadable instruction file. Todo, High.
   `[ -L ]` is true, `ls` looks right, git shows clean. Only reading finds it.
3. **Nothing intercepts destructive SQL** on any host, in any repository. An ADR
   accepting the unmitigated loss, with an owner, is still owed.
4. **AGE-509** — `check-shims.sh` has no reverse pass. Backlog. Keeping the
   checker half in #95 was a bet on this landing; if it never does, re-examine.
5. `normalize-claude-md` has no implementation anywhere while
   `project-hook-binding/spec.md` names it as a live shim in seven places.
6. fbc-platform #143: root `deno.lock` still records `husky@9.1.7` and
   `lint-staged@17.3.0`; CI runs `deno test --frozen`.
7. Delete the transitional binder: `reference-implementations/global-floor/`.
8. Three credentials outlived their file in `agenticapps-roadmap`'s `.env`.
9. `claude-workflow` cannot be deleted safely — 11 commits on no remote.

## Mistakes worth not repeating

- **Half the session went to archaeology nobody asked for.** The task was
  "remove the residue"; I reconciled a 44k README while three of four repos
  could not load instructions at all. Finding that took ninety seconds once the
  operator said to look.
- **34 tasks were executed one group at a time for two days without anyone
  asking whether they still had a subject.** They did not — the fleet had been
  clean the whole time. Measure the premise before executing the plan.
- **I argued a symlink would dangle without checking.** It would not; the cache
  keeps old versions, which is worse. The operator pushed back and was right.
  The conclusion survived, the reasoning did not, and only one of those was mine
  to be confident about.
