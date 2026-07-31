# RED run — 2026-07-31T20:08:33Z

```

═══ change-gate-conformance.sh  (shape=M roster=roster)
  FAIL  A. missing target -> non-zero
        exited 0; output:   SKIP  /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/absent/t0 (not found)||═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
  FAIL  B. empty target -> UNSCOREABLE, reason empty
        non-zero but no reason matching /UNSCOREABLE.*empty/; got: |═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t1|    (0 lines)|  ── A. Truth table (spec/18) ──|  PASS  no active change -> allow (exit 0
  FAIL  C. directory target -> UNSCOREABLE, reason not-a-regular-file
        exited 0
  FAIL  D. unreadable target -> UNSCOREABLE, reason unreadable
        non-zero but no reason matching /UNSCOREABLE.*unreadable/; got: |═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t3|/Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/tools/change-gate-conform
  FAIL  E. broken symlink -> UNSCOREABLE, not-a-regular-file wins
        exited 0
  FAIL  F. newline in a path cannot forge a PASS line
        matched forbidden /^  PASS  forged row/:   SKIP  /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t5|  PASS  forged row (not found)||═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
  SKIP  G. three-target row (set HARNESS_TEST_SLOW=1)
  FAIL  H. roster flag + explicit path -> usage error
        non-zero but no reason matching /usage|cannot be combined|both/; got: |═══ /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/reference-implementations/openspec-change-gate/openspec-change-gate.sh|    (775 lines)|  ── 
  FAIL  I. whole roster absent -> coverage line printed
        got: usage: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/fake-change-gate-conformance.sh/root/tools/change-gate-conformance.sh <gate-script> [...]
  FAIL  I2. whole roster absent -> NOT reported as a usage error
        reported a usage error instead of missing hosts
  SKIP  J. roster coverage rows (set HARNESS_TEST_SLOW=1) — needs a real sweep

═══ run-plan-review-conformance.sh  (shape=M roster=norost)
  FAIL  A. missing target -> non-zero
        exited 0; output:   SKIP  /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/absent/t0 (not found)||═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
  FAIL  B. empty target -> UNSCOREABLE, reason empty
        non-zero but no reason matching /UNSCOREABLE.*empty/; got: |── /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t1|   marker: <unmarked, treated as 0.0.0>||  A. Floor|  PASS  one reviewer returns, two tim
  FAIL  C. directory target -> UNSCOREABLE, reason not-a-regular-file
        exited 0
  FAIL  D. unreadable target -> UNSCOREABLE, reason unreadable
        non-zero but no reason matching /UNSCOREABLE.*unreadable/; got: |── /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t3|grep: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t3: Permission deni
  FAIL  E. broken symlink -> UNSCOREABLE, not-a-regular-file wins
        exited 0
  FAIL  F. newline in a path cannot forge a PASS line
        matched forbidden /^  PASS  forged row/:   SKIP  /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t5|  PASS  forged row (not found)||═══ TOTAL: 0 passed, 0 failed, 0 inconclusive
  SKIP  G. three-target row (set HARNESS_TEST_SLOW=1)

═══ reviewer-cli-conformance.sh  (shape=M roster=roster)
  PASS  A. missing target -> non-zero
  FAIL  B. empty target -> UNSCOREABLE, reason empty
        non-zero but no reason matching /UNSCOREABLE.*empty/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t1|  ── A. Argument handling ──|  FAIL  no arguments -> 3 — expected 3, got 0|  FAIL  vendor
  FAIL  C. directory target -> UNSCOREABLE, reason not-a-regular-file
        non-zero but no reason matching /UNSCOREABLE.*not a regular file/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t2|  FAIL  file not found||═══ TOTAL: 0 passed, 1 failed
  FAIL  D. unreadable target -> UNSCOREABLE, reason unreadable
        non-zero but no reason matching /UNSCOREABLE.*unreadable/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t3|  ── A. Argument handling ──|  FAIL  no arguments -> 3 — expected 3, got 126|  FAIL  vend
  FAIL  E. broken symlink -> UNSCOREABLE, not-a-regular-file wins
        non-zero but no reason matching /UNSCOREABLE.*not a regular file/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t4|  FAIL  file not found||═══ TOTAL: 0 passed, 1 failed
  FAIL  F. newline in a path cannot forge a PASS line
        matched forbidden /^  PASS  forged row/: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t5|  PASS  forged row|  FAIL  file not found||═══ TOTAL: 0 passed, 1 failed
  SKIP  G. three-target row (set HARNESS_TEST_SLOW=1)
  FAIL  H. roster flag + explicit path -> usage error
        non-zero but no reason matching /usage|cannot be combined|both/; got: ═══ /Users/donald/Sourcecode/agenticapps/agenticapps-workflow-core/tools/../reference-implementations/reviewer-cli/reviewer-cli.sh|  ── A. Argument handling ──|
  FAIL  I. whole roster absent -> coverage line printed
        got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/fake-reviewer-cli-conformance.sh/root/tools/../reference-implementations/reviewer-cli/review
  PASS  I2. whole roster absent -> NOT reported as a usage error
  SKIP  J. roster coverage rows (set HARNESS_TEST_SLOW=1) — needs a real sweep

═══ resolve-core-artifact-conformance.sh  (shape=S roster=norost)
  PASS  A. missing target -> non-zero
  FAIL  B. empty target -> UNSCOREABLE, reason empty
        non-zero but no reason matching /UNSCOREABLE.*empty/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t1|  ── A. Resolve and verify ──|  PASS  pinned file resolves from a local checkout (exit 0)
  FAIL  C. directory target -> UNSCOREABLE, reason not-a-regular-file
        non-zero but no reason matching /UNSCOREABLE.*not a regular file/; got: no such resolver: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t2
  FAIL  D. unreadable target -> UNSCOREABLE, reason unreadable
        non-zero but no reason matching /UNSCOREABLE.*unreadable/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t3|  ── A. Resolve and verify ──|  FAIL  pinned file resolves from a local checkout — expect
  FAIL  E. broken symlink -> UNSCOREABLE, not-a-regular-file wins
        non-zero but no reason matching /UNSCOREABLE.*not a regular file/; got: no such resolver: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t4
  FAIL  F. newline in a path cannot forge a PASS line
        matched forbidden /^  PASS  forged row/: no such resolver: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t5|  PASS  forged row

═══ shared-install-conformance.sh  (shape=S roster=norost)
  PASS  A. missing target -> non-zero
  FAIL  B. empty target -> UNSCOREABLE, reason empty
        non-zero but no reason matching /UNSCOREABLE.*empty/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t1|  ── A. Arbitration ──|  FAIL  installs when destination is absent — got ABSENT|  FAIL  i
  FAIL  C. directory target -> UNSCOREABLE, reason not-a-regular-file
        non-zero but no reason matching /UNSCOREABLE.*not a regular file/; got: not found: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t2
  FAIL  D. unreadable target -> UNSCOREABLE, reason unreadable
        non-zero but no reason matching /UNSCOREABLE.*unreadable/; got: ═══ /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t3|  ── A. Arbitration ──|  FAIL  installs when destination is absent — got ABSENT|  FAIL  i
  FAIL  E. broken symlink -> UNSCOREABLE, not-a-regular-file wins
        non-zero but no reason matching /UNSCOREABLE.*not a regular file/; got: not found: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t4
  FAIL  F. newline in a path cannot forge a PASS line
        matched forbidden /^  PASS  forged row/: not found: /var/folders/tg/4sw8p55n5gzgzlv1b7nb9qrm0000gn/T/tmp.8e4VPuHSxs/t5|  PASS  forged row

═══ TOTAL: 4 passed, 32 failed, 5 skipped
```
