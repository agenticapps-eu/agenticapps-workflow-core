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

## Decisions

- **Guard reach is cut by a construct closing at column 0** (`fi`, `done`,
  `esac`, `else`, `elif`, `;;`, `}`). Block-structure parsing was rejected as
  more machinery than the claim needs; the closing-construct rule fails every
  probe correctly and false-fails none of the sixteen existing fixtures. The
  opt-in is resolved through the variable it is bound to, because reading it at
  the top and testing it near the site is the shape all four hosts will write.
- **A `while`/`until` read is not consent evidence.** It is a loop over input,
  not a question put to the operator. `codexish` plus one unrelated manifest
  loop was enough to flip its FAIL to PASS.
- **An unterminated heredoc now aborts (exit 2)** rather than scoring a
  truncated file. §20 says a harness never reports a verdict it did not reach,
  and a blanked tail is the strongest possible version of that failure.
- **Fixing heredocs introduced a worse bug, caught by pointing it at the real
  fleet again.** `<<<` matched as a heredoc one character in, opening a body
  whose terminator never arrived — the pi installer went dark from line 118 and
  its `prereq-detection` FAIL silently became INCONCLUSIVE. The `<<<` test is a
  check on the preceding character; the `herestring` fixture pins it. Same
  lesson as last session: **the fixtures were not enough, the real installers
  were.**
- **codexish's expectation flipped to FAIL** on `owned-writes-reported`. It
  names the directory and not the file, which §21 forbids. The real
  codex-workflow installer names its file and still passes.

## Files modified

Both on `feat/installer-prerequisite-consent`, PR #82. **Uncommitted.**

- `tools/installer-prereq-conformance.sh` — code view rewritten (heredocs,
  continuations, unterminated-heredoc abort); guard reach scoped; opt-in
  variable resolution; `export`-bound owned dirs; per-file owned-write scoring;
  redaction line numbers; the stray `?`
- `tools/installer-prereq-conformance.test.sh` — 8 new fixtures
  (`halfadopted`, `continued`, `loopread`, `docheredoc`, `herestring`,
  `unterminated`, `exportowned`, `ownedpartial`) and section G; codexish's
  owned-write expectation flipped

No spec change. §21 already said everything the harness now scores; the
implementation had drifted from it, not the other way round.

## Next session: start here

**Commit the two files and push to PR #82** — nothing else is pending on this
branch, and the working tree is verified green. Then the fleet work the third
session queued is still waiting: `codex-workflow:333` and
`opencode-workflow:373` non-conformant on consent, `pi` on the reporting
obligation, and three of four on the unchecked `git`. Each is that host's own
change.

Worth knowing before that work starts: the consent row is now much harder to
satisfy accidentally, so a host adopting §21 will get a real answer rather than
a green one.

## Open questions

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
- **The plan reviews still predate the merged text**, and **CodeRabbit still
  has not reviewed #82**. Unchanged.
- **`.planning/skill-observations/*` is still being written** despite the
  freeze rule. Unchanged across six handoffs.
