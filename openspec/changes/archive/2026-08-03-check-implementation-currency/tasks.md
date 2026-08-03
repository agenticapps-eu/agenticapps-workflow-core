# Tasks

**Read `REVIEWS.md` before starting.** Three reviewers returned REQUEST-CHANGES
and the first draft of this change was wrong about its own cause — it proposed
building a comparison that already exists. The tasks below are the corrected
scope.

## 1. Establish the defect as a test before changing anything

- [x] 1.1 `tdd="true"` — RED: an install that matches its manifest row while
  differing from the authority must not produce the "This machine is provisioned"
  summary. It does today; that is the defect, and it is reproducible right now by
  pointing `--source-check` at a tree of pre-`f6e4b64` implementations. Record the
  RED output verbatim

  Reproduced against real history — an authority tree built from `f6e4b64~1`,
  installed from, then checked against today's tree. **Verbatim:**

  ```
  MANIFEST  database-sentinel  attested v1.0.0
  MANIFEST  normalize-claude-md  attested v1.0.0

  SOURCE    database-sentinel  DIFFERS from the maintained implementation in <core>/reference-implementations/project-hooks
  SOURCE    normalize-claude-md  DIFFERS from the maintained implementation in <core>/reference-implementations/project-hooks

  COMPLETENESS  complete   (2 of 2 expected artifact(s) present)
  INTEGRITY     attested
  This machine is provisioned. The shims will resolve.
  exit=0
  ```

  The comparison found it on both artifacts and the summary said provisioned
  anyway — the finding fed a separate block and no verdict. This is the whole
  defect in six lines.

- [x] 1.2 `tdd="true"` — RED: a default run (no `--source-check`) must disclose
  that the currency question was not asked. Today it reads identically to a run
  where it was asked and passed

  **Verbatim, same machine, no flag:**

  ```
  MANIFEST  database-sentinel  attested v1.0.0
  MANIFEST  normalize-claude-md  attested v1.0.0

  COMPLETENESS  complete   (2 of 2 expected artifact(s) present)
  INTEGRITY     attested
  This machine is provisioned. The shims will resolve.
  exit=0
  ```

  Byte-for-byte the summary a machine gets when the stronger question *was*
  asked and passed. Nothing distinguishes them.

  **The whole suite was run against the pre-change tool: 28 of the new
  assertions fail, 0 of the pre-existing ones do.** Two rounds were needed. The
  first found only 22, because five fixtures were named for the words their own
  assertions grep for — `mkauth behind` builds `…/auth-behind`, and the old
  `--source-check` line ends with the authority path, so `has "$OUT" "behind"`
  matched the *directory name* against the unfixed tool. That is the
  `override-dir` fixture defect from the previous change, repeated on the same
  suite. Fixtures are now named `fixture-a`…`fixture-h`, and every direction
  assertion is scoped to the artifact's own `CURRENCY` line via `curline()`
  rather than to the whole report.
- [x] 1.3 The four `stale` sub-cases, each asserted on its **message**, not only
  its verdict — a single "differs" assertion would pass on all four and the
  messages are where the remedy lives: published lower, published higher,
  versions equal with bytes differing, and no authority file for a **declared**
  artifact
- [x] 1.4 The `unknown` sub-cases, per design Decision 7: path absent, path
  present but holding no declared artifact (**not** an authority checkout — must
  not report every artifact stale), and an unreadable file. Assert
  **specifically that none of them reads as `current`**; asserting only the
  absence of `stale` passes on a silent green
- [x] 1.5 **Out-of-scope artifacts are not judged.** `openspec-change-gate`,
  `reviewer-cli` and `run-plan-review` share the bin and are published by another
  installer. Assert none of them is reported stale. This is a regression fence: an
  earlier revision of the delta made an absent authority file stale without
  scoping it, and running it flagged exactly these three
- [x] 1.6 Semver ordering is component-wise numeric — assert `1.10.0` is reported
  **ahead** of `1.9.0`, which a lexical compare inverts, pointing the operator at
  the opposite remedy

## 2. Promote the existing comparison to an axis

- [x] 2.1 Resolve the authority by default from the tool's own location, which is
  inside core — the gate hook's fixed-point argument. Keep `--source-check DIR`
  as the explicit override and add `--no-source-check`. **Do not add
  `--authority`**: the first draft proposed it and review found it overlapping
  `--source-check` with no conflict semantics
- [x] 2.2 Judge the **declared** set (`ARTIFACTS`) only
- [x] 2.3 Verdict on bytes; message from `# <hook>-version:`, reusing
  `semver_cmp` from `project-hook-conformance.sh` rather than a second
  implementation. Where either side has no parseable marker, say the version
  could not be read rather than inventing one
- [x] 2.4 Emit `CURRENCY current|stale|unknown`, and per-condition remedies per
  design Decision 5 — **not** one universal "re-run the installer", which is
  wrong for a published-ahead version, a lagging authority checkout, and
  `drifted`+`stale` together
- [x] 2.5 Qualify `current` as *matches this authority checkout*, never *matches
  what core ships*
- [x] 2.6 Aggregate: any `stale` → `stale`; else any `unknown` → `unknown`; else
  `current`
- [x] 2.7 Count currency toward `--strict`, and record in the header that this
  makes `--strict` newly able to fail — a real behaviour change, not a pure
  reporting one
- [x] 2.8 **Install nothing.** No auto-repair, not even behind a flag

## 3. Correct what the old vocabulary is quoted as saying

- [x] 3.1 The summary stops saying "This machine is provisioned. The shims will
  resolve." unless `complete` + `attested` + `current`. Under `unknown` it names
  the question it did not ask
- [x] 3.2 `reference-implementations/project-hooks/README.md` — the state
  vocabulary is documented there as a pair. Include the dated observation: a rule
  with a recorded counter-example is harder to quietly re-weaken
- [x] 3.3 Grep for every other place describing the state as a pair or attaching
  "running as documented" to `attested` alone. Do not assume the two files above
  are all of them

  Four hits beyond the two files, and the assumption was worth checking:

  | file | what it said | disposition |
  |---|---|---|
  | `openspec/specs/project-hook-binding/spec.md` | "two independent axes", `attested` alone licensing "running as documented" | the delta MODIFIES exactly this requirement — corrected on archive, **not** hand-edited here |
  | `tools/provisioning-check.sh` header | "THE STATE IS A PAIR, NOT ONE OF FOUR" | rewritten to the triple |
  | `tools/project-hook-provisioning.test.sh:330` | "The two axes are NOT overloaded" | now "None of the three axes" — a comment nobody would have grepped for |
  | `session-handoff.md` | quotes the old sentence | left; it is a dated record of what was true when written |

## 4. Verify

- [x] 4.1 Re-run the five project-hook suites; record before/after counts

  **190 → 235, all green.** Only the provisioning suite moved.

  | suite | before | after |
  |---|---|---|
  | `project-hook-provisioning.test.sh` | 56 | **101** |
  | `project-hook-conformance.test.sh` | 43 | 43 |
  | `project-hook-shim.test.sh` | 46 | 46 |
  | `project-hooks.test.sh` | 34 | 34 |
  | `normalize-claude-md.test.sh` | 11 | 11 |

  Before-counts measured by restoring the three changed files from `HEAD` **in
  place** and running there. Copying them to a scratch directory first was tried
  and is wrong: both tools resolve their authority from `$SCRIPT_DIR/..`, so a
  copy resolves a scratch directory and the suite refuses to run — which is the
  fixed-point argument working, in the one place it was inconvenient.

- [x] 4.2 Reproduce against the **real** history rather than only fixtures: build
  an authority tree from `f6e4b64~1` and confirm the machine reports `stale` with
  the right per-artifact messages, then confirm the current tree reports `current`

  Both directions, and this is now case 1.1 of the suite rather than a one-off:

  ```
  CURRENCY  database-sentinel  stale — published 1.0.0, this authority checkout holds 1.1.0 (behind)
            Remedy: re-run install-project-hooks.sh.
  CURRENCY  normalize-claude-md  stale — published 1.0.0, this authority checkout holds 1.0.1 (behind)
            Remedy: re-run install-project-hooks.sh.
  CURRENCY      stale
  ```

  `--strict` exits 1 on it. This machine, brought current last session, reports
  `complete` + `attested` + `current` and names the checkout it matched.

- [x] 4.3 `openspec validate --all`, gate `--ci`, gate conformance harness

  `openspec validate --all` **6/6**. Gate `--ci` **OK** — with one `NOTE` that
  the artifacts changed since the review was recorded, which task 4.5 clears.
  `conformance-harness-reporting.test.sh` 36 passed / 5 skipped.
  `change-gate-conformance.sh --family` **355 passed, 0 failed, 0
  inconclusive**, 5 of 6 roster entries scored — `claude-workflow` is not
  vendored and was not attempted, unchanged from the previous session's baseline.

- [x] 4.4 Confirm no shim, project, published artifact or manifest format
  changed. A diff that reaches the fleet means something went wrong

  Four files, and the only one under `reference-implementations/` is the README:

  ```
  M reference-implementations/project-hooks/README.md
  M tools/project-hook-conformance.sh
  M tools/project-hook-provisioning.test.sh
  M tools/provisioning-check.sh
  ? tools/lib/semver.sh          (new — one semver implementation, two callers)
  ```

  No shim, no template, no published artifact, no manifest format. `--fleet`
  reports 6 findings, all on `agenticapps-dashboard` and all pre-existing: its
  checkout sits on another session's branch that predates the 1.1.0 merge, which
  the previous handoff recorded and deliberately did not touch. `origin/main` is
  correct there.

  `tools/lib/semver.sh` is new and is the one structural change. `semver_cmp`
  moved out of `project-hook-conformance.sh` rather than being copied, because a
  divergent second copy fails **silently**: a lexical compare puts `1.10.0` below
  `1.9.0` and hands the operator the opposite remedy, and no output would show
  it. Both callers refuse to report if the lib is missing rather than degrading
  to a currency report with no direction. Neither tool is published to the shared
  bin, so nothing about distribution changes.
- [x] 4.5 Re-run `run-plan-review.sh` after implementation with
  `REVIEW_TIMEOUT=600`. At the default 180s two of three reviewers time out and
  are silently not counted, which is how this change nearly shipped on one
  opinion

  **3 of 3 counted at 600s, none failed** — gemini **APPROVE**, codex and
  opencode **REQUEST-CHANGES**, ten blocking findings between them. Full
  disposition in `CODE-REVIEW.md`; every behavioural claim was reproduced before
  being acted on and none was wrong.

  Running it **after** the code is what made it worth running: two reviewers read
  the tree rather than only the delta, and **eight of the ten findings are the
  delta describing something the implementation does not do.** Three needed code
  — the `--source-check`/`--no-source-check` conflict (was silently
  last-one-wins, now exit 64), `cmp` exit 2 being reported as a difference rather
  than as an inability to compare, and a wrong path description.

  One genuine decision fell out of it: `--no-source-check --strict` exits 1
  unconditionally, and the Migration Plan's claim that the flag "restores the old
  default" was false. **Kept the behaviour, fixed the claim** — carving the
  opt-out out of `--strict` would restore in one flag the silent pass this change
  exists to remove. Now normative in the delta.

  Suite **101 → 109** on the eight assertions this round added.
