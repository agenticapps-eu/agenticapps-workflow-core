# Executable Migration Format Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give core spec §08 a machine-executable migration format, and ship the extractor, runner and format linter that consume it — so applying a migration needs bash and nothing else.

**Architecture:** Migration steps keep their existing `**Label:**` prose headings and gain a `role=` tag on each executable fence. Three bash scripts in `reference-implementations/migration-runner/`: `extract.sh` (a library that pulls a role-tagged block out of a step), `lint-migration.sh` (rules L1–L5 plus the ID threshold), and `run-migration.sh` (check → precondition → apply → verify, with the A2 failure policy). Tests follow core's existing convention — a single `tools/migration-runner.test.sh` driving each script through its public interface against fixtures in a temp dir.

**Tech Stack:** bash 3.2+ (macOS default), awk, git. No Node, no network, no external dependencies.

> **Revised after Stage 2 review.** Three independent reviewers returned
> REQUEST-CHANGES on the first draft. Two structural findings are fixed in the
> code below: the runner now lints before executing anything (it previously
> would run an all-illustration migration and report success), and the linter
> now derives the migration ID from the **filename** rather than frontmatter (a
> missing `id:` line previously evaded it entirely, defeating the whole reason
> the ID was chosen). See `openspec/changes/executable-migration-format/design.md`,
> "What the Stage 2 review changed".
>
> **`openspec/changes/executable-migration-format/tasks.md` is now the
> authoritative task list** — it has nine groups, including a new one for the
> lint-first refusal. The task numbering below predates that split and no
> longer matches one-to-one. The `TOTAL: N passed` figures below are likewise
> from the pre-review draft and are now floors, not targets: the revision adds
> assertions for verify failure, three-valued `check`, filename-ID evasion,
> opt-in below threshold, non-consecutive numbering, info-string grammar, skip
> continuing, and the all-illustration refusal. Record actual counts in the
> ledger as you go rather than trusting these.

## Global Constraints

- **Bash, not JavaScript.** Migration steps are bash; a JS runner shells out for every block and buys only a process boundary. Migrations must stay runnable on a machine with no Node.
- **Version marker on line 2 of every script:** `# migration-runner-version: 0.1.0`. This is core's established convention (`# gate-version: 2.0.0`, `# reviewer-cli-version: 1.2.0`) and is what Part 2's installer will arbitrate on.
- **Roles:** `check`, `precondition`, `apply`, `verify` (optional), `rollback`. Nothing else is valid.
- **Role → heading map:** `check`→`**Idempotency check:**`, `precondition`→`**Pre-condition:**`, `apply`→`**Apply:**`, `verify`→`**Verify:**`, `rollback`→`**Rollback:**`.
- **Un-annotated ```` ```bash ```` fences are illustration and MUST NOT be executed.**
- **ID thresholds** (a migration at or above its host's threshold MUST be executable): claude-workflow `0035`, codex-workflow `0016`, opencode-workflow `0012`, pi-agentic-apps-workflow `0011`.
- **A2 failure policy:** TTY → prompt retry/skip/rollback. Non-TTY → abort in place, print which steps applied, **roll back nothing**. `--on-failure=abort|prompt|skip` overrides.
- **Pre-condition stderr is reproduced verbatim**, never paraphrased.
- **No writes outside a temp dir in any test.** No network in any test.
- `set -uo pipefail` at the top of every script (core's convention — note `-e` is deliberately absent; these scripts inspect exit codes).

## Fixture construction

`test-fixtures/conformant.md` is written out in full in Task 1 and is the base
for every other fixture. Each broken fixture is that file with **exactly one**
stated change, so that when it fails the linter you know which rule caught it
and nothing else is in play. Build each by copying `conformant.md` and applying
only the delta in its table row — do not vary anything else, or a test that
passes for the wrong reason becomes possible.

| Fixture | `id` | `slug` | The one delta from `conformant.md` |
|---|---|---|---|
| `bad-l1-missing-rollback.md` | 0017 | `bad-l1` | Keep step 1 only; delete its `**Rollback:**` heading and `role=rollback` fence |
| `bad-l3-duplicate-apply.md` | 0018 | `bad-l3` | Keep step 1 only; add a second `**Apply:**` heading and `role=apply` fence containing `echo "twice" >> fixture.txt` |
| `bad-l5-role-on-yaml.md` | 0019 | `bad-l5` | Keep step 1 only; add a fence opened as ```` ```yaml role=apply ```` containing `key: value` |
| `bad-l2-wrong-heading.md` | 0020 | `bad-l2` | Keep step 1 only; swap the two tags — put `role=apply` under `**Rollback:**` and `role=rollback` under `**Apply:**` |
| `bad-l4-typo-role.md` | 0021 | `bad-l4` | Keep step 1 only; open the apply fence as ```` ```bash role=aply ```` |
| `bad-threshold-no-frontmatter.md` | 0022 | `bad-threshold` | Keep step 1 only; delete the `migration_format: executable` line from frontmatter |
| `failing-apply.md` | 0023 | `failing-apply` | Keep both steps; change step 2's check to `test -f never.txt` and its apply to `exit 7` |
| `failing-precondition.md` | 0024 | `failing-precondition` | Keep step 1 only; replace its pre-condition with the three-line block shown in Task 5 |

---

### Task 1: The extractor

**Files:**
- Create: `reference-implementations/migration-runner/extract.sh`
- Create: `reference-implementations/migration-runner/test-fixtures/conformant.md`
- Create: `tools/migration-runner.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: three functions, and a CLI wrapping them. Later tasks source this file.
  - `mr_steps <doc>` → step numbers, one per line, in document order.
  - `mr_roles <doc> <step>` → role names present in that step, one per line, in document order.
  - `mr_block <doc> <step> <role>` → that block's body on stdout, no fence lines. Empty output and exit 1 if absent.
  - CLI: `extract.sh steps|roles|block <doc> [<step>] [<role>]`.

- [ ] **Step 1: Write the conformant fixture**

Create `reference-implementations/migration-runner/test-fixtures/conformant.md`:

````markdown
---
id: 0016
slug: conformant-fixture
title: A conformant executable migration
from_version: 1.2.0
to_version: 1.3.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0016 — conformant fixture

## Steps

### Step 1: Create the marker file

Prose explaining why. For contrast, the old shape was:

```bash
# illustration only — no role=, never executed
echo "DO NOT RUN ME" > tripwire.txt
```

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```

**Verify:**
```bash role=verify
grep -q '^applied$' fixture.txt
```

**Rollback:**
```bash role=rollback
rm -f fixture.txt
```

### Step 2: Append a second line

**Idempotency check:**
```bash role=check
grep -q '^second$' fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -f fixture.txt
```

**Apply:**
```bash role=apply
echo "second" >> fixture.txt
```

**Rollback:**
```bash role=rollback
grep -v '^second$' fixture.txt > fixture.tmp && mv fixture.tmp fixture.txt
```
````

- [ ] **Step 2: Write the failing tests**

Create `tools/migration-runner.test.sh`:

```bash
#!/usr/bin/env bash
# migration-runner.test.sh — tests for reference-implementations/migration-runner/
#
# Drives each script through its public interface against fixtures in a temp
# dir. No network, no writes outside the temp dir.
#
# Usage: tools/migration-runner.test.sh
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MR="$ROOT/reference-implementations/migration-runner"
FIX="$MR/test-fixtures"

pass=0
fail=0

assert_eq() { # $1=actual $2=expected $3=description
  if [ "$1" = "$2" ]; then
    echo "  PASS  $3"; pass=$((pass + 1))
  else
    echo "  FAIL  $3"
    echo "        expected: [$2]"
    echo "        actual:   [$1]"
    fail=$((fail + 1))
  fi
}

assert_contains() { # $1=haystack $2=needle $3=description
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  PASS  $3"; pass=$((pass + 1))
  else
    echo "  FAIL  $3"
    echo "        expected output to contain: $2"
    echo "        actual: $1"
    fail=$((fail + 1))
  fi
}

assert_not_contains() { # $1=haystack $2=needle $3=description
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  FAIL  $3"
    echo "        expected output NOT to contain: $2"
    fail=$((fail + 1))
  else
    echo "  PASS  $3"; pass=$((pass + 1))
  fi
}

echo "== extract.sh =="

out="$(bash "$MR/extract.sh" steps "$FIX/conformant.md")"
assert_eq "$out" "$(printf '1\n2')" "steps lists both steps in order"

out="$(bash "$MR/extract.sh" roles "$FIX/conformant.md" 1)"
assert_eq "$out" "$(printf 'check\nprecondition\napply\nverify\nrollback')" \
  "roles lists step 1's five roles in document order"

out="$(bash "$MR/extract.sh" roles "$FIX/conformant.md" 2)"
assert_eq "$out" "$(printf 'check\nprecondition\napply\nrollback')" \
  "roles omits verify where absent"

out="$(bash "$MR/extract.sh" block "$FIX/conformant.md" 1 apply)"
assert_eq "$out" 'echo "applied" > fixture.txt' "block returns step 1 apply body"

out="$(bash "$MR/extract.sh" block "$FIX/conformant.md" 2 apply)"
assert_eq "$out" 'echo "second" >> fixture.txt' "block scopes to step 2, not step 1"

# The illustration guard: an un-annotated bash fence must be invisible.
out="$(bash "$MR/extract.sh" roles "$FIX/conformant.md" 1)"
assert_not_contains "$out" "tripwire" "un-annotated fence contributes no role"
out="$(bash "$MR/extract.sh" block "$FIX/conformant.md" 1 apply)"
assert_not_contains "$out" "DO NOT RUN ME" "un-annotated fence is not returned as a block"

bash "$MR/extract.sh" block "$FIX/conformant.md" 2 verify >/dev/null 2>&1
assert_eq "$?" "1" "block exits 1 for an absent role"

echo
echo "TOTAL: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash tools/migration-runner.test.sh`
Expected: every assertion FAILs, because `extract.sh` does not exist. You should see `No such file or directory` and a non-zero total.

- [ ] **Step 4: Write the extractor**

Create `reference-implementations/migration-runner/extract.sh`:

```bash
#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# extract.sh — pull role-tagged fenced blocks out of a migration document.
#
# WHY THIS EXISTS AND WHAT IT REPLACES. codex-workflow's run-tests.sh carries
# extract_step_block(), which finds the first fence after a `**Label:**` marker.
# That is kept, and this is not a rewrite of it: the labels still structure the
# document. What labels cannot express is that a fence is ILLUSTRATION. This
# reads the role tag, so an un-annotated ```bash block is invisible to it.
#
# TWO PROPERTIES PORTED DELIBERATELY from extract_step_block(), because both
# were defects found under review there and would otherwise be re-introduced:
#
#   1. DELIMITER GUARD. `index($0, "### Step 1") == 1` also prefix-matches
#      "### Step 10" through "### Step 19". A document with ten or more steps
#      would latch onto the wrong step. delim_ok() requires the character after
#      the matched prefix to be ':', ' ', or end-of-line.
#
#   2. LITERAL PREFIX, NEVER AN INTERPOLATED REGEX. Step and role arrive as awk
#      -v variables and are compared with index()/string equality, never spliced
#      into a /.../ regex. There is nothing to escape and nothing to inject.
#
# Usage:
#   extract.sh steps <doc>                 -> step numbers, one per line
#   extract.sh roles <doc> <step>          -> roles present, one per line
#   extract.sh block <doc> <step> <role>   -> block body; exit 1 if absent

set -uo pipefail

mr_steps() {
  awk '
    index($0, "### Step ") == 1 {
      rest = substr($0, 10); n = ""
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c >= "0" && c <= "9") n = n c; else break
      }
      if (n != "") print n + 0
    }
  ' "$1"
}

mr_roles() {
  local doc="$1" step="$2"
  awk -v stepp="### Step ${step}" '
    function delim_ok(line, plen,   d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    # ANY step heading ends the previous step. Bounding on "the next step
    # heading" rather than on "the heading numbered N+1" means a gap in the
    # numbering cannot merge two steps and hide the second one'"'"'s roles from
    # both the linter and the runner.
    index($0, "### Step ") == 1 {
      in_step = (index($0, stepp) == 1 && delim_ok($0, length(stepp)))
      next
    }
    !in_step { next }
    inb && index($0, "```") == 1 { inb = 0; next }
    inb { next }
    index($0, "```") == 1 {
      inb = 1
      info = substr($0, 4); sub(/[ \t]+$/, "", info)
      # EXACT GRAMMAR: literal bash, whitespace, role=, a lowercase role name,
      # then end of string. An info-string carrying extra keys is NOT a tagged
      # fence — it falls through to the linter as a violation rather than being
      # silently honoured with its extra keys ignored.
      if (info ~ /^bash[ \t]+role=[a-z]+$/) { sub(/^bash[ \t]+role=/, "", info); print info }
      next
    }
  ' "$doc"
}

mr_block() {
  local doc="$1" step="$2" role="$3" out
  out="$(awk -v stepp="### Step ${step}" -v want="$role" '
    function delim_ok(line, plen,   d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    index($0, "### Step ") == 1 {
      in_step = (index($0, stepp) == 1 && delim_ok($0, length(stepp)))
      next
    }
    !in_step { next }
    inother && index($0, "```") == 1 { inother = 0; next }
    inother { next }
    inb && index($0, "```") == 1 { found = 1; exit }
    inb { print; next }
    index($0, "```") == 1 {
      info = substr($0, 4); sub(/[ \t]+$/, "", info); r = ""
      if (info ~ /^bash[ \t]+role=[a-z]+$/) { r = info; sub(/^bash[ \t]+role=/, "", r) }
      if (r == want) inb = 1; else inother = 1
      next
    }
    END { if (!found) exit 1 }
  ' "$doc")" || return 1
  printf '%s\n' "$out"
}

# CLI
case "${1:-}" in
  steps) mr_steps "$2" ;;
  roles) mr_roles "$2" "$3" ;;
  block) mr_block "$2" "$3" "$4" ;;
  *) echo "usage: extract.sh steps|roles|block <doc> [<step>] [<role>]" >&2; exit 64 ;;
esac
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tools/migration-runner.test.sh`
Expected: `TOTAL: 8 passed, 0 failed`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add reference-implementations/migration-runner/extract.sh \
        reference-implementations/migration-runner/test-fixtures/conformant.md \
        tools/migration-runner.test.sh
git commit -m "feat(migration-runner): role-tagged fence extractor

Ports the delimiter guard and literal-prefix matching from codex's
extract_step_block(); both were defects found under review there.
The un-annotated fence in the fixture is a tripwire: if it is ever
executed or reported as a role, a test goes red."
```

---

### Task 2: Linter — structural rules L1, L3, L5

**Files:**
- Create: `reference-implementations/migration-runner/lint-migration.sh`
- Create: `reference-implementations/migration-runner/test-fixtures/bad-l1-missing-rollback.md`
- Create: `reference-implementations/migration-runner/test-fixtures/bad-l3-duplicate-apply.md`
- Create: `reference-implementations/migration-runner/test-fixtures/bad-l5-role-on-yaml.md`
- Modify: `tools/migration-runner.test.sh` (append a `== lint-migration.sh ==` section)

**Interfaces:**
- Consumes: `extract.sh`'s `mr_steps` and `mr_roles`, sourced.
- Produces: `lint-migration.sh <doc>` → exit 0 clean, exit 1 with one `L<n>: step <s>: <message>` line per violation on stderr.

- [ ] **Step 1: Write the three broken fixtures**

`bad-l1-missing-rollback.md` — same frontmatter as `conformant.md` but `id: 0017`, `slug: bad-l1`, and a single step carrying `check`, `precondition` and `apply` only:

````markdown
---
id: 0017
slug: bad-l1
title: Missing rollback
from_version: 1.3.0
to_version: 1.4.0
migration_format: executable
applies_to:
  - fixture.txt
---

# Migration 0017 — missing rollback

## Steps

### Step 1: Apply without a way back

**Idempotency check:**
```bash role=check
test -f fixture.txt
```

**Pre-condition:**
```bash role=precondition
test -d .
```

**Apply:**
```bash role=apply
echo "applied" > fixture.txt
```
````

`bad-l3-duplicate-apply.md` — `id: 0018`, `slug: bad-l3`, one step with the full quartet **plus a second `**Apply:**` heading and `role=apply` fence** containing `echo "twice" >> fixture.txt`.

`bad-l5-role-on-yaml.md` — `id: 0019`, `slug: bad-l5`, one step with the full quartet, plus an extra fence opened as ```` ```yaml role=apply ```` containing `key: value`.

- [ ] **Step 2: Write the failing tests**

Append to `tools/migration-runner.test.sh`, before the `TOTAL` block:

```bash
echo
echo "== lint-migration.sh: structural rules =="

out="$(bash "$MR/lint-migration.sh" "$FIX/conformant.md" 2>&1)"
assert_eq "$?" "0" "L1/L3/L5: conformant fixture passes"

out="$(bash "$MR/lint-migration.sh" "$FIX/bad-l1-missing-rollback.md" 2>&1)"
assert_eq "$?" "1" "L1: missing rollback exits 1"
assert_contains "$out" "L1" "L1: names the rule"
assert_contains "$out" "rollback" "L1: names the missing role"

out="$(bash "$MR/lint-migration.sh" "$FIX/bad-l3-duplicate-apply.md" 2>&1)"
assert_eq "$?" "1" "L3: duplicate apply exits 1"
assert_contains "$out" "L3" "L3: names the rule"

out="$(bash "$MR/lint-migration.sh" "$FIX/bad-l5-role-on-yaml.md" 2>&1)"
assert_eq "$?" "1" "L5: role= on a yaml fence exits 1"
assert_contains "$out" "L5" "L5: names the rule"
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash tools/migration-runner.test.sh`
Expected: the eight extractor assertions still PASS; the eight new ones FAIL because `lint-migration.sh` does not exist.

- [ ] **Step 4: Write the linter's structural rules**

Create `reference-implementations/migration-runner/lint-migration.sh`:

```bash
#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# lint-migration.sh — enforce the executable migration format.
#
# L1  every step has exactly one check, precondition, apply, rollback;
#     verify is 0 or 1
# L2  each role= fence sits under its matching **Label:** heading
# L3  no duplicate roles within a step
# L4  unknown role values are rejected
# L5  role= appears only on bash fences
#
# L4 IS LOAD-BEARING. Un-annotated fences are illustration, so a typo
# (role=aply) silently demotes a real command to a comment and the runner
# reports success having done nothing. That is the same defect class as an
# untrusted hook that loads nothing: installed, looks correct, enforces
# nothing. Do not relax it into a warning.
#
# Usage: lint-migration.sh <doc>
# Exit 0 = clean. Exit 1 = one `L<n>: step <s>: <message>` line per violation.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
DOC="${1:?usage: lint-migration.sh <doc>}"

violations=0
report() { echo "$*" >&2; violations=$((violations + 1)); }

REQUIRED="check precondition apply rollback"
VALID="check precondition apply verify rollback"

steps="$(bash "$SCRIPT_DIR/extract.sh" steps "$DOC")"

for s in $steps; do
  roles="$(bash "$SCRIPT_DIR/extract.sh" roles "$DOC" "$s")"

  # L1 — every required role present
  for r in $REQUIRED; do
    printf '%s\n' "$roles" | grep -qx "$r" || \
      report "L1: step $s: missing required role '$r'"
  done

  # L1 — verify appears at most once (duplicates are L3's problem)
  # L3 — no duplicates of anything
  dupes="$(printf '%s\n' "$roles" | awk 'NF' | sort | uniq -d)"
  for d in $dupes; do
    report "L3: step $s: role '$d' appears more than once"
  done
done

# L5 — role= only on bash fences
awk -v doc="$DOC" '
  index($0, "```") == 1 {
    info = substr($0, 4); sub(/[ \t]+$/, "", info)
    if (info ~ /role=/ && info !~ /^bash[ \t]+role=/)
      printf "L5: %s:%d: role= on a non-bash fence: %s\n", doc, NR, info
  }
' "$DOC" >/tmp/mr-l5.$$ 2>/dev/null
if [ -s /tmp/mr-l5.$$ ]; then
  while IFS= read -r line; do report "$line"; done < /tmp/mr-l5.$$
fi
rm -f /tmp/mr-l5.$$

[ "$violations" -eq 0 ]
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tools/migration-runner.test.sh`
Expected: `TOTAL: 16 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add reference-implementations/migration-runner/lint-migration.sh \
        reference-implementations/migration-runner/test-fixtures/bad-l1-missing-rollback.md \
        reference-implementations/migration-runner/test-fixtures/bad-l3-duplicate-apply.md \
        reference-implementations/migration-runner/test-fixtures/bad-l5-role-on-yaml.md \
        tools/migration-runner.test.sh
git commit -m "feat(migration-runner): linter structural rules L1, L3, L5"
```

---

### Task 3: Linter — L2 label agreement, L4 unknown roles, ID threshold

**Files:**
- Modify: `reference-implementations/migration-runner/lint-migration.sh`
- Create: `reference-implementations/migration-runner/test-fixtures/bad-l2-wrong-heading.md`
- Create: `reference-implementations/migration-runner/test-fixtures/bad-l4-typo-role.md`
- Create: `reference-implementations/migration-runner/test-fixtures/bad-threshold-no-frontmatter.md`
- Modify: `tools/migration-runner.test.sh`

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces: `lint-migration.sh [--threshold N] <doc>`. With `--threshold`, a document whose `id` is ≥ N must carry `migration_format: executable`; a document below N is skipped entirely and exits 0.

- [ ] **Step 1: Write the three broken fixtures**

`bad-l2-wrong-heading.md` — `id: 0020`, `slug: bad-l2`, full quartet, but the `role=apply` fence sits under `**Rollback:**` and the `role=rollback` fence under `**Apply:**` (headings and tags swapped).

`bad-l4-typo-role.md` — `id: 0021`, `slug: bad-l4`, full quartet except the apply fence is opened as ```` ```bash role=aply ````. **This is the fixture that matters most** — without L4 it lints clean, because a misspelled role is indistinguishable from illustration.

`bad-threshold-no-frontmatter.md` — `id: 0022`, `slug: bad-threshold`, a complete and otherwise conformant step, but **no `migration_format:` line in frontmatter.**

- [ ] **Step 2: Write the failing tests**

Append to `tools/migration-runner.test.sh`:

```bash
echo
echo "== lint-migration.sh: agreement, typos, threshold =="

out="$(bash "$MR/lint-migration.sh" "$FIX/bad-l2-wrong-heading.md" 2>&1)"
assert_eq "$?" "1" "L2: swapped headings exit 1"
assert_contains "$out" "L2" "L2: names the rule"

out="$(bash "$MR/lint-migration.sh" "$FIX/bad-l4-typo-role.md" 2>&1)"
assert_eq "$?" "1" "L4: role=aply exits 1"
assert_contains "$out" "L4" "L4: names the rule"
assert_contains "$out" "aply" "L4: quotes the offending value back"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/bad-threshold-no-frontmatter.md" 2>&1)"
assert_eq "$?" "1" "threshold: id 0022 >= 16 without migration_format exits 1"
assert_contains "$out" "migration_format" "threshold: names the missing field"

out="$(bash "$MR/lint-migration.sh" --threshold 99 "$FIX/bad-l1-missing-rollback.md" 2>&1)"
assert_eq "$?" "0" "threshold: id 0017 < 99 is skipped entirely, even though it breaks L1"

out="$(bash "$MR/lint-migration.sh" --threshold 16 "$FIX/conformant.md" 2>&1)"
assert_eq "$?" "0" "threshold: conformant fixture at id 0016 passes"
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash tools/migration-runner.test.sh`
Expected: the 16 earlier assertions PASS; the 9 new ones FAIL.

Pay attention to `bad-l4-typo-role.md`: before L4 exists it exits **0**, which is the whole reason the rule is there. Confirm you see that before implementing.

- [ ] **Step 4: Add the threshold gate and L2/L4 to the linter**

In `lint-migration.sh`, replace the `DOC=` line with argument parsing:

```bash
THRESHOLD=""
while [ $# -gt 0 ]; do
  case "$1" in
    --threshold) THRESHOLD="${2:?--threshold needs a value}"; shift 2 ;;
    --host)
      # Resolve from the declared file rather than making every caller
      # remember a number. THRESHOLDS is core's declaration, one row per host.
      _h="${2:?--host needs a value}"; shift 2
      THRESHOLD="$(sed 's/#.*//' "$SCRIPT_DIR/THRESHOLDS" | awk -v h="$_h" '$1 == h { print $2; exit }')"
      [ -n "$THRESHOLD" ] || { echo "lint: no threshold declared for host '$_h'" >&2; exit 65; }
      ;;
    *) DOC="$1"; shift ;;
  esac
done
: "${DOC:?usage: lint-migration.sh [--threshold N | --host NAME] <doc>}"

# THE ID COMES FROM THE FILENAME, NEVER FROM FRONTMATTER.
#
# The ID threshold was chosen over a frontmatter declaration precisely because
# a filename cannot be forgotten. A linter that then reads frontmatter throws
# that away: delete one `id:` line and the file is skipped entirely. That was a
# real defect in this plan's first draft, found by the Stage 2 review, and the
# fixture bad-no-frontmatter-id.md is the regression guard. Do not "simplify"
# this back to reading frontmatter.
base="$(basename "$DOC")"
file_id="$(printf '%s' "$base" | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p')"
if [ -z "$file_id" ]; then
  echo "lint: $DOC: filename does not begin with a numeric migration ID" >&2
  exit 1
fi

fm_fmt="$(awk -F': *' '/^migration_format:/ { print $2; exit }' "$DOC" | tr -d '[:space:]')"

# In scope if the filename says so. A declaration may ADD a migration to scope
# but never remove one — opting in is always allowed, opting out is not
# expressible.
in_scope=0
above=0
if [ -n "$THRESHOLD" ] && [ "$((10#$file_id))" -ge "$((10#$THRESHOLD))" ]; then
  above=1; in_scope=1
fi
[ "$fm_fmt" = "executable" ] && in_scope=1

# Below the threshold and not opted in, this document predates the executable
# format. It is frozen history — skip it rather than reporting violations
# nobody will ever fix. Retrofit scope is deliberately zero.
if [ "$in_scope" -eq 0 ]; then
  if [ -n "$fm_fmt" ]; then
    echo "L0: $DOC: unknown migration_format value '$fm_fmt'" >&2
    exit 1
  fi
  exit 0
fi

if [ -n "$fm_fmt" ] && [ "$fm_fmt" != "executable" ]; then
  report "L0: $DOC: unknown migration_format value '$fm_fmt'"
fi
if [ "$above" -eq 1 ] && [ "$fm_fmt" != "executable" ]; then
  report "threshold: $DOC: id $file_id is at or above threshold $THRESHOLD but frontmatter does not declare migration_format: executable"
fi
```

Then add L2 and L4 inside the per-step loop, after the L3 block:

```bash
  # L2 + L4 — one pass, tracking the most recent **Label:** heading.
  bad="$(awk -v stepp="### Step ${s}" -v nextp="### Step $((s + 1))" '
    function delim_ok(line, plen,   d) {
      d = substr(line, plen + 1, 1)
      return (d == "" || d == ":" || d == " ")
    }
    BEGIN {
      want["check"]        = "**Idempotency check:**"
      want["precondition"] = "**Pre-condition:**"
      want["apply"]        = "**Apply:**"
      want["verify"]       = "**Verify:**"
      want["rollback"]     = "**Rollback:**"
    }
    index($0, stepp) == 1 && delim_ok($0, length(stepp)) { in_step = 1; next }
    index($0, nextp) == 1 && delim_ok($0, length(nextp)) { in_step = 0 }
    !in_step { next }
    inb && index($0, "```") == 1 { inb = 0; next }
    inb { next }
    index($0, "**") == 1 { label = $0; sub(/[ \t]+$/, "", label); next }
    index($0, "```") == 1 {
      inb = 1
      info = substr($0, 4); sub(/[ \t]+$/, "", info)
      if (info !~ /^bash[ \t]+role=/) next
      r = info; sub(/^bash[ \t]+role=/, "", r)
      if (!(r in want)) { printf "L4|%s\n", r; next }
      if (label != want[r]) printf "L2|%s|%s|%s\n", r, want[r], label
      next
    }
  ' "$DOC")"

  while IFS='|' read -r rule a b c; do
    [ -n "$rule" ] || continue
    case "$rule" in
      L4) report "L4: step $s: unknown role '$a' — valid roles are $VALID" ;;
      L2) report "L2: step $s: role '$a' expects heading $b but follows $c" ;;
    esac
  done <<EOF
$bad
EOF
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tools/migration-runner.test.sh`
Expected: `TOTAL: 25 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add reference-implementations/migration-runner/lint-migration.sh \
        reference-implementations/migration-runner/test-fixtures/ \
        tools/migration-runner.test.sh
git commit -m "feat(migration-runner): L2 label agreement, L4 unknown roles, ID threshold

L4 is the rule that earns the format. Before it, bad-l4-typo-role.md lints
clean at exit 0 — a misspelled role is indistinguishable from illustration,
so the runner would report success having executed nothing."
```

---

### Task 4: Runner — the happy path

**Files:**
- Create: `reference-implementations/migration-runner/run-migration.sh`
- Modify: `tools/migration-runner.test.sh`

**Interfaces:**
- Consumes: `extract.sh`.
- Produces: `run-migration.sh [--dry-run] [--on-failure=abort|prompt|skip] <doc> [<workdir>]`. Runs each step in `<workdir>` (default `.`). Exit 0 all steps applied or skipped; exit 1 a step failed.

- [ ] **Step 1: Write the failing tests**

Append to `tools/migration-runner.test.sh`:

```bash
echo
echo "== run-migration.sh: happy path =="

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/conformant.md" "$tmp" 2>&1)"
rc=$?
assert_eq "$rc" "0" "conformant migration applies cleanly"
assert_eq "$(cat "$tmp/fixture.txt")" "$(printf 'applied\nsecond')" "both steps applied in order"
assert_contains "$out" "step 1" "reports step 1"
assert_contains "$out" "step 2" "reports step 2"
assert_eq "$(ls "$tmp"/tripwire.txt 2>/dev/null; echo done)" "done" \
  "illustration fence was never executed"

# Idempotency: the second run must apply nothing.
out="$(cd "$tmp" && bash "$MR/run-migration.sh" "$FIX/conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "second run exits 0"
assert_contains "$out" "skipped" "second run reports skipped"
assert_eq "$(cat "$tmp/fixture.txt")" "$(printf 'applied\nsecond')" "second run changed nothing"
rm -rf "$tmp"; trap - EXIT

echo
echo "== run-migration.sh: dry-run =="

# §08 requires dry-run to run check + precondition and print the apply SOURCE,
# writing nothing. A dry run cannot show a real diff without applying the step.
tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" --dry-run "$FIX/conformant.md" "$tmp" 2>&1)"
assert_eq "$?" "0" "dry-run exits 0"
assert_contains "$out" 'echo "applied" > fixture.txt' "dry-run prints the apply source"
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo none)" "none" "dry-run wrote nothing"
rm -rf "$tmp"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tools/migration-runner.test.sh`
Expected: the 25 earlier assertions PASS; the 11 new FAIL — `run-migration.sh` does not exist.

- [ ] **Step 3: Write the runner**

Create `reference-implementations/migration-runner/run-migration.sh`:

```bash
#!/usr/bin/env bash
# migration-runner-version: 0.1.0
# run-migration.sh — apply an executable migration.
#
# Per step, in order:
#   check        exit 0 => already applied; skip the step
#   precondition non-zero => abort. THE BLOCK'S OWN STDERR IS REPRODUCED
#                VERBATIM, never paraphrased — 0001 exits 3 with a two-option
#                remediation message and that message is the useful output.
#   apply        non-zero => failure policy
#   verify       optional; non-zero => failure policy
#
# FAILURE POLICY (spec §08, as amended):
#   TTY      -> prompt: retry / skip-with-warning / rollback
#   non-TTY  -> abort in place, report what applied, ROLL BACK NOTHING.
#
# Rolling back unattended was considered and rejected: the absence of anyone to
# ask is not consent, and a half-applied tree is evidence a rollback destroys.
# CONSEQUENCE: role=rollback never runs unattended. It is exercised by its own
# fixtures, not by this path. See the design note.
#
# Usage: run-migration.sh [--dry-run] [--on-failure=abort|prompt|skip] <doc> [<workdir>]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT="$SCRIPT_DIR/extract.sh"

DRY_RUN=0
ON_FAILURE=""
DOC=""
WORKDIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --on-failure=*) ON_FAILURE="${1#*=}"; shift ;;
    *) if [ -z "$DOC" ]; then DOC="$1"; else WORKDIR="$1"; fi; shift ;;
  esac
done
: "${DOC:?usage: run-migration.sh [--dry-run] [--on-failure=P] <doc> [<workdir>]}"
WORKDIR="${WORKDIR:-.}"

if [ -z "$ON_FAILURE" ]; then
  if [ -t 0 ]; then ON_FAILURE="prompt"; else ON_FAILURE="abort"; fi
fi

applied=""
partial=0

run_block() { # $1=step $2=role ; returns the block's exit code, stderr passthrough
  local body
  body="$(bash "$EXTRACT" block "$DOC" "$1" "$2" 2>/dev/null)" || return 127
  ( cd "$WORKDIR" && bash -c "$body" )
}

has_role() { bash "$EXTRACT" roles "$DOC" "$1" | grep -qx "$2"; }

# LINT BEFORE EXECUTING ANYTHING.
#
# Rejecting a bad migration at lint time is not enough on its own, because
# nothing obliges the operator to have linted. A runner that executes whatever
# it is given can be handed an all-illustration document and report success
# having changed nothing — the exact failure this format exists to prevent, and
# worst when the silently-skipped step was the security-relevant one. The Stage
# 2 review found this hole; all-illustration.md is the regression guard.
if ! bash "$SCRIPT_DIR/lint-migration.sh" ${LINT_HOST:+--host "$LINT_HOST"} "$DOC"; then
  echo "refusing to run: $DOC does not satisfy the executable format" >&2
  exit 1
fi

steps="$(bash "$EXTRACT" steps "$DOC")"
if [ -z "$steps" ]; then
  echo "refusing to run: $DOC declares no steps" >&2
  exit 1
fi
for s in $steps; do
  if [ -z "$(bash "$EXTRACT" block "$DOC" "$s" apply 2>/dev/null)" ]; then
    echo "refusing to run: $DOC step $s has no apply block" >&2
    exit 1
  fi
done

fail_policy() { # $1 = failing step ; returns 0 to continue, 1 to abort
  case "$ON_FAILURE" in
    abort)
      echo "applied steps:${applied:- none}" >&2
      echo "step $1 left in place. Nothing was rolled back — inspect before re-running." >&2
      return 1
      ;;
    skip)
      echo "step $1: skipped with warning (migration is partial)" >&2
      partial=1
      return 0
      ;;
    prompt)
      echo "step $1 failed. [r]etry / [s]kip / [b]ack out steps${applied:- none}?" >&2
      read -r choice
      case "$choice" in
        r) RETRY=1; return 0 ;;
        s) partial=1; return 0 ;;
        # Reverse document order: a later step may depend on an earlier one, so
        # undoing forwards can leave the tree in a state no rollback expected.
        # The FAILED step is deliberately absent from $applied — a step that
        # died part-way through apply is in an unknown state, and running its
        # rollback could destroy work the rollback did not create.
        *) for d in $(echo "$applied" | tr ' ' '\n' | tail -r 2>/dev/null || echo "$applied" | tr ' ' '\n' | tac); do
             [ -n "$d" ] && run_block "$d" rollback || true
           done
           return 1 ;;
      esac
      ;;
  esac
}

for s in $steps; do
  # THREE-VALUED CHECK: 0 = applied, 1 = not applied, anything else = the check
  # itself could not run. Conflating the last two silently re-applies a step
  # whose state is unknown.
  run_block "$s" check >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "step $s: skipped (already applied)"
    continue
  elif [ "$rc" -ne 1 ]; then
    echo "step $s: idempotency check could not run (exit $rc) — aborting" >&2
    exit 1
  fi

  # A failed pre-condition ALWAYS hard-aborts, terminal or not. It means the
  # migration's assumptions about the tree do not hold; retrying cannot change
  # that, and skipping would apply a step whose assumptions are violated. The
  # interactive policy governs apply and verify only.
  if ! run_block "$s" precondition; then
    echo "step $s: pre-condition failed — aborting" >&2
    exit 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "step $s: would apply:"
    bash "$EXTRACT" block "$DOC" "$s" apply | sed 's/^/    /'
    continue
  fi

  RETRY=1
  while [ "$RETRY" -eq 1 ]; do
    RETRY=0
    if ! run_block "$s" apply; then
      echo "step $s: apply failed" >&2
      fail_policy "$s" || exit 1
      [ "$RETRY" -eq 1 ] && continue
      continue 2
    fi
    if has_role "$s" verify && ! run_block "$s" verify; then
      # The step is NOT recorded as applied: apply ran, but its result is not
      # what the migration said it should be.
      echo "step $s: verify failed" >&2
      fail_policy "$s" || exit 1
      [ "$RETRY" -eq 1 ] && continue
      continue 2
    fi
  done

  applied="$applied $s"
  echo "step $s: applied"
done

[ "$partial" -eq 1 ] && echo "migration is partial" >&2
exit 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tools/migration-runner.test.sh`
Expected: `TOTAL: 36 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add reference-implementations/migration-runner/run-migration.sh tools/migration-runner.test.sh
git commit -m "feat(migration-runner): apply/check/verify happy path with idempotent re-run"
```

---

### Task 5: Runner — A2 failure policy and verbatim pre-condition stderr

**Files:**
- Create: `reference-implementations/migration-runner/test-fixtures/failing-apply.md`
- Create: `reference-implementations/migration-runner/test-fixtures/failing-precondition.md`
- Modify: `tools/migration-runner.test.sh`

**Interfaces:**
- Consumes: `run-migration.sh` from Task 4.
- Produces: no new interface — this task proves the A2 contract holds.

- [ ] **Step 1: Write the two fixtures**

`failing-apply.md` — `id: 0023`, `migration_format: executable`, **two** steps. Step 1 is the same as `conformant.md`'s step 1 (it succeeds). Step 2 has a check that fails (`test -f never.txt`), a passing pre-condition, and an apply of `exit 7`, plus a rollback of `rm -f fixture.txt`.

`failing-precondition.md` — `id: 0024`, `migration_format: executable`, one step whose pre-condition is:

````markdown
**Pre-condition:**
```bash role=precondition
echo "cparx: unmanaged prose at line 42. Either (a) move it above the marker," >&2
echo "or (b) re-run with --adopt to take ownership." >&2
exit 3
```
````

- [ ] **Step 2: Write the failing tests**

```bash
echo
echo "== run-migration.sh: A2 failure policy =="

tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" --on-failure=abort "$FIX/failing-apply.md" "$tmp" 2>&1)"
assert_eq "$?" "1" "A2: failing apply exits 1"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "applied" \
  "A2: step 1's work SURVIVES — nothing was rolled back"
assert_contains "$out" "Nothing was rolled back" "A2: says so explicitly"
assert_contains "$out" "applied steps: 1" "A2: names which steps applied"
rm -rf "$tmp"

# Non-TTY defaults to abort without being told.
tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" "$FIX/failing-apply.md" "$tmp" </dev/null 2>&1)"
assert_eq "$?" "1" "A2: non-TTY exits 1 with no --on-failure"
assert_eq "$(cat "$tmp/fixture.txt" 2>/dev/null)" "applied" "A2: non-TTY rolls back nothing"
rm -rf "$tmp"

tmp="$(mktemp -d)"
out="$(bash "$MR/run-migration.sh" "$FIX/failing-precondition.md" "$tmp" </dev/null 2>&1)"
assert_eq "$?" "1" "pre-condition failure exits 1"
assert_contains "$out" "unmanaged prose at line 42" "stderr reaches the caller verbatim"
assert_contains "$out" "(b) re-run with --adopt" "the remediation's second option survives too"
rm -rf "$tmp"
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bash tools/migration-runner.test.sh`
Expected: the 36 earlier PASS; the 9 new FAIL because the fixtures do not exist yet, and possibly because `fail_policy` does not yet print `applied steps:` in the exact asserted form.

- [ ] **Step 4: Make them pass**

Create the fixtures. Adjust `fail_policy`'s `abort` arm so the output matches the assertions exactly — `applied steps: 1` (single space, no leading blank), and the literal sentence `Nothing was rolled back — inspect before re-running.`

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tools/migration-runner.test.sh`
Expected: `TOTAL: 45 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add reference-implementations/migration-runner/test-fixtures/failing-apply.md \
        reference-implementations/migration-runner/test-fixtures/failing-precondition.md \
        reference-implementations/migration-runner/run-migration.sh \
        tools/migration-runner.test.sh
git commit -m "test(migration-runner): A2 leaves the tree half-applied, verbatim precondition stderr

The surviving fixture.txt is the assertion that matters: absence of anyone to
ask is not consent, and the half-applied tree is the evidence."
```

---

### Task 6: Rollback fixtures — the blocks the runner never reaches

**Files:**
- Modify: `tools/migration-runner.test.sh`

**Interfaces:**
- Consumes: `extract.sh`, `conformant.md`.
- Produces: nothing new. This closes the gap A2 opens.

- [ ] **Step 1: Write the tests**

Under A2 the runner never executes `rollback` unattended, so it needs testing directly against each step's post-apply state.

```bash
echo
echo "== rollback blocks, exercised directly =="

# Step 1: apply, then roll back, and assert we are back where we started.
tmp="$(mktemp -d)"
( cd "$tmp" && bash -c "$(bash "$MR/extract.sh" block "$FIX/conformant.md" 1 apply)" )
assert_eq "$(cat "$tmp/fixture.txt")" "applied" "step 1 apply produced its state"
( cd "$tmp" && bash -c "$(bash "$MR/extract.sh" block "$FIX/conformant.md" 1 rollback)" )
assert_eq "$(ls "$tmp"/fixture.txt 2>/dev/null; echo gone)" "gone" "step 1 rollback undid it"
rm -rf "$tmp"

# Step 2: apply both, roll back only step 2, assert step 1 survives.
tmp="$(mktemp -d)"
( cd "$tmp" && bash -c "$(bash "$MR/extract.sh" block "$FIX/conformant.md" 1 apply)" )
( cd "$tmp" && bash -c "$(bash "$MR/extract.sh" block "$FIX/conformant.md" 2 apply)" )
assert_eq "$(cat "$tmp/fixture.txt")" "$(printf 'applied\nsecond')" "both steps applied"
( cd "$tmp" && bash -c "$(bash "$MR/extract.sh" block "$FIX/conformant.md" 2 rollback)" )
assert_eq "$(cat "$tmp/fixture.txt")" "applied" "step 2 rollback is surgical — step 1 survives"
rm -rf "$tmp"

# Every step in the conformant fixture declares a rollback, and none is empty.
for s in $(bash "$MR/extract.sh" steps "$FIX/conformant.md"); do
  body="$(bash "$MR/extract.sh" block "$FIX/conformant.md" "$s" rollback)"
  if [ -n "${body//[[:space:]]/}" ]; then
    echo "  PASS  step $s declares a non-empty rollback"; pass=$((pass + 1))
  else
    echo "  FAIL  step $s rollback is empty"; fail=$((fail + 1))
  fi
done
```

Note the emptiness check strips whitespace before testing. `assert_contains
"$body" ""` would be worse than useless — an empty needle matches everything, so
it passes for an empty rollback, which is the exact case this is here to catch.

- [ ] **Step 2: Run the tests**

Run: `bash tools/migration-runner.test.sh`
Expected: `TOTAL: 51 passed, 0 failed`. These should pass immediately — the fixtures already carry correct rollbacks. If any fails, the fixture's rollback is wrong, which is exactly the rot this task exists to catch.

- [ ] **Step 3: Commit**

```bash
git add tools/migration-runner.test.sh
git commit -m "test(migration-runner): exercise rollback blocks directly

A2 means the runner never reaches rollback unattended, which would make it the
least-tested block in every migration. These run each one against its own
step's post-apply state instead."
```

---

### Task 7: Revise spec §08

**Files:**
- Modify: `spec/08-migration-format.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the normative contract the three scripts implement.

- [ ] **Step 1: Bump the version**

Change frontmatter `spec_version: 0.9.1` → `spec_version: 0.10.0`.

- [ ] **Step 2: Extend the step-structure section**

After the existing four-row table at `spec/08-migration-format.md:84-89`, add:

```markdown
### Executable form

Migrations at or above a host's declared **executable threshold** MUST express
each step's four sections as role-tagged fenced code blocks, and MUST declare
`migration_format: executable` in frontmatter.

| Role | Heading it MUST follow |
|---|---|
| `check` | `**Idempotency check:**` |
| `precondition` | `**Pre-condition:**` |
| `apply` | `**Apply:**` |
| `verify` (optional) | `**Verify:**` |
| `rollback` | `**Rollback:**` |

A block is tagged in the fence info-string: ```` ```bash role=apply ````.

- **MUST NOT** execute an un-annotated ```` ```bash ```` fence. Un-annotated
  fences are illustration, and this is what lets a migration keep explanatory
  snippets beside the commands it runs.
- **MUST** reject an unrecognised role value rather than ignoring it. Because
  un-annotated fences are illustration, a misspelled role would otherwise
  silently demote a real command to a comment, and the runner would report
  success having done nothing.
- **MUST** declare the host's executable threshold in the host's instruction
  file. Migrations below it predate this format and are not required to satisfy
  it.
- `role=` **MUST NOT** appear on a non-`bash` fence.
```

- [ ] **Step 3: Amend the atomicity contract**

Replace the block at `spec/08-migration-format.md:107-119` with:

```markdown
### Atomicity contract

- When step N fails halfway and **stdin is a terminal**, the flow **MUST**
  prompt with three options:
  1. **Retry** — re-run step N (idempotent steps are safe to re-run).
  2. **Skip with warning** — log the skip, continue with step N+1. The
     migration is recorded as `partial`.
  3. **Rollback** — apply rollback patches for steps 1..N-1.
- When **stdin is not a terminal**, the flow **MUST** abort in place, report
  which steps applied, and **MUST NOT** roll back. The absence of anyone to ask
  is not consent, and a half-applied tree is evidence that an automatic
  rollback destroys.
- **MUST NOT** auto-rollback without explicit consent. Consent is a human
  answering the prompt, or an explicit `--on-failure` selection.
- Implementations **SHOULD** offer `--on-failure=abort|prompt|skip` to override
  the TTY-derived default.

Because rollback never executes on the non-interactive path, a host's migration
harness **SHOULD** exercise each `rollback` block directly against its own
step's post-apply state. Otherwise the one block every step is required to have
is the one nothing ever runs.
```

- [ ] **Step 4: Correct the dry-run promise**

At `spec/08-migration-format.md:121-127`, replace "prints the diff each step would apply" with:

```markdown
- **MUST** support a dry-run mode that runs every step's idempotency check and
  pre-condition, and prints the **source** of the `apply` block each pending
  step would run, without writing or committing. A dry run cannot show a real
  diff, because producing one would require applying the step.
```

- [ ] **Step 5: Add the conformance requirement**

In the Conformance list, after the test-fixtures bullet:

```markdown
- **MUST** run a format linter over its migrations that rejects a step missing
  any required role, a role that does not match its heading, a duplicate role,
  an unrecognised role value, and `role=` on a non-`bash` fence.
```

- [ ] **Step 6: Validate and commit**

```bash
openspec validate --all
git add spec/08-migration-format.md
git commit -m "spec(08): executable migration form, A2 atomicity, honest dry-run

spec_version 0.9.1 -> 0.10.0. The quartet was already a MUST; this adds the
machine-dispatchable form of it, an ID threshold so existing migrations stay
frozen history, and an atomicity rule that a non-interactive runner can
actually satisfy. The dry-run text now promises what is deliverable."
```

---

### Task 8: Wire into CI, and document

**Files:**
- Create: `reference-implementations/migration-runner/README.md`
- Modify: `.github/workflows/openspec-gate.yml`

**Interfaces:**
- Consumes: everything.
- Produces: a green CI job and a README Part 2's installer will read.

- [ ] **Step 1: Write the README**

Create `reference-implementations/migration-runner/README.md` covering: what the three scripts are; the role table; that un-annotated fences are illustration and why L4 exists; the A2 failure policy and its rollback consequence; the per-host ID thresholds (claude `0035`, codex `0016`, opencode `0012`, pi `0011`); and a note that Part 2's installer publishes these to `~/.agenticapps/bin/` under `# migration-runner-version:` arbitration, exactly as it does the gate and the reviewer CLI.

- [ ] **Step 2: Add the CI step**

In `.github/workflows/openspec-gate.yml`, after the `Check spec placement` step and before `Run the change gate`:

```yaml
      - name: Test the migration runner
        # The linter's L4 rule is the reason this runs in CI rather than by
        # hand: a misspelled role is indistinguishable from an illustration
        # fence, so a migration can lint clean and do nothing. The fixture
        # bad-l4-typo-role.md is the regression guard.
        run: bash tools/migration-runner.test.sh
```

- [ ] **Step 3: Run the full suite locally**

```bash
bash tools/migration-runner.test.sh
bash reference-implementations/migration-runner/lint-migration.sh --threshold 16 \
     reference-implementations/migration-runner/test-fixtures/conformant.md
openspec validate --all
bash ~/.agenticapps/bin/openspec-change-gate.sh --ci
```

Expected: `TOTAL: 51 passed, 0 failed`; linter exits 0; validate green; gate exits 0.

- [ ] **Step 4: Commit**

```bash
git add reference-implementations/migration-runner/README.md .github/workflows/openspec-gate.yml
git commit -m "ci(migration-runner): run the suite; document the format"
```

---

## Out of scope, deliberately

Recorded so a reader does not think they were forgotten:

- **No migration is retrofitted.** All 73 existing migrations across the four hosts stay exactly as they are. Every live install in the fleet is at head, so nothing replays. Retrofit scope is zero by decision, not by omission.
- **The installer is a separate change** — bash, `curl`-fetched from a tagged URL, multi-select host detection, no npm package and no TUI.
- **`apply-agent` is deferred.** It existed to absorb legacy prose; there is no legacy prose in scope.
- **`answers:` frontmatter is not in §08.** Its only consumer was `0000-baseline`, which never replays.
- **The four host repos get their thresholds declared when the installer lands**, not here. This change defines the mechanism; core is the only repo it touches.
