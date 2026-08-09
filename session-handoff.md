# Session Handoff — 2026-08-09 (twenty-sixth session)

Group 3.13 is executed, reviewed against the code rather than the plan, pushed
and on PR #95. The four working repositories now resolve an instruction file on
every host — three of them did not when the session started.

## Accomplished

- **Group 3.13 complete, RED first.** Three assertions written and observed
  failing (56 passed / 3 failed against a 56/0 baseline) before a single
  deletion; 55/0 after. Deleted `database-sentinel.sh`, `ARTIFACTS`,
  `install-project-hooks.sh`, `tools/project-hooks.test.sh`, the `PROJHOOKS`
  wiring, 4 cases and 16 stub lines. On the machine:
  `~/.agenticapps/bin/database-sentinel.sh` and `manifest.tsv`.
- **The bind half is green and untouched** — check-shims 9/0, project-hook-shim
  64/0, bind-openspec-tools 42/0, init-project 55/0, `validate --all` 14/0.
- **PR #95 open.** Not archived: 34 tasks in the change are still open.
- **THREE OF FOUR REPOS HAD NO READABLE INSTRUCTION FILE.** `callbot` and
  `fx-signal-agent` carried a committed symlink loop — `AGENTS.md → CLAUDE.md →
  AGENTS.md`, ELOOP on both names, since 2026-08-08 21:46. `fbc-platform` had
  `CLAUDE.md` only, so codex/pi/omp read nothing. All three fixed and committed.
- **5.1 measured on two hosts.** codex and omp, in a throwaway `cparx` worktree,
  both activated the skill unprompted and emitted the ritual. Worktree removed.

## Decisions

- **The `# shim-contract:` marker is NOT bumped**, against task 3.13f. It argued
  the bump propagates template bytes; `check-shims.sh:97` propagates them with
  `cmp -s` and never reads the marker, and the spec names exactly four triggers —
  resolution order, exit behaviour, identification, reporting. A header comment
  is none. Bumping would have moved two sibling files for a contract that did
  not change.
- **`SHIMMED-HOOKS` carries the invariant** (3.13k): an entry requires a
  surviving publisher owning the implementation. Otherwise the checker demands
  shims that fail open against a path nothing writes.
- **Docs reconciled, not rewritten.** What instructed is corrected; what recorded
  is marked superseded and left. An evidence file edited to match the present
  stops being evidence.
- **`database-sentinel` the upstream skill keeps its name everywhere.** It is a
  different thing from the retired hook and the sweep had to say so explicitly.
- **The change is not archived.** Groups 2, 2b, 3.8 and most of 4–6 are open. It
  was never one change; it is four.

## Files modified

- `install.sh` — PROJHOOKS variable, delegation and the attestation claim removed
- `tools/install.test.sh` — 3.13a's three assertions in, 4 cases and 16 stubs out
- `reference-implementations/project-hooks/{shim-template.sh,SHIMMED-HOOKS,FLEET,README.md}`
- `docs/HOW-IT-FITS-TOGETHER.md`, `docs/evidence/install-run-after.md`
- `tools/project-hook-shim.test.sh` — header notes why the fixture name survives
- `openspec/changes/projects-bind-not-copy/{tasks.md,manifest.tsv.retired}`
- `callbot`, `fx-signal-agent`, `fbc-platform` — instruction files (own commits)

## Next session: start here

**Do not open a new group in `projects-bind-not-copy`.** Merge #95, then decide
whether that change survives as one change at all — 34 open tasks across five
groups, and the two that matter (2: `check-project-skills.sh`; 2b: the reverse
pass) are independent tools that would each be a change in their own right. The
first action is a split proposal, not more execution. Open question 1 from the
previous handoff still stands and is now the deciding one: `check-shims.sh` has
no reverse pass, so keeping the bind half is a bet on 2b landing.

## Open questions

1. **codex resolves none of the four `superpowers:*` gate skills.** Measured this
   session. It reports and continues, which is correct behaviour and no coverage
   at all — on codex, TDD/verification/branch-close/`cso` are prose. Whether that
   is acceptable is a decision nobody has made.
2. **Nothing intercepts destructive SQL, on any host, in any repository.** An ADR
   accepting the unmitigated loss, with an owner, is still owed (3.9d records the
   decision; an ADR is its home).
3. `check-shims.sh` has no reverse pass — tasks 2b.1–2b.5 all open.
4. `normalize-claude-md` has no implementation anywhere while
   `project-hook-binding/spec.md` names it as a live shim in seven places. The
   phantom manifest row was its last trace and went with the manifest.
5. `.planning/` survives in cparx, fbc-platform, fx-signal-agent (task 6.2).
6. fbc-platform #143: root `deno.lock` still records `husky@9.1.7` and
   `lint-staged@17.3.0`; CI runs `deno test --frozen`. Fix is
   `deno install --frozen=false` on `chore/drop-vendored-workflow-copies`.
7. Delete the transitional binder: `reference-implementations/global-floor/` and
   `tools/global-floor-bind.test.sh`.
8. Three credentials outlived their file in `agenticapps-roadmap`'s `.env`.
9. `claude-workflow` cannot be deleted safely — 11 commits on no remote.

## Mistakes worth not repeating

- **I spent the session's first half on archaeology the user did not ask for.**
  The task was "remove the residue"; I produced a reconciled 44k README. The
  three broken repositories — the thing actually blocking work — were found only
  after the user said so, in a check that took ninety seconds.
- **A symlink loop is invisible to every check we have.** `[ -L ]` is true,
  `ls -l` looks right, git shows a clean tree. Only reading the file finds it,
  and no sweep reads instruction files. Two repositories ran that way for a day.
