#!/usr/bin/env bash
# init-project.test.sh — the project initializer's contract, test-first.
#
# Covers change two-real-instruction-files section 1, and retains the coverage
# from fresh-clone-needs-nothing tasks 3.1-3.5 and 3.7-3.11 that survived it.
#
# WHAT CHANGED AND WHY THE OLD ASSERTIONS WERE INVERTED. Until 2.0.0 this suite
# asserted that CLAUDE.md is a SYMLINK to AGENTS.md, which was the arrangement
# that made the two names one inode. two-real-instruction-files replaces that
# guarantee with two regular files and a gate check, so every "is a symlink"
# assertion below is now "is a regular file" and the symlink cases moved from
# the success path to the refusal path. The rows did not become weaker: the
# equality they used to get by construction is now asserted directly, on bytes.
#
# The initializer is driven through its public interface only: a working
# directory inside a scratch repository, a PATH, and an exit code out. Nothing
# here reaches into its internals, and no case touches a real repository.
#
# `openspec` is doubled rather than invoked for real. The double is not there to
# make assertions cheap — it is there because two of these cases are ABOUT the
# CLI's absence, and because a suite that shells out to the real one would assert
# on that tool's behaviour instead of this script's.
#
# Usage: tools/init-project.test.sh
#   INIT_PROJECT_BIN=/bin/true tools/init-project.test.sh
#     Points the suite at a deliberately wrong implementation. Every assertion
#     below MUST fail under it. That is how this file proves it has teeth
#     without a production script existing yet.
#
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT="${INIT_PROJECT_BIN:-$ROOT/reference-implementations/init-project/init-project.sh}"

# The markers are normative in host-neutral-instruction-files. They are spelled
# out here rather than sourced from the implementation on purpose: a test that
# read them from the thing under test would agree with it no matter what it said.
BEGIN_MARKER='<!-- BEGIN: agentic-apps-workflow sections (do not remove this marker) -->'
END_MARKER='<!-- END: agentic-apps-workflow sections -->'

pass=0
fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $1"; shift; for l in "$@"; do echo "        $l"; done; fail=$((fail + 1)); }

# Most assertions below are REFUSALS — "exits non-zero", "writes nothing",
# "leaves the file untouched". Every one of them is satisfied vacuously by a
# script that does not exist, because a missing command exits 127 and writes
# nothing. Without this guard the suite would report a clean run for an empty
# repository. Fail loudly instead of vacuously.
if [ ! -x "$INIT" ]; then
  echo "  FAIL  precondition: initializer not executable at $INIT"
  echo "        Refusing to run: the refusal assertions would pass vacuously."
  echo "        This is the expected RED while the implementation does not exist."
  exit 1
fi

# ---------------------------------------------------------------------------
# Scratch fixtures
# ---------------------------------------------------------------------------

# A doubled `openspec` that records its invocation and creates the directory the
# real one creates. Kept deliberately dumb: this suite asserts what the
# initializer does, never what the CLI does.
FAKEBIN="$TMP/fakebin"
mkdir -p "$FAKEBIN"
# It refuses `init` without --tools exactly as the real CLI does. An earlier,
# more permissive double accepted a bare `openspec init` and hid the fact that
# the real one exits 1 on it — the suite was green while the script could not
# initialize a single real repository.
cat > "$FAKEBIN/openspec" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "init" ]; then
  case " $* " in
    *" --tools "*) ;;
    *) echo "Error: No tools detected and no --tools flag provided." >&2; exit 1 ;;
  esac
  mkdir -p openspec/specs openspec/changes
  printf '%s\n' "$*" >> "$PWD/.openspec-invocations"
  exit 0
fi
exit 0
EOF
chmod +x "$FAKEBIN/openspec"

repo_n=0
# new_repo [name] — a scratch git repository, echoed as an absolute path.
new_repo() {
  repo_n=$((repo_n + 1))
  local d="$TMP/repo-$repo_n-${1:-plain}"
  mkdir -p "$d"
  git -C "$d" init -q
  printf '%s' "$d"
}

# run_init <repo> [subdir] — run the initializer with only the doubled openspec
# on PATH. Stdout+stderr into $OUT, exit code into $RC.
OUT=""; RC=0
run_init() {
  local repo="$1" sub="${2:-}"
  OUT=$( cd "$repo/$sub" && PATH="$FAKEBIN:/usr/bin:/bin" "$INIT" 2>&1 )
  RC=$?
}

# run_init_no_openspec <repo> — same, with no `openspec` reachable at all.
run_init_no_openspec() {
  local repo="$1"
  OUT=$( cd "$repo" && PATH="/usr/bin:/bin" "$INIT" 2>&1 )
  RC=$?
}

# A missing file gets a digest that can never equal another digest, including
# another missing file's. Returning "" for both sides made "unchanged" assertions
# pass against a script that had written nothing at all.
digest() {
  if [ -f "$1" ]; then shasum -a 256 "$1" | cut -d' ' -f1
  else printf 'ABSENT(%s)#%s' "$1" "$((++absent_n))"
  fi
}
absent_n=0

# THE PRESERVATION ASSERTION, and the only honest form of it (task 1.7).
# "Every existing line is preserved" cannot mean every byte: updating the block
# necessarily rewrites the bytes BETWEEN the markers. So the claim is scoped to
# the bytes OUTSIDE them, which is what an operator's own content occupies, and
# this digests exactly that. A file with no markers digests whole.
digest_outside_markers() {
  local f="$1" b e
  if [ ! -f "$f" ]; then printf 'ABSENT(%s)#%s' "$f" "$((++absent_n))"; return; fi
  b=$(grep -nF -m1 "$BEGIN_MARKER" "$f" 2>/dev/null | cut -d: -f1)
  e=$(grep -nF -m1 "$END_MARKER" "$f" 2>/dev/null | cut -d: -f1)
  if [ -z "$b" ] || [ -z "$e" ]; then shasum -a 256 "$f" | cut -d' ' -f1; return; fi
  { head -n "$((b - 1))" "$f"; tail -n "+$((e + 1))" "$f"; } | shasum -a 256 | cut -d' ' -f1
}

# The preservation assertion for the OTHER half of task 1.7 — a file that had no
# block and now has one. digest_outside_markers is the wrong instrument there:
# appending necessarily adds bytes outside the markers, one of them the blank
# line that keeps the marker off the end of somebody's last sentence. What can
# be asserted absolutely is that the original file is an unchanged PREFIX of the
# new one, which forbids every edit, removal and reordering of existing content
# while allowing the append that is the whole point of the run.
#
# `head -c` and a pipe rather than `cmp -n`: BSD cmp reports "EOF on <file>" for
# a limit equal to the shorter file's length, so the portable spelling is to cut
# the prefix and compare whole files.
prefix_unchanged() { # $1 = file now, $2 = a copy of it as it was
  local n
  [ -f "$1" ] && [ -f "$2" ] || return 1
  n=$(wc -c < "$2" | tr -d ' ')
  head -c "$n" "$1" | cmp -s - "$2"
}

# The inode, so "it rewrote the file in place" can be told apart from "it
# replaced the file with a new one". The distinction is the whole of task 1.4:
# a `mv` over the destination passes every content assertion in this file and is
# exactly the operation the requirement forbids.
inode() { [ -e "$1" ] && ls -i "$1" 2>/dev/null | awk '{print $1}' || printf 'NONE#%s' "$((++absent_n))"; }

# 0 when the file is missing, so a count comparison cannot error out.
count_marker() { [ -f "$2" ] && grep -cF "$1" "$2" 2>/dev/null || printf '0'; }

# Both names, regular, readable, non-empty and byte-identical. This is the
# post-condition of every successful run and it is asserted after each one,
# because it is the invariant the gate check will later enforce on commits —
# a writer that can produce a pair the gate rejects is a broken writer.
assert_pair() { # $1 = repo, $2 = label
  local r="$1" lbl="$2" a c arc crc
  if [ -L "$r/AGENTS.md" ] || [ -L "$r/CLAUDE.md" ]; then
    bad "$lbl: neither name is a symlink" "one of them is a link — the arrangement 2.0.0 removed"
    return
  fi
  ok "$lbl: neither name is a symlink"

  [ -f "$r/AGENTS.md" ] && [ -f "$r/CLAUDE.md" ] \
    && ok "$lbl: both names are regular files" \
    || { bad "$lbl: both names are regular files" "one is missing or is not a regular file"; return; }

  a=$(cat "$r/AGENTS.md" 2>/dev/null); arc=$?
  c=$(cat "$r/CLAUDE.md" 2>/dev/null); crc=$?
  [ "$arc" -eq 0 ] && [ "$crc" -eq 0 ] && [ -n "$a" ] \
    && ok "$lbl: both names read, and are non-empty" \
    || bad "$lbl: both names read, and are non-empty" "AGENTS rc=$arc CLAUDE rc=$crc"

  cmp -s "$r/AGENTS.md" "$r/CLAUDE.md" \
    && ok "$lbl: the two names are byte-identical" \
    || bad "$lbl: the two names are byte-identical" \
           "$(diff "$r/AGENTS.md" "$r/CLAUDE.md" 2>&1 | head -3)"

  grep -qF "$BEGIN_MARKER" "$r/AGENTS.md" && grep -qF "$END_MARKER" "$r/AGENTS.md" \
    && ok "$lbl: the section sits behind the normative markers" \
    || bad "$lbl: the section sits behind the normative markers" "marker missing"
}

# Every path the initializer is permitted to leave behind. Anything else in the
# worktree is a violation of "and nothing else", which is the requirement most
# likely to erode quietly. It also catches a temp file left in the repository:
# the writer builds the new content somewhere, and somewhere must not be here.
unexpected_paths() {
  ( cd "$1" && find . -mindepth 1 \
      -not -path './.git' -not -path './.git/*' \
      -not -path './openspec' -not -path './openspec/*' \
      -not -name 'AGENTS.md' -not -name 'CLAUDE.md' \
      -not -name '.openspec-invocations' \
      | sort )
}

# ---------------------------------------------------------------------------
echo "A. Neither file exists — a bare repository gets exactly two artifacts"
# ---------------------------------------------------------------------------
r=$(new_repo bare)
run_init "$r"

[ "$RC" -eq 0 ] && ok "exits zero" \
  || bad "exits zero" "got $RC" "output: $(printf '%s' "$OUT" | head -2)"

[ -d "$r/openspec" ] && ok "openspec/ is created" \
  || bad "openspec/ is created" "no openspec/ in $r"

grep -q '^init' "$r/.openspec-invocations" 2>/dev/null \
  && ok "openspec/ is created by invoking the CLI, not by hand" \
  || bad "openspec/ is created by invoking the CLI, not by hand" \
         "the initializer never ran 'openspec init'"

# Every --tools value except none writes per-host command and skill files into
# the repository; `--tools claude` alone writes six commands and six skills
# under .claude/. The flag is not optional either — the real CLI exits 1 without
# it, which a laxer double here concealed.
grep -q '^init --tools none$' "$r/.openspec-invocations" 2>/dev/null \
  && ok "the CLI is invoked with --tools none" \
  || bad "the CLI is invoked with --tools none" \
         "recorded: $(cat "$r/.openspec-invocations" 2>/dev/null || echo '(nothing)')"

assert_pair "$r" "bare"

[ -z "$(unexpected_paths "$r")" ] \
  && ok "and nothing else is written" \
  || bad "and nothing else is written" \
         "unexpected: $(unexpected_paths "$r" | tr '\n' ' ')"

# THE WRITER'S OUTPUT MUST SATISFY THE SCORER, and nothing asserted that until
# core's own AGENTS.md finally carried a section and CI failed on it. The two
# tools had been in the same repository for weeks with no row joining them: the
# initializer wrote a section carrying no `section-version`, which
# `agents-md-conformance.sh` fails, and every repository the initializer touched
# got one. It went unseen because core's AGENTS.md was a symlink to a CLAUDE.md
# with no section at all, and a file with no section is conformant.
#
# Scored against the real harness rather than by re-stating its rules here. A
# hand-written copy of "must contain section-version" would agree with itself
# and would not have caught the next requirement the scorer grows.
AMC="$ROOT/tools/agents-md-conformance.sh"
if [ -x "$AMC" ]; then
  if bash "$AMC" "$r/AGENTS.md" >"$TMP/amc.out" 2>&1; then
    ok "the written file scores clean against tools/agents-md-conformance.sh"
  else
    bad "the written file scores clean against tools/agents-md-conformance.sh" \
        "$(grep -m2 '  FAIL' "$TMP/amc.out" || tail -2 "$TMP/amc.out")"
  fi
else
  bad "the written file scores clean against tools/agents-md-conformance.sh" \
      "the scorer is missing at $AMC — the cross-check cannot run"
fi

for p in .claude .codex .github commands claude-md workflow-config.md; do
  [ ! -e "$r/$p" ] && ok "no $p" \
    || bad "no $p" "the initializer wrote a host, hook, or CI artifact"
done

# ---------------------------------------------------------------------------
echo
echo "B. Running it twice changes nothing the second time"
# ---------------------------------------------------------------------------
a_before=$(digest "$r/AGENTS.md"); c_before=$(digest "$r/CLAUDE.md")
a_ino=$(inode "$r/AGENTS.md"); c_ino=$(inode "$r/CLAUDE.md")
run_init "$r"

[ "$RC" -eq 0 ] && ok "second run exits zero" || bad "second run exits zero" "got $RC"

[ "$(digest "$r/AGENTS.md")" = "$a_before" ] && [ "$(digest "$r/CLAUDE.md")" = "$c_before" ] \
  && ok "second run leaves both names byte-identical to themselves" \
  || bad "second run leaves both names byte-identical to themselves" "a file changed, or never existed"

[ "$(count_marker "$BEGIN_MARKER" "$r/AGENTS.md")" -eq 1 ] \
  && [ "$(count_marker "$BEGIN_MARKER" "$r/CLAUDE.md")" -eq 1 ] \
  && ok "the section is not appended twice, in either name" \
  || bad "the section is not appended twice, in either name" \
         "AGENTS.md has $(count_marker "$BEGIN_MARKER" "$r/AGENTS.md") begin markers"

# The file is REWRITTEN, never REPLACED. Task 1.4 forbids moving, replacing,
# linking or deleting, and a `mv` of a freshly built file over the destination
# satisfies every content assertion above while doing precisely that.
[ "$(inode "$r/AGENTS.md")" = "$a_ino" ] && [ "$(inode "$r/CLAUDE.md")" = "$c_ino" ] \
  && ok "neither name is replaced by a different file" \
  || bad "neither name is replaced by a different file" \
         "the inode changed — the writer moved a new file over an existing name"

assert_pair "$r" "second run"

# ---------------------------------------------------------------------------
echo
echo "C. Only AGENTS.md exists — every line of it survives"
# ---------------------------------------------------------------------------
r=$(new_repo agents-only)
printf '# House rules\n\nDeploy on Fridays, never on Mondays.\n' > "$r/AGENTS.md"
cp "$r/AGENTS.md" "$TMP/agents-only.before"
a_ino=$(inode "$r/AGENTS.md")
run_init "$r"

[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC"
grep -q 'Deploy on Fridays' "$r/AGENTS.md" \
  && ok "existing content survives" || bad "existing content survives" "content was lost"
prefix_unchanged "$r/AGENTS.md" "$TMP/agents-only.before" \
  && ok "and every byte of it is an unchanged prefix — the section is appended, never woven in" \
  || bad "and every byte of it is an unchanged prefix — the section is appended, never woven in" \
         "existing content was edited, removed or reordered"
[ "$(inode "$r/AGENTS.md")" = "$a_ino" ] \
  && ok "AGENTS.md is written in place, not replaced" \
  || bad "AGENTS.md is written in place, not replaced" "the inode changed"
assert_pair "$r" "agents-only"

# ---------------------------------------------------------------------------
echo
echo "D. Only CLAUDE.md exists — the case that silently makes two files"
# ---------------------------------------------------------------------------
# THE CASE THE WHOLE REQUIREMENT EXISTS FOR. Appending to CLAUDE.md and leaving
# AGENTS.md alone is the obvious implementation and it produces the two
# divergent copies the gate will later fail. Until 2.0.0 the script avoided that
# by MOVING CLAUDE.md to AGENTS.md and linking it back; it no longer moves
# anything, so the copy must be made and the pair asserted directly.
r=$(new_repo claude-only)
printf '# Claude rules\n\nAlways rebase.\n' > "$r/CLAUDE.md"
c_ino=$(inode "$r/CLAUDE.md")
cp "$r/CLAUDE.md" "$TMP/claude-only.before"
run_init "$r"

[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "output: $(printf '%s' "$OUT" | head -2)"

grep -q 'Always rebase' "$r/CLAUDE.md" \
  && ok "CLAUDE.md keeps its own content" \
  || bad "CLAUDE.md keeps its own content" "the original content is gone from CLAUDE.md"

# It STAYS at its own path. The 1.x script moved it, which relocated a file the
# operator did not ask to have relocated and widened its readership in the same
# step. Content survived that; the path did not.
[ "$(inode "$r/CLAUDE.md")" = "$c_ino" ] \
  && ok "CLAUDE.md remains the same file at the same path — not moved" \
  || bad "CLAUDE.md remains the same file at the same path — not moved" \
         "the inode changed: it was moved, replaced, or re-created"

prefix_unchanged "$r/CLAUDE.md" "$TMP/claude-only.before" \
  && ok "no line of it is removed, edited or reordered — the section is appended" \
  || bad "no line of it is removed, edited or reordered — the section is appended" \
         "the operator's own bytes changed"

grep -q 'Always rebase' "$r/AGENTS.md" 2>/dev/null \
  && ok "AGENTS.md is created holding the SAME content, block included" \
  || bad "AGENTS.md is created holding the SAME content, block included" \
         "AGENTS.md holds only the block, or does not exist"

assert_pair "$r" "claude-only"

printf '%s' "$OUT" | grep -qi 'agents\.md\|every host\|other host' \
  && ok "the widened readership is disclosed to the operator" \
  || bad "the widened readership is disclosed to the operator" \
         "content Claude alone read is now read by every host, and nothing said so"

# ---------------------------------------------------------------------------
echo
echo "E. Both exist as regular files"
# ---------------------------------------------------------------------------
r=$(new_repo both-differ)
printf 'agents rule\n' > "$r/AGENTS.md"
printf 'claude rule\n' > "$r/CLAUDE.md"
a_before=$(digest "$r/AGENTS.md"); c_before=$(digest "$r/CLAUDE.md")
run_init "$r"

[ "$RC" -ne 0 ] && ok "differing content is refused" \
  || bad "differing content is refused" "exited 0; collapsing them decides which rule survives"
[ "$(digest "$r/AGENTS.md")" = "$a_before" ] && [ "$(digest "$r/CLAUDE.md")" = "$c_before" ] \
  && ok "neither file is touched by the refusal" \
  || bad "neither file is touched by the refusal" "a refusal still wrote something"
[ ! -d "$r/openspec" ] \
  && ok "the refusal happens before anything is written" \
  || bad "the refusal happens before anything is written" \
         "openspec/ was created before the conflict was detected"
printf '%s' "$OUT" | grep -qi 'reconcil\|differ' \
  && ok "and it says reconciling them is the operator's decision" \
  || bad "and it says reconciling them is the operator's decision" \
         "output: $(printf '%s' "$OUT" | head -2)"

r=$(new_repo both-identical)
printf '# same rule\n' > "$r/AGENTS.md"
printf '# same rule\n' > "$r/CLAUDE.md"
a_ino=$(inode "$r/AGENTS.md"); c_ino=$(inode "$r/CLAUDE.md")
run_init "$r"

[ "$RC" -eq 0 ] && ok "identical content is not a conflict" \
  || bad "identical content is not a conflict" "got $RC; there is no rule to choose between"
[ "$(inode "$r/AGENTS.md")" = "$a_ino" ] && [ "$(inode "$r/CLAUDE.md")" = "$c_ino" ] \
  && ok "both names are written in place, neither is replaced" \
  || bad "both names are written in place, neither is replaced" "an inode changed"
grep -q 'same rule' "$r/AGENTS.md" && grep -q 'same rule' "$r/CLAUDE.md" \
  && ok "the shared content survives in both" \
  || bad "the shared content survives in both" "content was lost"
assert_pair "$r" "both-identical"

# ---------------------------------------------------------------------------
echo
echo "F. The block is UPDATED in place, never appended beside itself"
# ---------------------------------------------------------------------------
# "Inserted or updated" is a real second behaviour, not a synonym for inserted.
# A repository carrying an older section must end up carrying the current one,
# and the bytes outside the markers must not move while that happens — which is
# the preservation claim in its only defensible form (task 1.7).
r=$(new_repo stale-block)
{
  printf '# House rules\n\nRebase, never merge.\n\n'
  printf '%s\n' "$BEGIN_MARKER"
  printf '\n## The AgenticApps workflow\n\nSOMETHING OLD AND WRONG.\n\n'
  printf '%s\n' "$END_MARKER"
  printf '\n## Afterword\n\nThis paragraph is below the block.\n'
} > "$r/AGENTS.md"
cp "$r/AGENTS.md" "$r/CLAUDE.md"
outside_before=$(digest_outside_markers "$r/AGENTS.md")
run_init "$r"

[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "output: $(printf '%s' "$OUT" | head -2)"

[ "$(digest_outside_markers "$r/AGENTS.md")" = "$outside_before" ] \
  && ok "every byte OUTSIDE the markers is unchanged" \
  || bad "every byte OUTSIDE the markers is unchanged" \
         "the writer touched content it does not own"

grep -q 'This paragraph is below the block' "$r/AGENTS.md" \
  && ok "content below the block survives" \
  || bad "content below the block survives" "the writer truncated the file at the block"

grep -q 'SOMETHING OLD AND WRONG' "$r/AGENTS.md" \
  && bad "the stale section is replaced, not kept" "the old block is still there" \
  || ok "the stale section is replaced, not kept"

[ "$(count_marker "$BEGIN_MARKER" "$r/AGENTS.md")" -eq 1 ] \
  && ok "and no second block is appended beside it" \
  || bad "and no second block is appended beside it" \
         "found $(count_marker "$BEGIN_MARKER" "$r/AGENTS.md") begin markers"

assert_pair "$r" "stale-block"

# A marker pair that does not delimit anything cannot be updated safely, and
# guessing where the block ends is how a writer eats the rest of the file.
r=$(new_repo unbalanced-markers)
{ printf '# Rules\n\n'; printf '%s\n' "$BEGIN_MARKER"; printf '\nno end marker follows\n'; } > "$r/AGENTS.md"
before=$(digest "$r/AGENTS.md")
run_init "$r"
[ "$RC" -ne 0 ] && ok "an unterminated block is refused" \
  || bad "an unterminated block is refused" "exited 0 with no way to know where the block ends"
[ "$(digest "$r/AGENTS.md")" = "$before" ] \
  && ok "and the file is untouched" || bad "and the file is untouched" "it wrote anyway"

# ---------------------------------------------------------------------------
echo
echo "G. One name is a symlink — refused in either direction"
# ---------------------------------------------------------------------------
# THE STATE THAT DESTROYED TWO REPOSITORIES, and now also the state every
# repository migrating off 1.x is in. Refused rather than migrated in place:
# replacing a link with content is a one-time, per-repository act that belongs
# in a reviewable commit, not in a scaffolder run nobody is watching.
r=$(new_repo claude-is-link)
printf '# Real rules\n\nNever force-push to main.\n' > "$r/AGENTS.md"
( cd "$r" && ln -s AGENTS.md CLAUDE.md )
a_before=$(shasum -a 256 "$r/AGENTS.md" | cut -d' ' -f1)
run_init "$r"

[ "$RC" -ne 0 ] && ok "a CLAUDE.md symlink is refused — the 1.x arrangement is not adopted" \
  || bad "a CLAUDE.md symlink is refused — the 1.x arrangement is not adopted" "exited 0"
printf '%s' "$OUT" | grep -qi 'claude\.md' \
  && ok "the refusal names which of the two is the link" \
  || bad "the refusal names which of the two is the link" "output: $(printf '%s' "$OUT" | head -2)"
printf '%s' "$OUT" | grep -qi 'copy\|replace\|regular file' \
  && ok "and names the migration step" \
  || bad "and names the migration step" "output: $(printf '%s' "$OUT" | head -3)"
[ "$(shasum -a 256 "$r/AGENTS.md" | cut -d' ' -f1)" = "$a_before" ] \
  && ok "the real file is left alone" || bad "the real file is left alone" "it was rewritten"
[ ! -d "$r/openspec" ] \
  && ok "and nothing is written before the refusal" \
  || bad "and nothing is written before the refusal" "openspec/ was created first"

# The inverse direction. `-f` and `cmp` both dereference, so when one name links
# to the other a naive preflight compares a file to ITSELF, finds it trivially
# identical, and waves through the arrangement it exists to refuse.
r=$(new_repo agents-is-link)
printf '# Real rules\n\nNever force-push to main.\n' > "$r/CLAUDE.md"
( cd "$r" && ln -s CLAUDE.md AGENTS.md )
c_before=$(shasum -a 256 "$r/CLAUDE.md" | cut -d' ' -f1)
run_init "$r"

[ "$RC" -ne 0 ] && ok "an AGENTS.md symlink is refused" \
  || bad "an AGENTS.md symlink is refused" "exited 0 — this is the loop being created"
printf '%s' "$OUT" | grep -qi 'agents\.md' \
  && ok "the refusal names AGENTS.md" \
  || bad "the refusal names AGENTS.md" "output: $(printf '%s' "$OUT" | head -2)"
if cat "$r/CLAUDE.md" >/dev/null 2>&1 \
   && [ "$(shasum -a 256 "$r/CLAUDE.md" | cut -d' ' -f1)" = "$c_before" ]; then
  ok "CLAUDE.md is still readable and byte-identical"
else
  bad "CLAUDE.md is still readable and byte-identical" "read: $(cat "$r/CLAUDE.md" 2>&1 | head -1)"
fi
[ "$(cd "$r" && readlink AGENTS.md)" = "CLAUDE.md" ] \
  && ok "AGENTS.md still points where it did" \
  || bad "AGENTS.md still points where it did" "readlink: $(cd "$r" && readlink AGENTS.md 2>&1)"

# ---------------------------------------------------------------------------
echo
echo "H. Other hostile starting states are refused, not repaired"
# ---------------------------------------------------------------------------
r=$(new_repo link-elsewhere)
printf 'elsewhere\n' > "$TMP/outside.md"
ln -s "$TMP/outside.md" "$r/CLAUDE.md"
outside_before=$(digest "$TMP/outside.md")
run_init "$r"

[ "$RC" -ne 0 ] && ok "a CLAUDE.md linked outside the repository is refused" \
  || bad "a CLAUDE.md linked outside the repository is refused" "exited 0"
printf '%s' "$OUT" | grep -qF "$TMP/outside.md" \
  && ok "and the refusal names the target" \
  || bad "and the refusal names the target" "output: $(printf '%s' "$OUT" | head -2)"
[ "$(readlink "$r/CLAUDE.md" 2>/dev/null)" = "$TMP/outside.md" ] \
  && ok "the existing link is left alone" || bad "the existing link is left alone" "the link was rewritten"
[ "$(digest "$TMP/outside.md")" = "$outside_before" ] \
  && ok "nothing is written THROUGH the link, outside the repository" \
  || bad "nothing is written THROUGH the link, outside the repository" \
         "the initializer followed a link and wrote outside the worktree"

r=$(new_repo agents-is-dir)
mkdir "$r/AGENTS.md"
run_init "$r"
[ "$RC" -ne 0 ] && ok "AGENTS.md as a directory is refused" \
  || bad "AGENTS.md as a directory is refused" "exited 0"

r=$(new_repo claude-is-dir)
mkdir "$r/CLAUDE.md"
run_init "$r"
[ "$RC" -ne 0 ] && ok "CLAUDE.md as a directory is refused" \
  || bad "CLAUDE.md as a directory is refused" "exited 0"

r=$(new_repo dangling)
ln -s no-such-file "$r/CLAUDE.md"
run_init "$r"
[ "$RC" -ne 0 ] && ok "a dangling CLAUDE.md link is refused" \
  || bad "a dangling CLAUDE.md link is refused" "exited 0"

# A FIFO is neither a directory nor a link, it passes `-e`, and opening one for
# reading BLOCKS UNTIL A WRITER APPEARS. The writer reads the existing name to
# build the new content, so this is the one hostile state that HANGS rather than
# fails — and a hang is worse than a wrong answer, because it stops the operator
# rather than telling them anything.
#
# Bounded by polling rather than by `timeout`, which is not on a stock macOS.
# The unblocking write matters as much as the kill: the parked reader is a
# grandchild of the backgrounded shell, so signalling that shell leaves the read
# in place and the FIFO held open for the rest of the run.
if command -v mkfifo >/dev/null 2>&1; then
  r=$(new_repo agents-is-fifo)
  mkfifo "$r/AGENTS.md"
  ( cd "$r" && PATH="$FAKEBIN:/usr/bin:/bin" "$INIT" >"$TMP/fifo.out" 2>&1; echo $? > "$TMP/fifo.rc" ) &
  fifo_pid=$!
  n=0
  while kill -0 "$fifo_pid" 2>/dev/null && [ "$n" -lt 50 ]; do sleep 0.1; n=$((n + 1)); done
  if kill -0 "$fifo_pid" 2>/dev/null; then
    ( : > "$r/AGENTS.md" ) 2>/dev/null &   # gives the parked reader an EOF
    sleep 1
    kill -9 "$fifo_pid" 2>/dev/null
    wait "$fifo_pid" 2>/dev/null
    bad "a FIFO named AGENTS.md is refused, without hanging" \
        "it was still running after 5s — it is parked on a read of the FIFO"
  else
    wait "$fifo_pid" 2>/dev/null
    [ "$(cat "$TMP/fifo.rc" 2>/dev/null)" != 0 ] \
      && ok "a FIFO named AGENTS.md is refused, without hanging" \
      || bad "a FIFO named AGENTS.md is refused, without hanging" \
             "it exited 0 on a name that is not a regular file"
  fi
fi

# ---------------------------------------------------------------------------
echo
echo "I. openspec absent — a state this change deliberately makes reachable"
# ---------------------------------------------------------------------------
r=$(new_repo no-openspec)
run_init_no_openspec "$r"

[ "$RC" -ne 0 ] && ok "refuses when openspec is unavailable" \
  || bad "refuses when openspec is unavailable" "exited 0 without the tool it needs"
printf '%s' "$OUT" | grep -qi 'openspec' \
  && ok "names openspec as the missing prerequisite" \
  || bad "names openspec as the missing prerequisite" "output: $(printf '%s' "$OUT" | head -2)"
[ ! -e "$r/AGENTS.md" ] && [ ! -e "$r/CLAUDE.md" ] \
  && ok "writes nothing before refusing" \
  || bad "writes nothing before refusing" "a half-initialized repository was left behind"

# ---------------------------------------------------------------------------
echo
echo "J. Invoked below the repository root"
# ---------------------------------------------------------------------------
r=$(new_repo subdir)
mkdir -p "$r/packages/api"
run_init "$r" "packages/api"

[ "$RC" -eq 0 ] && ok "exits zero from a subdirectory" || bad "exits zero from a subdirectory" "got $RC"
[ -d "$r/openspec" ] && ok "openspec/ lands at the repository root" \
  || bad "openspec/ lands at the repository root" "not at the root"
[ ! -e "$r/packages/api/openspec" ] \
  && ok "no second openspec/ beside the first" \
  || bad "no second openspec/ beside the first" "it initialized the subdirectory"
[ -f "$r/AGENTS.md" ] && [ ! -e "$r/packages/api/AGENTS.md" ] \
  && ok "the instruction files land at the root" \
  || bad "the instruction files land at the root" "not at the root"

r=$(new_repo not-a-repo)
rm -rf "$r/.git"
run_init "$r"
[ "$RC" -ne 0 ] && ok "refuses outside a git repository" \
  || bad "refuses outside a git repository" "exited 0 with no repository to initialize"

# ---------------------------------------------------------------------------
echo
echo "K. It makes no network call, and it moves, links and deletes nothing"
# ---------------------------------------------------------------------------
# Asserted against the source, because the honest runtime check is a sandbox
# this suite does not have. A grep is weaker than a sandbox and stronger than
# nothing: it catches the reachable spellings.
if [ "$INIT" = "${INIT_PROJECT_BIN:-}" ]; then
  ok "source scans skipped (running against an override binary)"
else
  net_re='(^|[^[:alnum:]_])(curl|wget|nc|ssh|scp)([^[:alnum:]_]|$)|git (clone|fetch|pull|push)'
  if grep -nE "$net_re" "$INIT" >/dev/null; then
    bad "no network call in the source" "found: $(grep -nE "$net_re" "$INIT" | head -1)"
  else
    ok "no network call in the source"
  fi

  # Task 1.4, asserted where it can be asserted absolutely. The runtime inode
  # checks above prove the happy paths did not replace a file; this proves the
  # capability is not in the script at all, including on paths no fixture here
  # reaches. Comments are stripped first — this file's own header discusses the
  # `ln -s` it removed, and so does the initializer's.
  destr_re='^[[:space:]]*(ln|mv|rm)[[:space:]]'
  if sed 's/#.*//' "$INIT" | grep -nE "$destr_re" >/dev/null; then
    bad "the source never moves, links or deletes" \
        "found: $(sed 's/#.*//' "$INIT" | grep -nE "$destr_re" | head -1)"
  else
    ok "the source never moves, links or deletes"
  fi
fi

# ---------------------------------------------------------------------------
echo
echo "L. The initializer enrols the repository in the floor"
# ---------------------------------------------------------------------------
# WITHOUT THIS THE ARTIFACTS ARE INERT. The published pre-commit runs in every
# repository on a bound machine and exits 0 for want of this key, so a project
# that has openspec/ and the instruction file and is NOT enrolled is ungated
# while looking, from every file on disk, exactly like one that is.
#
# Measured 2026-08-08, which is why this exists: five repositories carried live
# openspec changes and none of them was enrolled, because the only thing that
# ever wrote the key was somebody remembering to.
r=$(new_repo enrol)
run_init "$r"

[ "$(git -C "$r" config --local --get agenticapps.workflow.enrolled)" = true ] \
  && ok "a fresh init enrols the repository" \
  || bad "a fresh init enrols the repository" \
         "got '$(git -C "$r" config --local --get agenticapps.workflow.enrolled)'"

# LOCAL, NEVER GLOBAL, and the dispatcher's own header records why: a stray
# `--global agenticapps.workflow.enrolled true` enrolled every repository on
# the machine. The initializer must not be the thing that does that.
#
# Asserted against the repository's config FILE rather than through `git config
# --local`, which would agree with itself. Note git stores this as a subsection
# — `[agenticapps "workflow"]` with `enrolled = true` — so the dotted name never
# appears literally, and grepping for it passes on an implementation that wrote
# nothing at all.
git -C "$r" config --local --list --show-origin 2>/dev/null \
  | grep 'agenticapps.workflow.enrolled=true' | grep -q '\.git/config' \
  && ok "and the key lives in the repository's own config file" \
  || bad "and the key lives in the repository's own config file" \
         "origin: $(git -C "$r" config --local --list --show-origin 2>/dev/null | grep enrolled)"

# The complement, and it is the assertion that actually forbids the defect:
# nothing about this run may have reached the operator's global configuration.
git config --global --get agenticapps.workflow.enrolled >/dev/null 2>&1 \
  && bad "and no global enrolment key was written" \
         "the machine now has a global agenticapps.workflow.enrolled — every repository is enrolled" \
  || ok "and no global enrolment key was written"

# Re-running is the common case: the script is idempotent everywhere else and
# an operator re-runs it after adding a host. A second run must not report a
# fresh enrolment it did not perform.
run_init "$r"
[ "$RC" -eq 0 ] \
  && [ "$(git -C "$r" config --local --get agenticapps.workflow.enrolled)" = true ] \
  && ok "re-running leaves it enrolled and still exits zero" \
  || bad "re-running leaves it enrolled and still exits zero" \
         "rc=$RC enrolled='$(git -C "$r" config --local --get agenticapps.workflow.enrolled)'"

# The value is asserted, not merely the key's presence. `--type=bool` in the
# dispatcher means `false` does not enrol, so writing anything but true here
# would produce a repository that reads as configured and is not gated.
[ "$(git -C "$r" config --local --type=bool --get agenticapps.workflow.enrolled)" = true ] \
  && ok "and it reads as true under the dispatcher's own --type=bool" \
  || bad "and it reads as true under the dispatcher's own --type=bool" \
         "the dispatcher would not treat this repository as enrolled"

echo
echo "  passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
