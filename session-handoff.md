# Session Handoff — 2026-08-05

## Accomplished

**Three branches, two of them finished and green.**

`factiv/cparx` PR #125 — removed both vestigial host installs. `.opencode/`
had a tracked config and a `0.5.0` stamp but no skills; `.codex/` had the same
two files and was never committed. Both marker-delimited blocks stripped from
`AGENTS.md` (285 → 93 lines), leaving the coding-discipline preamble and the
observability block. All six CI jobs pass; CodeRabbit reviewed it for real, no
findings. **Those were the last two stale `0.5.0` stamps in the fleet.**

`agenticapps-workflow-core` PR #78 (executable migration format) — was red,
now green. The four CI failures were one bug: seven rollback blocks used
`sed -i '' 'script' file`, the BSD spelling where the backup suffix is a
separate argument. GNU sed reads `''` as the script and the sed expression as a
filename. `spec/08-migration-format.md`'s own worked example had the
mirror-image bug — bare `sed -i`, which BSD rejects — so the one example the
format teaches from would have failed on every macOS, and CI (Linux) could
never have caught it. All now use `sed -i.bak … && rm -f …bak`.

Then two follow-on fixes on the same PR: `tree_snapshot` preflights `shasum`
and exits 2 rather than returning an empty snapshot on a box without Perl
(which made seventeen rollback assertions fail while blaming the fixtures), and
a new **L11** lint rule rejects non-portable `sed -i`. 567 → 587 assertions,
green under bash 3.2 + BSD sed and bash 5 + GNU sed 4.9 in a container.

`feat/host-neutral-agents-md` — new OpenSpec change proposed, all four
artifacts written and reconciled, `openspec validate --all` green, pushed. **No
PR opened; nothing implemented yet.**

## Decisions

- **A duplicate `AGENTS.md` section is reported, never auto-collapsed.** The
  cparx pair had drifted, so merging means choosing between `gsd-execute-plan`
  and `gsd-execute-phase` — and both were wrong, since GSD was deleted
  2026-07-28. A tool that picked silently would ship a dead reference with the
  authority of having been fixed.
- **A link per agent is the only host-specific content in `AGENTS.md`**
  (Donald). This *replaced* a rule already written — "the shared file is
  touched only at the boundaries" — which was wrong in an interesting way: it
  protected the file by making agents invisible in it, so nothing recorded
  which agents were installed and removal had no per-agent handle to pull.
- **The host-neutral section survives the last agent leaving** (Donald).
  Symmetry is the wrong goal; a repo briefly without an agent would lose
  documentation it is about to want back.
- **A host identifier inside the section warns, does not fail** (Donald), and
  **the links are exempt** — a correctness condition, not a nicety, since a
  check that flagged them would fire on the one thing the spec permits.
- **`CLAUDE.md` is out of scope entirely** (Donald). Claude is its only reader,
  so there is nothing to deduplicate and claude-workflow's lack of a marker
  convention is not a defect.
- **Core binds this with a conformance harness, not an implementation** — it
  cannot provision an agent into a repo it does not own, and the templates that
  write these blocks live in `codex-workflow` and `pi-agentic-apps-workflow`.

## Files modified

- `factiv/cparx`: `AGENTS.md` (-190), `.opencode/workflow-{config.md,version.txt}`
  deleted, `.codex/` removed. A backup of the untracked `.codex/` (it held a
  real 2026-07-28 review record) exists in that session's scratchpad only.
- `reference-implementations/migration-runner/lint-migration.sh` — L11 added
- `reference-implementations/migration-runner/README.md` — L0–L11, L11 rationale
- `reference-implementations/migration-runner/test-fixtures/` — 7 sed fixes, 6 files
- `spec/08-migration-format.md` — the worked example's `sed -i`
- `tools/migration-runner.test.sh` — preflight + L11 section (587 assertions)
- `openspec/changes/host-neutral-agents-md/` — proposal, design, 2 specs, tasks

## Next session: start here

**Run `/opsx:apply` on `host-neutral-agents-md`.** You are already on branch
`feat/host-neutral-agents-md`, off main, artifacts complete and validated.
Task group 1 is the three decisions above, already marked `[x]` — carry them,
do not re-litigate. Start at **2.5**, which settles the link's shape (markdown
link under a fixed heading / marker-delimited block / frontmatter list),
because tasks 3.3 and 4.8 both write spec text that depends on it. Before that,
2.2 and 2.3 need the GSD references and the drifted step names resolved against
what the workflow does today — neither cparx block can be the basis for
canonical text, since both cite a deleted system.

Both other PRs are green and mergeable, and nothing here is blocked on them:
core #78 and cparx #125.

## Open questions

- **The link's shape** — task 2.5, blocks the spec text.
- **The host-identifier denylist has no source.** It needs a list and a rule
  for a new host not on it, which is the case where the warning is most useful
  and least likely to fire.
- **CodeRabbit has still never reviewed core #78.** It reports `pass` with
  "Review rate limited" — the state is not the review. cparx #125 got a real one.
- **`sed -i` portability was invisible to every reviewer, in both directions**,
  because each spelling reads correct to whoever shares the author's sed. L11
  closes it for migrations; nothing checks the rest of the tree.
- **`.planning/skill-observations/*` is still being written into these repos**
  despite the global rule that `.planning/` is frozen. Unchanged across three
  handoffs now. Worth finding the writer or gitignoring it.
