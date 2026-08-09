# Session Handoff — 2026-08-09 (twenty-seventh session)

gstack removed and reinstalled clean. One PR merged. One change proposed and
closed as having no subject, one proposed and discarded, and the survivor folded
into `diagram-is-the-surface`. **Nothing is implemented — that change has 64
unticked tasks and is the next session's whole job.**

## Accomplished

- **gstack: full removal and clean reinstall.** One checkout at
  `~/.claude/skills/gstack` (v1.60.1.0 → **v1.61.0.0**), `./setup --host auto`,
  native on claude + codex + opencode. Removed: 55 link-dirs, the hand-vendored
  `setup-gstack`, six gstack-derived prefixed links, `~/.pi/agent/gstack-pi`
  (**1.0 GB**, a second checkout of the same upstream) and the `pi-gstack` npm
  package. Kept by your decision: `~/.gstack` (API key, learnings, 308M browser
  profiles) and the eight project `.gstack/` dirs.
- **`ts-declare-first` symlink removed**; no dangling symlink in any host dir.
- **`database-sentinel` removed from the machine** — skill checkout and both host
  aliases. No host declares that name.
- **`impeccable` now resolves canonically on all four skill dirs**, one
  declaration each, via plain symlinks nothing in the workflow owns. On demand
  everywhere, per your instruction.
- **PR #99 merged** (`5bb0bf9`) — `docs/evidence/gate-skill-resolution-measured.md`.
- **`diagram-is-the-surface` revised**: two gate bindings folded in, re-reviewed,
  findings folded, coherent. `validate --all` green 14/14.

## Decisions

- **Reinstall native on all hosts, kill the custom prefixed links.** Your call.
  The six removed were true duplicates — `codex-cso` and `gstack-cso` both
  declared `cso` on one host.
- **`~/.gstack` kept.** It holds a live OpenAI key and months of learnings and
  causes no duplication. Removing it would have cost real data for nothing.
- **§13 dropped, against your instruction, on evidence you didn't have.** You
  chose "retire it anyway, the host repos are going away." They aren't: all four
  have live remotes with commits dated 2026-08-05, and `agenticapps/CLAUDE.md`
  lists three under "Active repos". `install.sh`'s `ARCHIVED` list governs
  symlink targets — "not a dependency", in its own comment — not repo lifecycle.
  **Reversing this is one edit; it needs a deprecation window or evidence no host
  ships it, not a fourth reading of local state.**
- **2.0.0, not 1.7.0.** I argued minor; two reviewers independently called it
  self-serving and were right. A consumer losing an automatic security control
  has had something broken.
- **`impeccable` unbound as policy, not cleanup.** The skill exists and stays
  installed. Labelled as a policy change so it isn't buried under "dead surface".

## Files modified

- `docs/evidence/gate-skill-resolution-measured.md` — new, merged in PR #99
- `openspec/changes/diagram-is-the-surface/proposal.md` — gate bindings added;
  §13 section rewritten recording three failed retirement attempts; version
  resolved to 2.0.0; `adrs/` and `CHANGELOG.md` removed from the exclusion list
- `.../design.md` — goals cover the gate bindings; the "nothing breaks `spec/`,
  2.0.0 uncontested" claim corrected; PR #78 collision recorded as live
- `.../specs/vestigial-surface-removal/spec.md` — gate-binding requirements;
  "a local artifact is not evidence about a normative section"; failure-path
  recommendations are governed surface
- `.../tasks.md` — re-review moved to **group 0**; task 1.2 withdrawn as
  superseded; groups 9/9b/9c added; §13 tasks removed
- `.../REVIEWS.md` — rewritten for round 2 (gemini + codex, both
  REQUEST-CHANGES), replacing a record whose reviewers never saw the folded scope
- Machine (not version-controlled): gstack, database-sentinel, impeccable,
  ts-declare-first as above

## Next session: start here

**Implement `diagram-is-the-surface`.** Review is done — group 0 is ticked, do
not re-review. The 64 tasks are over-decomposed; the real work is five chunks:
delete `GSD_SKIP_REVIEWS` (**51 occurrences across 29 files** — by far the
largest), delete `gate/`, fix `workflow.mmd` + the gate header, remove the two
gate rows from `skills/agentic-apps-workflow/SKILL.md` and amend §02/§17, then
write ADR-0030 + bump spec to 2.0.0 + CHANGELOG. **Start with
`GSD_SKIP_REVIEWS`** — it is most of the diff and the rest is small by
comparison. Branch off `main`; there is no branch for this change yet.

## Open questions

1. **PR #78 also claims spec 2.0.0.** Both can't have it. Whichever merges first
   takes it, the other rebases to 2.1.0. Undecided.
2. **§13** — reinstate only with a lifecycle argument. See Decisions.
3. **Both reviewers said split this change into three.** You chose the fold and I
   kept it; with §13 out, the remaining two strands are both gate bindings on a
   change that already owns the diagram. Revisit if implementation gets unwieldy.
4. **The installer has no retired-artifact sweep**, so removals here don't reach
   other machines' installs. Scoped honestly to this machine; gap not closed.
5. **After any `gstack-upgrade`, re-run `./setup --host auto`** — upgrade runs a
   bare `./setup`, which relinks claude only.
6. **`impeccable` is bound by two hand-made symlinks** no installer recreates.
   Deliberate — the workflow is not to own its availability — but a machine
   rebuild loses them.
7. Carried over, untouched this session: AGE-510 (nothing detects an unreadable
   instruction file), AGE-509 (`check-shims.sh` has no reverse pass), no
   interception of destructive SQL, `normalize-claude-md` has no implementation,
   `claude-workflow` has 11 commits on no remote.

## Mistakes worth not repeating

- **I measured skill presence by directory basename.** codex and opencode key on
  the declared frontmatter `name:`. That one error produced a whole proposed
  change with no subject. Use `grep -lm1 "^name: X$" */SKILL.md`.
- **Three attempts have now tried to retire §13 from local state** — a skills
  directory, a symlink, an installer variable. Two of them were mine, this
  session. The section's implementation name is host-discretionary; local
  absence proves nothing.
- **I talked myself down from a correct 2.0.0 to a wrong 1.7.0** and needed two
  external reviewers to put it back.
- **I over-decomposed the plan.** 64 checkboxes for ~26 real actions, after
  proposing two changes that were discarded. The operator called it out and was
  right.
