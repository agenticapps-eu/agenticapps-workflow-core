# Tasks

## 1. Establish the defect as a test before changing anything

- [ ] 1.1 `tdd="true"` — RED: build a synthetic install whose published artifact
  matches its manifest row but differs from the authority's source, and assert
  the check reports it stale. It must fail today reporting `complete` +
  `attested`, which is the whole defect. Record the RED output verbatim
- [ ] 1.2 Assert the direction cases separately, because they carry different
  messages and a single "differs" assertion would pass on all of them: published
  **lower** than the authority, published **higher** than the authority, and
  markers **equal with bytes differing**
- [ ] 1.2a **(gemini plan review)** Assert the case the first draft had no answer
  for: a published artifact with **no counterpart in the authority** — core
  checked out before it existed, or the artifact renamed or removed upstream. It
  is `stale` with its own message and **not `unknown`**; the authority was
  reached, so this is a finding rather than an inability to check
- [ ] 1.3 `tdd="true"` — RED: with the authority unreachable, assert `unknown`
  and assert **specifically that it is not `current`**. A test that only checks
  for the absence of `stale` passes on a silent green, which is the failure mode
  this value exists to prevent
- [ ] 1.3a **(gemini plan review)** Assert the `unknown` report names the path it
  looked for and says the reading is expected on a machine without the authority.
  An operator has to be able to tell an ordinary condition from a broken one
- [ ] 1.3b **(gemini plan review)** Assert the authority is read as a **checkout,
  not a branch**: with the authority path pointed at a tree holding older
  implementations, the machine reports `stale` — the check being right about the
  disk. Observed for real hours earlier, when `--fleet` called a repository stale
  because a concurrent session had moved its checkout
- [ ] 1.4 Assert the licence sentence operationally: a `complete` + `attested` +
  `stale` machine SHALL NOT be described as provisioned in the summary line.
  Grep the summary text, since that string is what an operator actually reads

## 2. Implement the axis

- [ ] 2.1 Resolve the authority. Default from the script's own location, which is
  inside core — the same fixed-point argument the gate hook makes about its own
  path, and for the same reason: an environment variable or a working directory
  can be stale or wrong, and this file's location cannot. Add `--authority DIR`
  for checking a foreign install (design open question 1)
- [ ] 2.2 Compare by **bytes**, not by version. The markers supply the message,
  never the verdict — a file whose bytes differ while its marker matches is
  precisely the case a version-only comparison cannot see, and it is the case
  Stage-2 finding 5 already caught once for shims
- [ ] 2.3 Report `CURRENCY current|stale|unknown` on its own line, and one line
  per stale artifact naming both versions and the direction
- [ ] 2.4 Name the remedy on the stale line: re-run `install-project-hooks.sh`.
  A check that detects a condition without naming how to clear it is one
  operators learn to ignore
- [ ] 2.5 Count currency toward `--strict`, including `unknown` — in CI the
  authority is always reachable, so `unknown` there means the check could not do
  its job
- [ ] 2.6 **Do not install anything.** No auto-repair, not even behind a flag in
  this change. The tools report and the installer installs, and `drifted`'s
  "SHALL NOT resolve it silently" is the same rule

## 3. Correct what the old vocabulary is quoted as saying

- [ ] 3.1 The summary line stops saying "This machine is provisioned. The shims
  will resolve." on a stale machine. It said exactly that on 2026-08-03 while two
  implementations were behind
- [ ] 3.2 `reference-implementations/project-hooks/README.md` — the state
  vocabulary is documented there as a pair and becomes a triple. Include the
  dated observation, because a rule with a recorded counter-example is harder to
  quietly re-weaken than one stated in the abstract
- [ ] 3.3 Grep the repository for other places that describe the state as a pair
  or attach the "running as documented" licence to `attested` alone, and fix each
  — the same sweep discipline the shim-contract bump used. Do not assume the two
  files above are all of them

## 4. Verify

- [ ] 4.1 Re-run the five project-hook suites; record the before/after counts
- [ ] 4.2 Verify against the **real** machine state: this machine was stale at
  18:09–09:00 on 2026-08-02/03 and was brought current before this change was
  written, so it now reports `current`. Reproduce the stale reading by pointing
  `--authority` at a tree holding the older implementations, rather than by
  trusting that the synthetic fixtures resemble it
- [ ] 4.3 `openspec validate --all`, gate `--ci`, and the gate conformance
  harness
- [ ] 4.4 Confirm no shim, project, published artifact or manifest format
  changed. This change touches core's reporting only, and a diff that reaches the
  fleet means something went wrong
