# Two-stage review — shim-project-hooks

Core spec §07 requires both stages recorded in one document under separate
top-level headings. Under the OpenSpec front end (§07's v1.0.0 remap, §17)
Stage 1 collapses into `openspec validate` plus the pre-code multi-AI review,
so the Stage 1 heading records where that evidence lives rather than
duplicating it. Stage 2 is retained unchanged and is authored here.

Unlike `REVIEWS.md`, this file is NOT producer-managed: it carries no digest
trailer and `run-plan-review.sh` neither writes nor reads it. `REVIEWS.md` must
not be hand-edited; this file must not be generated.

## Stage 1 — Spec compliance

Discharged by the machine check plus the pre-code review, per §17's gate map:

- `openspec validate --all` — green, 5 passed / 0 failed.
- Multi-AI pre-code review — `REVIEWS.md` in this directory, written by
  `run-plan-review.sh`: gemini APPROVE, codex REQUEST-CHANGES, opencode
  REQUEST-CHANGES, `claude` excluded as the implementing host. That file is the
  Stage 1 artifact and carries the digest binding it to the reviewed text.

Stage 1 ran before Stage 2, as §07 requires. The two REQUEST-CHANGES verdicts
were answered in the delta itself — each objection appears in
`specs/project-hook-binding/spec.md` as a named correction — so Stage 2 reviews
code written against the revised contract.

## Stage 2 — Code quality

**Independence.** Authored in a cleared session with no access to the
implementing session's conversation context, per §07's rule that the
implementer must not author Stage 2 and its preference for a fresh context.
Disclosure, because independence claims should be checkable: this session read
`session-handoff.md` at startup, which contains the author's own account of the
change. Every finding below was nonetheless derived from the files and verified
by execution, and three of the four leading findings are in areas the handoff
does not mention.

**Scope.** The code this change adds to core — the two implementations, the
shim template, the migrated gate shim, the installer, the two check tools, and
the five test suites. Planning artifacts are Stage 1's subject. Delta
conformance was checked where code claims to implement a normative clause.

**Method.** Read, then execute. Every finding marked *verified* was reproduced
by running something.

### Verification performed

| Check | Result |
|---|---|
| `tools/project-hooks.test.sh` | 30 passed / 0 failed |
| `tools/project-hook-shim.test.sh` | 22 passed / 0 failed |
| `tools/project-hook-conformance.test.sh` | 21 passed / 0 failed |
| `tools/project-hook-provisioning.test.sh` | 45 passed / 0 failed |
| `tools/normalize-claude-md.test.sh` | 9 passed / 0 failed |
| Total | **127 assertions green** (the change record says 128) |
| Live install into a scratch `HOME` | publishes 2 artifacts, manifest written, exit 0 |
| Shim byte-identity, published-resolution profile | `agenticapps-roadmap` and `agents-task-viewer` are byte-identical to `sed s/@@HOOK@@/<hook>/` of the template, and to each other |
| Matcher vs. implementation coverage | both repos register `Bash\|Edit\|Write\|MultiEdit` for `database-sentinel`, `Edit\|Write\|MultiEdit\|NotebookEdit` for the gate — agrees with what the implementations handle |

`agenticapps-dashboard`'s working tree still carries the pre-shim vendored
hooks; it is checked out on `feat/close-readiness-spec-gaps`, which is the
branch tangle already recorded as an open question, not a defect of this change.

### Findings

Ordered by consequence. None blocks; three are worth fixing before archive.

**1. `mv`-as-rename changes `CLAUDE.md`'s mode to 0600, and the comment claims
the opposite** — `reference-implementations/project-hooks/normalize-claude-md.sh:296`

`TMP_OUT` comes from `mktemp` (0600). `rename(2)` makes the destination *name*
refer to the temp inode, so the destination takes the temp file's mode. The
comment at :293–295 states "Preserves permissions because mv-as-rename doesn't
touch file mode of the existing entry being replaced" — that is the inverse of
what `rename(2)` does.

*Verified:* a 0644 file, replaced by this exact sequence, measured 0600
afterwards.

Practical blast radius is small — git tracks only the executable bit and the
owner can still read it — but this is a fleet-canonical implementation, the
golden corpus does not compare modes, and a comment asserting a guarantee the
code does not deliver is the defect class this whole change exists to remove.
Fix: capture `stat -f %Lp` / `-c %a` of the input and re-apply after the `mv`.

**2. The ownership and writability rules are established at install time and
never checked afterwards** — `tools/provisioning-check.sh`,
`tools/project-hook-conformance.sh`

The delta requires (spec.md, "A shared hook's protections are described as what
they are") that a published artifact owned by another user "SHALL be reported,
not executed silently", that neither the directory nor any artifact be group- or
world-writable, and that the manifest is covered by the same rules — describing
all of it as "checkable by the conformance tool that already exists". No tool
checks any of it. `provisioning-check.sh` reports presence, executability and
digest; `project-hook-conformance.sh` reports markers and override vectors.

Consequences: a `chmod g+w ~/.agenticapps/bin` performed after a clean install
reports `complete` + `attested`; and the installer's own
`chmod go-w "$DEST_DIR" 2>/dev/null || true`
(`reference-implementations/shared-install/install-project-hooks.sh:197`)
swallows the failure that a directory owned by another user would produce.

The property is asserted only in `tools/project-hook-provisioning.test.sh:237`,
against a tree the test just created. That proves the installer sets the mode;
it cannot observe the machine anyone is actually running on — which is the exact
gap the per-machine check was added to close.

This is the mitigation the delta offers in exchange for accepting an
arbitrary-code-execution concentration point. It should be a loop in
`provisioning-check.sh`; it is roughly ten lines.

**3. The concurrency assertion does not pin the lock** —
`tools/project-hook-provisioning.test.sh:204`

The test backgrounds two installers and immediately `wait`s. Each run completes
in milliseconds, so the two critical sections need not overlap, and the
assertion ("3 rows survive") passes whether or not mutual exclusion exists.

*Verified:* with the `mkdir` lock loop disabled outright, the same scenario
passed **15 out of 15** runs. The suite would not have detected the lock's
removal.

`install-project-hooks.sh` has deterministic abort knobs but no
in-critical-section delay knob; `install-shared-artifact.sh`'s
`SHARED_INSTALL_TEST_DELAY` is the precedent its own header cites. Add the
equivalent, have the first run hold the lock across the manifest rewrite, and
assert the second blocks rather than interleaves.

Given the `flock` deviation was accepted on the grounds that the suite "tests
the behaviour, not the primitive"
(`install-project-hooks.sh:146–157`), the suite has to actually test it.

**4. The stale-lock breaker can delete a live lock** —
`reference-implementations/shared-install/install-project-hooks.sh:165–175`

`rm -rf "$LOCKDIR"` runs unconditionally once a dead pid is observed. Two
waiters that both read the same dead pid race: the first breaks the lock and
`mkdir`s it, the second then removes the *new* holder's lock and enters the
critical section as well. The window is narrow and needs two waiters plus a
dead holder, so it is unlikely rather than impossible.

It matters because the deviation from `flock` was justified as preserving "the
property the task is protecting", named as *a lock that does not outlive its
holder*. Mutual exclusion under contention is a second property `flock` holds
and the substitute does not, and it is not among the residuals recorded.

Fix without changing the scheme: break by `mv "$LOCKDIR" "$LOCKDIR.stale.$$"`
(only one racer can win the rename) and `rm -rf` the moved directory.

**5. Nothing checks a shim's content — only its marker** —
`tools/project-hook-conformance.sh:113`

The delta makes the template in core "the authority" and requires byte-identity
within a profile. The check reads `# shim-contract:` and compares semver. A
project shim can be edited to add behaviour, reorder resolution, or drop the
fail-open path and still report `current`, because nothing compares content.

The render is deterministic — I reproduced both landed projects' shims exactly
with `sed 's/@@HOOK@@/<hook>/g'` — so the byte-identity requirement is
mechanically checkable in a few lines, and adding it would turn the marker from
an attestation about a string into one about the file.

**6. An override naming a directory is `exec`'d** —
`reference-implementations/project-hooks/shim-template.sh:87`,
`.../openspec-change-gate.shim.sh:110`

The delta honours the override "only when it names an existing executable
**regular file**". `[ -x "$OVERRIDE" ]` is true for any searchable directory,
so the shim `exec`s it.

*Verified:* with the override pointing at a directory, the shim exits **126**
with bash's own "is a directory" message; the specified invalid-override report
never fires, and the exit code is not the stated 1.

Fail-open is preserved, so this is a conformance and diagnostics defect rather
than a safety one. Fix: `[ -f "$OVERRIDE" ] && [ -x "$OVERRIDE" ]`.

Related, same line: an override exported as the empty string is treated as
unset and falls through to the shared install. The delta says an override that
is set but does not name an executable regular file "SHALL NOT fall through".
`FOO=` is a common way to neutralise a variable, so silently ignoring it is
defensible — but it is a decision, and it is unrecorded.

**7. Two declarations of the expected hook set** —
`tools/project-hook-conformance.sh:30`

`SHIMMED_HOOKS=(...)` is hardcoded while the installer and the provisioning
check both read `reference-implementations/project-hooks/ARTIFACTS`. That file
exists precisely because a set derived in more than one place drifts, and its
header says so. The gate legitimately is not in `ARTIFACTS` (a different
installer publishes it), so the fix is a second declared list read by the third
tool, not a merge.

**8. `provisioning-check.sh` crashes on a missing option value** —
`tools/provisioning-check.sh:57–60`

*Verified:* `provisioning-check.sh --dest` → `line 57: $2: unbound variable`,
exit 1. Its sibling shipped in the same change guards every option and exits 64
with a usage message (`install-project-hooks.sh:75–80`). Two tools, one change,
two argument-parsing conventions.

**9. Comment overstates the directory's mode** —
`reference-implementations/shared-install/install-project-hooks.sh:192` vs `:197`

The comment says "0700 on the directory, 0755 on the artifacts"; the code
applies `chmod go-w`. *Verified:* a fresh install produces **0755** on
`~/.agenticapps/bin`. World-readable and traversable is a fine posture for this
directory — the comment should say what the code does.

**10. `database-sentinel`'s DELETE guard misses schema-qualified tables** —
`reference-implementations/project-hooks/database-sentinel.sh:44`

`[a-z_][a-z0-9_]*[[:space:]]*(;|$)` stops at the dot, so `DELETE FROM
public.users;` does not match and is allowed; quoted and backticked identifiers
behave the same. The hook is best-effort by design and the README's coverage
boundary is otherwise unusually honest, but it names indirection as the bypass
and not this one. Either widen the character class or add the case to the
boundary text.

**11. No dependency check in the implementations** —
`database-sentinel.sh:28`

`jq` absent → `set -e` aborts at the first command substitution, exit 127,
nothing explaining why. The shim layer is meticulous about announcing an
unresolvable implementation; the implementation is silent about an unresolvable
dependency. Low impact (`jq` is present fleet-wide), noted for symmetry.

### Code-style consistency

Consistent with the surrounding tools and with each other on the things that
matter: `set -u` everywhere, `set -o pipefail` where a pipeline's status is
read, `die`/`note` helpers, `--flag value` and `--flag=value` both accepted,
long rationale comments in the house style that state what was rejected and
why. Exit-code vocabulary (0 / 1 / 2 / 64 / 65) is uniform across the new tools.

Two inconsistencies, both minor and both listed above: argument-value guarding
(finding 8) and the expected-set declaration (finding 7). One stylistic note not
worth a finding — the gate shim is a hand-maintained sibling of the template
rather than a render of it, which the "shims are deliberately copies" rule
permits, but it means the rate-limit block now exists in two files that must be
edited together.

### Naming

`shim-contract:` versus `<hook>-version:` is the distinction the delta was
forced to draw, and both the code and the reports keep it. `completeness` /
`integrity` and their values read correctly at the call site and in the output.
`report_rate_limited` says what it does. `KEEP` / `ROWS` / `NAMES` are terse but
scoped to a screenful. `install-project-hooks.sh` versus the pre-existing
`install-shared-artifact.sh` is the one pair a newcomer will have to look up —
the header explains it in its first paragraph.

### Obvious-bug scan

Checked and clean: array expansion under `set -u` (`${NAMES+"${NAMES[@]}"}`
throughout), `read` into three fields on short manifest rows, subshell scoping
of the `findings` counter in `project-hook-conformance.sh` (here-strings, not
pipelines — the counter does survive), the `tr 'a-z-' 'A-Z_'` transliteration
(equal-length sets, trailing `-` literal), the `\$` end-anchor inside the
double-quoted ERE, semver comparison on validated input, `exec` preserving
stdin, and — since it was the near-miss defect — argv reaching the
implementation, which is asserted at
`tools/project-hook-shim.test.sh:251`.

Defects found are findings 1, 4 and 6 above. Nothing in the scan suggests a
systemic problem.

### What is good, recorded because a review that only lists defects misleads

- `ARTIFACTS` — replacing a discovered expected set with a declared one is the
  right fix to a bug class that made "one implementation missing" report as
  `complete`. The header explains the failure rather than the mechanism.
- The two-axis state model is implemented as designed, and
  `provisioning-check.sh` computes both axes from disk with no appeal to
  history.
- The publication ordering is implemented exactly as specified — every artifact
  renamed, then the manifest rewritten once — and the crash tests exercise both
  windows through deterministic abort points rather than timing.
- The undeclared-artifact case (`reviewer-cli.sh` in the shared directory)
  is scoped out instead of reported as drift, which is the difference between a
  check people run and one they learn to ignore.
- The unverified `PostToolUse` reporting channel is recorded as unestablished
  rather than claimed. That is the change's own rule applied against its own
  interest.

### Verdict

**pass-with-followups.**

The contract is implemented, the tests are green and honest about most of what
they pin, byte-identity holds where the change has landed, and the fail-open
posture behaves correctly under every failure mode I could construct — including
the two the code does not handle as specified (findings 4 and 6), where it
degrades safely rather than blocking.

Recommended before archive: **1** (a stated guarantee the code inverts), **2**
(the mitigation the delta trades the ACE concentration point for), **3** (an
assertion that passes 15/15 with the mechanism removed).

Findings 4–11 are follow-ups. None of them changes whether this should merge.
