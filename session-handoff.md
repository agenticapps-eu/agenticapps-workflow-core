# Session Handoff — 2026-08-05 (fourth session)

## Accomplished

**Stage-2 review of PR #82, then fixed everything it found.** Six defects in
`tools/installer-prereq-conformance.sh`, all in the quiet direction the third
session predicted. Suite 75 → 102, still 0 failed.

The one that mattered: **the guard search was "does the word `read` occur
earlier in this file"**, so the first correctly gated install site permanently
satisfied every site added below it. An installer with one gated install and
one ungated install scored 6/6 clean, exit 0. The row would have gone green
exactly as the fleet began adopting §21 and never failed again — the harness
breaking at the moment it started being used.

The other five:

- a **line continuation** hid the install entirely (`npm install \` newline
  `-g pkg` matched nothing), and the consent row then reported the positive
  claim that no install reaches outside the workflow's surface. codex-workflow
  already breaks that line, one token to the right
- **heredoc bodies were read as code** — an installer writing its own README
  scored the documentation, three false findings against a script that
  installs nothing
- **`export AA_BIN=…`** did not bind the owned directory, so the write went
  invisible; the same false inconclusive as the literal-path bug, one keyword over
- **redaction reported the wrong line number** — `$RAW` has its comments
  stripped, so its numbering is a file the operator does not have (a leak on
  source line 10 was reported as line 4)
- `tr -c '[:print:]'` converted the trailing newline, appending a stray `?` to
  every command the consent row named

Also: `owned-writes-reported` now scores §21 as written — every file **by
name**. It was satisfied by any mention of the directory, so an installer could
say "installed into ~/.agenticapps/bin" and pass having told the operator
nothing about what is now on their machine.

Verification: 102/102 under bash 3.2/BSD sed; §20 suite 42/42; agents-md 77/77;
hook installer 16/16; drift-report 18/18; spec-placement clean; `openspec
validate --all` 8/8; gate `--ci` green. Robustness sweep over all 23 `tools/*.sh`
plus all five installers: no crash, every exit in {0,1,2}.

**The fleet scorecard is unchanged** — same totals for all four hosts and core's
own before and after. The fixes changed what the harness can see, not what it
found in what it could already see.

## Decisions (fourth session, merged as #82 / 2827fa1)

- **Guard reach is cut by a construct closing at column 0** (`fi`, `done`,
  `esac`, `else`, `elif`, `;;`, `}`). Block-structure parsing was rejected as
  more machinery than the claim needs. The opt-in resolves through the variable
  it is bound to, because reading it at the top and testing it near the site is
  the shape every host actually wrote.
- **A `while`/`until` read is not consent evidence.** It is a loop over input,
  not a question put to the operator.
- **An unterminated heredoc aborts (exit 2)** rather than scoring a truncated
  file. A blanked tail is the strongest possible version of the failure §20
  exists to prevent.
- **Fixing heredocs introduced a worse bug, caught by pointing it at the real
  fleet again.** `<<<` matched as a heredoc one character in, opening a body
  whose terminator never arrived — pi went dark from line 118 and its
  `prereq-detection` FAIL silently became INCONCLUSIVE. Pinned by the
  `herestring` fixture. **The fixtures were not enough; the real installers
  were.** This has now been the lesson three sessions running.
- **codexish flipped to FAIL** on `owned-writes-reported`: it names the
  directory and not the file. The real codex-workflow installer names its file.
- **No spec change.** §21 already said everything the harness now scores; the
  implementation had drifted from it, not the other way round.

## The fleet adoption (fifth session, same day)

**§21 is adopted in all four hosts. Six PRs, all CI-green, all merged.**

| repo | PR | before | after |
|---|---|---|---|
| `claude-workflow` | #113 | 3 passed, 1 failed | 4 passed, 0 failed |
| `codex-workflow` | #35 | 2 passed, 4 failed | 6 passed, 0 failed |
| `opencode-workflow` | #24 | 2 passed, 4 failed | 6 passed, 0 failed |
| `pi-agentic-apps-workflow` | #20 | 1 passed, 2 failed | 3 passed, 0 failed |
| core | #83 | — | the git row is four of four, not three |
| core | #84 | — | two harness fixes, below |

codex and opencode were the two the section was written about. Both now offer
rather than install: y/yes only, case-insensitive, EOF and anything
unrecognised decline, no terminal means report-and-refuse, `--install-prereqs`
/ `AGENTICAPPS_INSTALL_PREREQS=1` authorise it unattended, a failed install
reports its exit status, and a skipped step exits non-zero. The consent branch
was exercised directly for every path §21 names, not just scored statically.

**Adopting the contract found two more harness defects, both the same shape:
indirection through a helper.**

- **A consent prompt in a function was not a guard.** The first adoption wrote
  `prereq_consent()` and called it above the install — the shape §21 wants —
  and the branch-scoped scan could not see the `read` inside the body. The
  harness failed the best implementation available while passing nothing
  better. Functions whose body reads consent or the opt-in are now resolved.
- **A report through a logging helper was not a report.** pi names every file
  it writes, through `done_`, under a header naming the directory, and the row
  read literal echo/printf only — so it was told it says nothing. Loggers are
  now resolved, and a dispatcher (`run() { …; else "$@"; fi; }`) deliberately
  is not: counting it would make `run cp gate.sh "$AA_BIN/x"` its own report.

pi needed **no repo change** for the owned-write row. It was a false FAIL.

Two unrelated bugs found while working in the same files: opencode's
`--skip-upstream` has been documented and rejected by its own arg parser since
it was introduced (the second `for arg` loop that reads it never runs, because
the first hits `*)` and exits 2), and pi told the operator "not a git
repository" about a repository that is one, whenever git itself was absent.

## Next session: start here

**Nothing is pending.** All six PRs are merged, and every installer scores zero
failures from its own main:

    claude-workflow    bb59fe6   4 passed, 0 failed, 3 inconclusive
    codex-workflow     5421812   6 passed, 0 failed, 1 inconclusive
    opencode-workflow  9bf6015   6 passed, 0 failed, 1 inconclusive
    pi                 1f3af6e   3 passed, 0 failed, 4 inconclusive
    core (own)         348a878   3 passed, 0 failed, 4 inconclusive

There is no §21 work left. **Start with the first open question below —
publishing the harness.** Until that is settled, nothing stops the next
installer change from reintroducing exactly what this fixed.

## Open questions

- **Nothing enforces §21 on any host.** The harness lives only in core's
  `tools/` — it is not published to `~/.agenticapps/bin/`, no host CI runs it,
  and no host repo references it. All four adoptions were scored by running
  core's checkout by path. So conformance is voluntary and unverified from the
  host side, and the next host installer that adds a global install will not be
  caught by anything. Either publish the harness the way the gate and the
  reviewer wrapper are published, or accept that core scores the fleet by hand.
  This is the decision worth taking before anything else.
- **`non-interactive` is still file-scoped.** Any `-t 0` anywhere passes the
  row, including an unrelated colour-detection test. Scoping it per-site the
  way consent now is would false-fail the conformant reference, whose tty test
  sits in the `elif` after the opt-in branch. The PASS now carries a note
  saying so, which is disclosure rather than a fix.
- **`prereq-detection` still reads a fixed list of 17 known tools.** Unchanged
  from last session. A prerequisite outside the list is invisible and the row
  does not say so.
- **A `read` in the same branch as an install is still counted even if it is
  not a consent prompt.** Narrower than before, not gone.
- **The bash 5.2 / GNU sed / mawk leg was not re-run** — no bash 5 or GNU
  coreutils on this machine. CI covers it; local verification was bash 3.2/BSD
  only.
- **CodeRabbit did review #82**, unlike #79-#81 — 8 actionable comments, two of
  them real. Do not assume it skips; read the body.
- **`.planning/skill-observations/*` is still being written** despite the
  freeze rule. Unchanged across six handoffs.
