# ADR-0019: Drift report checks a declared prose set, not the whole clone

**Status**: Accepted  **Date**: 2026-07-15  **Supersedes**: —

## Context

`tools/drift-report.sh` compares the spec's canonical-prose blocks against
host clones. It shipped with no tests and three defects, all of which were
reproduced live before this change:

1. **The red-flags check baked in the flag count.** It grepped for the
   literal `13 Red Flags — STOP → DELETE → RESTART`. But spec/04 rule 3
   (since spec 0.8.0) states the heading's leading count is **not
   normative** — a host that appends a host-specific flag updates it to its
   own total. claude-workflow legitimately ships `## 14 Red Flags — …`. The
   tool was enforcing a literal the spec explicitly declares non-normative:
   it contradicted the spec it exists to check.

2. **The grep was unscoped.** `grep -r --include="*.md"` over the whole
   clone meant a phrase found in a migration, a test fixture, a planning
   doc, or `docs/ENFORCEMENT-PLAN.md` satisfied a conformance check. A host
   could gut its real instruction file and still pass on a test fixture's
   quotation of the phrase.

3. **It read gitignored scratch.** This produced a live false PASS:
   `.superpowers/sdd/task-{4,5}-report.md` in claude-workflow quote the old
   canonical phrase, so §04 reported `OK` while `skill/SKILL.md` had
   legitimately moved to `## 14 Red Flags`. **No tracked file** in the clone
   contained the phrase the tool was looking for. The only thing holding the
   check green was disposable scratch.

Defects 1 and 3 were load-bearing on each other: fixing the scratch-blindness
alone would have flipped claude-workflow to a *false DRIFT*; fixing the count
alone would have made it pass for the right reason. Neither could land alone.

Two further problems surfaced while testing:

4. **Unversioned and absent instruction files were scored.**
   pi-agentic-apps-workflow carries `implements_spec` in no file anywhere, yet
   scored 12 OK — though spec/09 item 4 says a host without that field "is
   unversioned and cannot claim any conformance level".

5. **Repos that author no canonical prose were scored.**
   agenticapps-dashboard is ledger-classified a consumer ("reads workflow
   artifacts; does not author them") and was checked anyway, matching against
   its scaffolded payload. Between them, pi and the dashboard contributed 27
   of the report's 68 OKs — noise from repos that never claimed conformance.

## Decision

**A canonical phrase satisfies a check only when it appears in one of the
files the host declares as carrying its canonical prose.**

Each host is declared as
`"repo-dir|workflow-instruction-file|project-instruction-file"`:

```
claude-workflow|skill/SKILL.md|CLAUDE.md
codex-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md
opencode-workflow|skills/agentic-apps-workflow/SKILL.md|AGENTS.md
```

The paths are literal, not globs. An earlier revision globbed them and paid for
it: an unquoted `for pat in $secondary_pats` pathname-expands each pattern
against the *caller's* directory before it reaches the host, so the report
answered differently depending on where it was run from. No host needs a glob,
so the feature is gone rather than fixed.

The primary file must carry `implements_spec:` (spec/09 item 4); if it is
missing or unversioned the host reports `ERROR` and is not scored. The
red-flags check matches only the canonical, non-count portion of the heading.
`HOSTS` lists only hosts that author canonical prose.

Scoping this way removes the need for gitignore-awareness entirely: scratch is
excluded **by construction**, not by an exclusion list. The tool needs no git
plumbing.

### Why the paths are declared, not discovered

Discovery by scanning for `implements_spec:` is the obvious alternative and it
does not work: the field does not identify the file uniquely. claude-workflow
has **seven** files carrying it (a build-artifact snapshot, satellite skills
like `ts-declare-first`, and three stale planning docs); codex-workflow has
**thirteen**. Any disambiguation rule — shallowest path, first match, name
convention — is a heuristic that can silently pick the wrong file. That is
precisely the bug class this ADR closes. A declared path is boring, and it
fails loudly (`ERROR`) when a host moves its file instead of quietly scoring
the wrong one.

### Why two files rather than one

§09 item 1 says "the host's instruction file" (singular), and read alone that
suggests one file per host. But **§11 carries its own binding clause**, to a
different file:

> Host implementations MUST reproduce the block below verbatim in their
> **primary project-instruction file** (CLAUDE.md, AGENTS.md, or whichever
> filename the host runtime treats as canonical project-level guidance).

So the two-file split is the spec's own design, not a host convenience: the
workflow skill carries §01/03/04/05, and the project-instruction file carries
§11. Each host declares both.

Scoping to a single file per host was tried first and reported a false DRIFT on
§11 for all three hosts. It was caught only by running against the real clones;
the synthetic fixtures, which assumed the singular framing, passed.

### What must never go in the declared set: a scaffolding payload

The first attempt to fix the above declared claude-workflow's
`templates/spec-mirrors/*.md`, reasoning that §11 is "injected into consuming
projects rather than spoken by the skill". That reasoning was wrong, and the
error is worth recording because it is subtle and it recreated the very defect
this ADR closes.

The mirror under `templates/` is **payload**: migration 0014 injects it into
consuming projects. It instructs nobody in claude-workflow itself. Counting it
made §11 report OK for claude-workflow off the back of a template — the same
false PASS as the gitignored scratch, wearing better clothes — and it **masked
a real gap**. Under §11's actual clause:

| Host | §11 block lives in | Conformant? |
|---|---|---|
| codex-workflow | `AGENTS.md` | yes |
| opencode-workflow | `AGENTS.md` | yes |
| claude-workflow | *(nowhere in the host's own files)* | **no** |

claude-workflow's `CLAUDE.md` does not carry the block, and `skill/SKILL.md`'s
spec-deltas list declares no §11 delta — which §09 requires for any unsatisfied
requirement. The source of canonical prose is the one host not reproducing this
block. The old recursive grep never caught it because the block appears in
`templates/`, `setup/`, and `migrations/0014`; it has been a false PASS for as
long as the tool has existed.

Declaring `CLAUDE.md` surfaces it as honest DRIFT. A test (T13) pins the payload
mirror as something that must not satisfy the check.

The narrowness matters for §04 too: claude-workflow ships a *reworded* 13-flag
list in its vendored payload (`templates/.claude/claude-md/workflow.md`) which
its own spec delta declares is not bound by §09 item 1. Nothing under
`templates/` is in the declared set, so that divergence cannot satisfy §04
either. A test pins this too (T11).

## Alternatives Rejected

- **Discover the instruction file by scanning for `implements_spec:`.**
  Rejected: not unique (7 and 13 candidates), so it needs a heuristic, and a
  heuristic that silently picks wrong is the defect being fixed.
- **Parse `reference-implementations/README.md` as the source of truth for
  host list, conformance level, and prose paths.** Right in principle — the
  ledger already records this — but it is prose markdown with the data buried
  in free-text Notes cells. It would need a machine-readable field first.
  Worth doing when the ledger gains structure; tracked as a follow-up.
- **Keep the repo-wide grep and add an exclusion list** (`.superpowers`,
  `.planning`, …). Rejected: a denylist is unbounded and grows silently stale;
  the next scratch directory reintroduces the false PASS. Scoping inverts this
  to an allowlist of ~2 files per host.
- **Extend the check into a full canonical-block differ.** spec/04's rationale
  notes the block was designed so "conformance is an exact match rather than an
  order-preserving subsequence search", so this is tempting and probably right
  eventually. Rejected here as scope creep: it is a redesign of what the tool
  asserts, not a fix to defects it shipped with. Follow-up.

## Consequences

- The report went from 68 OK / 7 DRIFT across 5 repos to **42 OK / 3 DRIFT /
  0 ERROR across 3 hosts**, and every OK is now earned against a declared
  prose file rather than against scratch or a payload.
- **The 3 DRIFT are real, and they are the tool's first true finding:**
  claude-workflow does not reproduce the §11 block in its own `CLAUDE.md`,
  while codex and opencode both do in their `AGENTS.md`. This is a live
  conformance gap in the host that claims `full` at 0.9.0 and is the source of
  canonical prose. It needs either the block added to `claude-workflow/CLAUDE.md`
  or a §11 delta declared in its `skill/SKILL.md` — a host change, out of scope
  here. The tool's job was to stop hiding it.
- `tools/drift-report.test.sh` is core's **first test of any kind**. The tool
  shipped three defects precisely because nothing exercised it. 16 assertions,
  no network, no real clones, temp dirs only.
- Adding a host, or a host moving its prose, now requires a one-line edit to
  `HOSTS`. Forgetting produces a loud `ERROR`, not a silent wrong answer.
- **pi-agentic-apps-workflow is retired as a host.** Its ledger row is removed;
  adoption was never pursued and the repo is no longer in use.
- The per-host `implements_spec` is printed in the report, which surfaces
  **codex-workflow sitting at 0.4.0 against spec 0.9.1** to anyone reading it.
  The tool still does not gate on version currency — deliberately out of scope,
  and codex's canonical prose genuinely passes, since 01/03/05/11 are unchanged
  since 0.4.0 and §04's 0.8.0 change only relaxed the heading rule.
- **Not a spec version bump.** `tools/` and `reference-implementations/` are
  not normative spec text, and spec/09's description of the tool ("an advisory
  check that compares canonical-block presence across known host clones")
  remains accurate. No host's conformance claim changes.

## Follow-ups

- Give the ledger a machine-readable per-host field and have the tool read it
  (retires the duplicated `HOSTS` table).
- **claude-workflow §11 gap** (surfaced by this change): add the block to
  `claude-workflow/CLAUDE.md`, or declare a §11 spec delta in its
  `skill/SKILL.md`. Until then its `full` claim at 0.9.0 is overstated.
- README.md:100 classifies §09 as "Not normative", yet §09 is where every
  conformance MUST lives, and both this ADR and the spec reason from it as
  normative. README.md:92-99 is also stale (canonical-prose "01, 03, 04, 05"
  omits 11). Pre-existing; worth reconciling.
- Consider a full canonical-block differ per spec/04's exact-match rationale.
