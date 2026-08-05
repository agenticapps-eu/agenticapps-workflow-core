# §21 conformance evidence — the four host installers

Produced by `tools/installer-prereq-conformance.sh` on 2026-08-05, run from
`agenticapps-workflow-core` against each host's `install.sh` **read-only**.
No host repository was edited (task 6.2); each host adopts on its own schedule.

The transcripts below were regenerated after the stage-2 review of this branch
fixed six defects in the harness. The verdicts are unchanged — the fixes
changed what the harness can see, not what it found in what it could already
see — but the row wording moved, and the first transcripts recorded `exit=0`
for all four runs when every one of them has a failed row and exits 1.

## What it found

| Installer | consent-guard | owned-writes-reported | prereq-detection | Verdict |
|---|---|---|---|---|
| `claude-workflow` | PASS | PASS | FAIL (`git`) | 3 passed, 1 failed |
| `codex-workflow` | **FAIL** | PASS | FAIL (`git`) | 2 passed, 4 failed |
| `opencode-workflow` | **FAIL** | PASS | FAIL (`git`) | 2 passed, 4 failed |
| `pi-agentic-apps-workflow` | PASS | **FAIL** | FAIL (`git`) | 1 passed, 2 failed |

**The consent row sorts the fleet exactly as the proposal said it would.**
`codex-workflow:333` and `opencode-workflow:373` both reach
`npm i -g @fission-ai/openspec` with no consent read and no opt-in anywhere
before it. Neither tests for an absent terminal, and neither accepts
`AGENTICAPPS_INSTALL_PREREQS` or `--install-prereqs`. `claude-workflow` and
`pi-agentic-apps-workflow` pass the row: they detect and instruct, which §21
holds conformant even though it is not the offer the section prefers.

Two findings the proposal did not predict:

- **All four fail `prereq-detection` on `git`.** Every one of them invokes git
  — submodule sync, `rev-parse` — and none checks for it. Core's own installer
  had the same defect and is fixed in this change; the four hosts inherit the
  finding. It is a small fix and a real one: without the check the failure
  surfaces as git's own "command not found", which names the symptom.
- **`pi-agentic-apps-workflow` fails `owned-writes-reported`.** It writes
  `~/.agenticapps/bin/` and never says so. This is the obligation the migration
  plan said all four gain, and it turns out three of them already satisfy it.

The consent boundary is the one the harness was hardest to get right: three of
the four bind the path to a variable (`AA_BIN`, `AGENTICAPPS_BIN`) and write
through it, so a detector matching the literal path found the write in one
installer out of four and called the rest inconclusive. Fixed before this run;
the fixture that pins it is `indirect` in the test suite.

## Raw output

```
$ tools/installer-prereq-conformance.sh ../claude-workflow/install.sh
═══ ../claude-workflow/install.sh
  FAIL  prereq-detection: invoked but never checked: git
        §21 — an installer declares the external tools it depends on.
  PASS  consent-guard: no out-of-boundary install command was found
        detecting and instructing is conformant; only installing unasked is not.
        the census reads command shapes — an install through a variable, or
        through a package manager not on its list, would not be seen.
  INCONCLUSIVE  non-interactive: no consent-requiring install, so nothing to gate
  INCONCLUSIVE  opt-in: installs nothing, so it is not required to accept the opt-in
  PASS  owned-writes-reported: every file written into ~/.agenticapps/ is named
  PASS  redaction: commands are printed and none carries a credential
  INCONCLUSIVE  uninstall-preserves-prereqs: no removal path, so nothing to judge

─── coverage: 4 of 7 rows scored, 3 inconclusive
═══ TOTAL: 3 passed, 1 failed, 3 inconclusive
exit=1

$ tools/installer-prereq-conformance.sh ../codex-workflow/install.sh
═══ ../codex-workflow/install.sh
  FAIL  prereq-detection: invoked but never checked: git
        §21 — an installer declares the external tools it depends on.
  FAIL  consent-guard: install reachable with no consent read and no opt-in
          line 333: npm i -g @fission-ai/openspec            || echo    ${YELLOW} ${RESET}
        §21 — consent is required to change software the workflow does not own.
  FAIL  non-interactive: no test for an absent terminal before an install
        §21 names the rule — standard input not being a terminal.
  FAIL  opt-in: not accepted: AGENTICAPPS_INSTALL_PREREQS --install-prereqs
        both spellings are fixed by §21; a host-chosen name is four names.
  PASS  owned-writes-reported: every file written into ~/.agenticapps/ is named
  PASS  redaction: commands are printed and none carries a credential
  INCONCLUSIVE  uninstall-preserves-prereqs: no removal path, so nothing to judge

─── coverage: 6 of 7 rows scored, 1 inconclusive
═══ TOTAL: 2 passed, 4 failed, 1 inconclusive
exit=1

$ tools/installer-prereq-conformance.sh ../opencode-workflow/install.sh
═══ ../opencode-workflow/install.sh
  FAIL  prereq-detection: invoked but never checked: git
        §21 — an installer declares the external tools it depends on.
  FAIL  consent-guard: install reachable with no consent read and no opt-in
          line 373: npm i -g @fission-ai/openspec          || echo    ${YELLOW} ${RESET}
        §21 — consent is required to change software the workflow does not own.
  FAIL  non-interactive: no test for an absent terminal before an install
        §21 names the rule — standard input not being a terminal.
  FAIL  opt-in: not accepted: AGENTICAPPS_INSTALL_PREREQS --install-prereqs
        both spellings are fixed by §21; a host-chosen name is four names.
  PASS  owned-writes-reported: every file written into ~/.agenticapps/ is named
  PASS  redaction: commands are printed and none carries a credential
  INCONCLUSIVE  uninstall-preserves-prereqs: no removal path, so nothing to judge

─── coverage: 6 of 7 rows scored, 1 inconclusive
═══ TOTAL: 2 passed, 4 failed, 1 inconclusive
exit=1

$ tools/installer-prereq-conformance.sh ../pi-agentic-apps-workflow/install.sh
═══ ../pi-agentic-apps-workflow/install.sh
  FAIL  prereq-detection: invoked but never checked: git
        §21 — an installer declares the external tools it depends on.
  PASS  consent-guard: no out-of-boundary install command was found
        detecting and instructing is conformant; only installing unasked is not.
        the census reads command shapes — an install through a variable, or
        through a package manager not on its list, would not be seen.
  INCONCLUSIVE  non-interactive: no consent-requiring install, so nothing to gate
  INCONCLUSIVE  opt-in: installs nothing, so it is not required to accept the opt-in
  FAIL  owned-writes-reported: writes ~/.agenticapps/ and never says so
        the exemption from consent is paired with the obligation to report;
        without the pair it is a loophole rather than a boundary.
  INCONCLUSIVE  redaction: prints no command, so there is nothing to redact
  INCONCLUSIVE  uninstall-preserves-prereqs: no removal path, so nothing to judge

─── coverage: 3 of 7 rows scored, 4 inconclusive
═══ TOTAL: 1 passed, 2 failed, 4 inconclusive
exit=1
```
