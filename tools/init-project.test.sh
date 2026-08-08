#!/usr/bin/env bash
# init-project.test.sh — the project initializer's contract, test-first.
#
# Covers change fresh-clone-needs-nothing tasks 3.1-3.5 and 3.7-3.11. Written
# and observed RED before reference-implementations/init-project/init-project.sh
# existed.
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

# 0 when the file is missing, so a count comparison cannot error out.
count_marker() { [ -f "$2" ] && grep -cF "$1" "$2" 2>/dev/null || printf '0'; }

# Every path the initializer is permitted to leave behind. Anything else in the
# worktree is a violation of "and nothing else", which is the requirement most
# likely to erode quietly.
unexpected_paths() {
  ( cd "$1" && find . -mindepth 1 \
      -not -path './.git' -not -path './.git/*' \
      -not -path './openspec' -not -path './openspec/*' \
      -not -name 'AGENTS.md' -not -name 'CLAUDE.md' \
      -not -name '.openspec-invocations' \
      | sort )
}

# ---------------------------------------------------------------------------
echo "A. A bare repository gets exactly two artifacts (task 3.1)"
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

[ -f "$r/AGENTS.md" ] && [ ! -L "$r/AGENTS.md" ] \
  && ok "AGENTS.md is a regular file" \
  || bad "AGENTS.md is a regular file" "missing, or it is a link"

[ -L "$r/CLAUDE.md" ] && ok "CLAUDE.md is a symlink" \
  || bad "CLAUDE.md is a symlink" "missing, or it is a regular file"

[ "$(cd "$r" && readlink CLAUDE.md)" = "AGENTS.md" ] \
  && ok "CLAUDE.md points at AGENTS.md by relative path" \
  || bad "CLAUDE.md points at AGENTS.md by relative path" \
         "readlink gave: $(cd "$r" && readlink CLAUDE.md 2>&1)" \
         "an absolute link breaks the moment the repo is cloned elsewhere"

grep -qF "$BEGIN_MARKER" "$r/AGENTS.md" 2>/dev/null && grep -qF "$END_MARKER" "$r/AGENTS.md" 2>/dev/null \
  && ok "the section is written behind the normative markers (task 3.9)" \
  || bad "the section is written behind the normative markers (task 3.9)" \
         "host-neutral-instruction-files makes these literal strings normative"

[ -z "$(unexpected_paths "$r")" ] \
  && ok "and nothing else is written (task 3.5)" \
  || bad "and nothing else is written (task 3.5)" \
         "unexpected: $(unexpected_paths "$r" | tr '\n' ' ')"

for p in .claude .codex .github commands claude-md workflow-config.md; do
  [ ! -e "$r/$p" ] && ok "no $p (task 3.5)" \
    || bad "no $p (task 3.5)" "the initializer wrote a host, hook, or CI artifact"
done

# ---------------------------------------------------------------------------
echo
echo "B. Running it twice changes nothing the second time (tasks 3.2, 3.9)"
# ---------------------------------------------------------------------------
before=$(digest "$r/AGENTS.md")
run_init "$r"

[ "$RC" -eq 0 ] && ok "second run exits zero" || bad "second run exits zero" "got $RC"

[ -f "$r/AGENTS.md" ] && [ "$(digest "$r/AGENTS.md")" = "$before" ] \
  && ok "second run leaves AGENTS.md byte-identical" \
  || bad "second run leaves AGENTS.md byte-identical" "the file changed, or never existed"

[ "$(count_marker "$BEGIN_MARKER" "$r/AGENTS.md")" -eq 1 ] \
  && ok "the section is not appended twice" \
  || bad "the section is not appended twice" \
         "found $(count_marker "$BEGIN_MARKER" "$r/AGENTS.md") begin markers, expected 1"

[ -L "$r/CLAUDE.md" ] && ok "the symlink is not re-created as a file" \
  || bad "the symlink is not re-created as a file" "CLAUDE.md is no longer a link"

# ---------------------------------------------------------------------------
echo
echo "C. An existing AGENTS.md keeps every line"
# ---------------------------------------------------------------------------
r=$(new_repo agents-only)
printf '# House rules\n\nDeploy on Fridays, never on Mondays.\n' > "$r/AGENTS.md"
run_init "$r"

[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC"
grep -q 'Deploy on Fridays' "$r/AGENTS.md" \
  && ok "existing content survives" || bad "existing content survives" "content was lost"
grep -qF "$BEGIN_MARKER" "$r/AGENTS.md" \
  && ok "the section is appended behind the markers" \
  || bad "the section is appended behind the markers" "no marker found"
[ -L "$r/CLAUDE.md" ] && ok "CLAUDE.md is created as a symlink" \
  || bad "CLAUDE.md is created as a symlink" "it is not a link"

# ---------------------------------------------------------------------------
echo
echo "D. Only CLAUDE.md exists — the case that silently makes two files (task 3.7)"
# ---------------------------------------------------------------------------
r=$(new_repo claude-only)
printf '# Claude rules\n\nAlways rebase.\n' > "$r/CLAUDE.md"
run_init "$r"

[ "$RC" -eq 0 ] && ok "exits zero" || bad "exits zero" "got $RC" "output: $(printf '%s' "$OUT" | head -2)"

[ -f "$r/AGENTS.md" ] && [ ! -L "$r/AGENTS.md" ] && grep -q 'Always rebase' "$r/AGENTS.md" \
  && ok "the content moves into AGENTS.md" \
  || bad "the content moves into AGENTS.md" "AGENTS.md missing the original content"

[ -L "$r/CLAUDE.md" ] && ok "CLAUDE.md is replaced by a symlink" \
  || bad "CLAUDE.md is replaced by a symlink" "it is still a regular file"

# The whole point of the case. Appending to CLAUDE.md and creating AGENTS.md
# beside it is the obvious implementation, it passes both assertions above, and
# it produces exactly the two divergent copies the requirement forbids.
{ [ -L "$r/CLAUDE.md" ] || [ -L "$r/AGENTS.md" ]; } \
  && ok "NEVER two regular instruction files" \
  || bad "NEVER two regular instruction files" \
         "both names are regular files — the failure the rule exists to prevent"

printf '%s' "$OUT" | grep -qi 'agents\.md\|every host\|other host' \
  && ok "the widened readership is disclosed to the operator" \
  || bad "the widened readership is disclosed to the operator" \
         "content Claude alone read is now read by every host, and nothing said so"

# ---------------------------------------------------------------------------
echo
echo "E. Both names exist as separate regular files (tasks 3.4, 3.8)"
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
  && ok "the refusal happens before anything is written (task 3.11 preflight)" \
  || bad "the refusal happens before anything is written (task 3.11 preflight)" \
         "openspec/ was created before the conflict was detected"

r=$(new_repo both-identical)
printf 'same rule\n' > "$r/AGENTS.md"
printf 'same rule\n' > "$r/CLAUDE.md"
run_init "$r"

[ "$RC" -eq 0 ] && ok "identical content is not a conflict" \
  || bad "identical content is not a conflict" "got $RC; there is no rule to choose between"
[ -L "$r/CLAUDE.md" ] && ok "identical content collapses to the symlink" \
  || bad "identical content collapses to the symlink" "CLAUDE.md is still a regular file"

# ---------------------------------------------------------------------------
echo
echo "F. Hostile starting states are refused, not repaired (task 3.8)"
# ---------------------------------------------------------------------------
r=$(new_repo link-elsewhere)
printf 'elsewhere\n' > "$TMP/outside.md"
ln -s "$TMP/outside.md" "$r/CLAUDE.md"
outside_before=$(digest "$TMP/outside.md")
run_init "$r"

[ "$RC" -ne 0 ] && ok "a CLAUDE.md linked elsewhere is refused" \
  || bad "a CLAUDE.md linked elsewhere is refused" "exited 0"
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

r=$(new_repo dangling)
ln -s no-such-file "$r/CLAUDE.md"
run_init "$r"
[ "$RC" -ne 0 ] && ok "a dangling CLAUDE.md link is refused" \
  || bad "a dangling CLAUDE.md link is refused" "exited 0"

# ---------------------------------------------------------------------------
echo
echo "G. openspec absent — a state this change deliberately makes reachable (task 3.10)"
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
echo "H. Invoked below the repository root (task 3.11)"
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
[ -f "$r/AGENTS.md" ] && ok "the instruction file lands at the root" \
  || bad "the instruction file lands at the root" "not at the root"

r=$(new_repo not-a-repo)
rm -rf "$r/.git"
run_init "$r"
[ "$RC" -ne 0 ] && ok "refuses outside a git repository" \
  || bad "refuses outside a git repository" "exited 0 with no repository to initialize"

# ---------------------------------------------------------------------------
echo
echo "I. It makes no network call (task 3.5)"
# ---------------------------------------------------------------------------
# Asserted against the source, because the honest runtime check is a sandbox
# this suite does not have. A grep is weaker than a sandbox and stronger than
# nothing: it catches the reachable spellings.
if [ "$INIT" = "${INIT_PROJECT_BIN:-}" ]; then
  ok "network scan skipped (running against an override binary)"
elif grep -nE '(^|[^[:alnum:]_])(curl|wget|nc|ssh|scp)([^[:alnum:]_]|$)|git (clone|fetch|pull|push)' "$INIT" >/dev/null; then
  bad "no network call in the source" \
      "found: $(grep -nE '(^|[^[:alnum:]_])(curl|wget|nc|ssh|scp)([^[:alnum:]_]|$)|git (clone|fetch|pull|push)' "$INIT" | head -1)"
else
  ok "no network call in the source"
fi

# ---------------------------------------------------------------------------
echo
echo "J. The collapse never destroys CLAUDE.md before its replacement exists (code review M4)"
# ---------------------------------------------------------------------------
# The collapse path ran `rm -f CLAUDE.md` and then `ln -s`. A failing link left
# the repository with NO CLAUDE.md at all, and the die message named the link it
# could not create rather than the file it had just removed. No content is lost
# — the preflight has already proved the two files byte-identical, so it all
# survives in AGENTS.md — but a repository is left in a state the operator did
# not ask for and is not told about.
#
# install.sh:190 handles the same ordering in sweep_vendored and says so out
# loud: "a failed `ln` leaves the binding as nothing at all. Saying so is the
# whole point." This is that argument applied one directory over.
#
# `ln` is doubled to fail, which is the only honest way to reach the branch:
# every real filesystem condition that breaks `ln -s` here also breaks the `rm`
# that precedes it, so the window cannot be opened with permissions alone.
r="$(new_repo collapse-ln-fails)"
printf 'shared rule\n' > "$r/AGENTS.md"
printf 'shared rule\n' > "$r/CLAUDE.md"          # byte-identical: collapsible
cat > "$FAKEBIN/ln" <<'EOF'
#!/usr/bin/env bash
echo "ln: simulated failure" >&2
exit 1
EOF
chmod +x "$FAKEBIN/ln"
run_init "$r"
rm -f "$FAKEBIN/ln"

[ "$RC" -ne 0 ] \
  && ok "a failing link is a non-zero exit" \
  || bad "a failing link is a non-zero exit" "exited 0 having not created the link"
[ -e "$r/CLAUDE.md" ] \
  && ok "CLAUDE.md survives a link that could not be created" \
  || bad "CLAUDE.md survives a link that could not be created" \
         "it was removed before the replacement existed, and is now gone"
[ -f "$r/AGENTS.md" ] && grep -q 'shared rule' "$r/AGENTS.md" \
  && ok "and AGENTS.md still carries the content" \
  || bad "and AGENTS.md still carries the content" "the shared rule is gone"

# ---------------------------------------------------------------------------
echo
echo "K. The initializer enrols the repository in the floor (task 2.8b)"
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
