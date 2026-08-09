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

**AGE-523 — gstack.** Researched and decided; not started.

### What the operator decided, in their words

- **They use gstack's skills** — not just the four the workflow names. So this is
  a live dependency, and the question "bind four or all 54" is answered: **all of
  them.** Do not narrow it to the gate skills.
- **Same shape as `superpowers`**: one clone in a global location, symlinked per
  host.
- **On the two competing copies**: fetch the latest into the global checkout and
  **remove both old ones.** Do not try to reconcile or merge them — the newest
  upstream wins and the duplicates go.
- **On the installer**: read how gstack installs itself, then decide whether to
  use its installer or do our own symlinking. Their framing, and it turned out to
  be the load-bearing question.

### What the research found, and why it inverts PR #96's approach

**gstack already does exactly what we were about to build, and does it better.**
`~/.claude/skills/gstack/setup` is a 1531-line multi-host installer:

- targets `CODEX_SKILLS`, `OPENCODE_SKILLS`, `FACTORY_SKILLS`, kiro, openclaw,
  hermes, gbrain
- `--host claude|codex|kiro|factory|opencode|auto`, with `auto` detecting by
  executable — the same rule `install.sh` uses
- **symlinks**, via one helper carrying an explicit invariant that *every*
  symlink in the script routes through it (the `cp -R` branch is Windows-only)
- carries `migrate_direct_codex_install`, which relocates a checkout to
  `$HOME/.gstack/repos/gstack` — so upstream is itself moving off the
  skills-directory location

**So do not write our own binder.** Run `./setup --host auto` and let it own the
per-host symlinking. Writing our own would fight an installer that already
handles four more hosts than we do, and it is the exact mistake nearly made with
the superpowers plugin cache — reaching into another tool's internals instead of
using its supported path.

**The checkout's location is upstream's documented default, not a mistake.** The
README's install line is
`git clone … ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`.
Moving it out unilaterally would break `gstack-upgrade` and the hourly
auto-update check. If it should move, `$HOME/.gstack/repos/gstack` is upstream's
own answer — check whether `setup` supports being run from there before assuming.

**The prefixed copies are probably ours, not gstack's.** `install.sh`'s own
comment says the archived host installers vendored `codex-cso`, `opencode-qa`,
`codex-impeccable-audit`. gstack's setup creates *neutral* names. So the twelve
`codex-*`/`opencode-*` directories are almost certainly legacy vendoring from the
retired `codex-workflow`/`opencode-workflow`, and running gstack's setup will not
remove them — **we** have to. They are byte-identical to the neutral versions, so
deleting them loses nothing. Confirm the provenance before deleting.

**And the top-level `cso`/`qa` copies are stale.** They are real directories, and
they are *missing files* the checkout's versions have (`ACKNOWLEDGEMENTS.md`,
`SKILL.md.tmpl`). That is an older gstack vendored at some point, not a symlink
setup produced — which is the operator's "remove both old ones" case exactly.

### Suggested first actions

1. `cd ~/.claude/skills/gstack && git pull` — get latest into the global checkout.
2. Read `setup`'s host-targeting section properly (lines ~180–260) and confirm
   what it writes where, and whether it is idempotent over the current mess.
3. Establish provenance of the twelve prefixed copies and the stale top-level
   `cso`/`qa` before removing anything.
4. Run `./setup --host auto`, then re-measure the 54 collisions.
5. Decide whether `install.sh` should invoke gstack's setup the way it already
   invokes `bind-openspec-tools.sh`, or whether gstack stays operator-run.

## Open questions

1. **gstack: use upstream's `setup`, or our own symlinking?** Research says use
   `setup`. Confirm it is idempotent against the current duplicated state first.
2. **Does the gstack checkout move out of `~/.claude/skills/`?** Upstream's
   documented install puts it there; upstream's own migration helper points at
   `$HOME/.gstack/repos/gstack`. Do not move it without reading which upstream
   actually supports today.
3. **AGE-510** — nothing detects an unreadable instruction file. Todo, High.
   `[ -L ]` is true, `ls` looks right, git shows clean. Only reading finds it.
4. **Nothing intercepts destructive SQL** on any host, in any repository. An ADR
   accepting the unmitigated loss, with an owner, is still owed.
5. **AGE-509** — `check-shims.sh` has no reverse pass. Backlog. Keeping the
   checker half in #95 was a bet on this landing; if it never does, re-examine.
6. `normalize-claude-md` has no implementation anywhere while
   `project-hook-binding/spec.md` names it as a live shim in seven places.
7. fbc-platform #143: root `deno.lock` still records `husky@9.1.7` and
   `lint-staged@17.3.0`; CI runs `deno test --frozen`.
8. Delete the transitional binder: `reference-implementations/global-floor/`.
9. Three credentials outlived their file in `agenticapps-roadmap`'s `.env`.
10. `claude-workflow` cannot be deleted safely — 11 commits on no remote.

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
