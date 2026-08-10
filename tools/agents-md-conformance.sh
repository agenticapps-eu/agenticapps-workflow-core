#!/usr/bin/env bash
# agents-md-conformance.sh — score a project's shared instruction file against
# spec §12 "Shared instruction files across hosts". Behaviour without a row
# here is not certified.
#
# Usage: agents-md-conformance.sh <path-to-AGENTS.md>
#
# Optional, enables the agent-lifecycle rows (section E). Each is a command
# invoked as: <cmd> <repo-dir> <agent-id>
#   AGENTS_MD_ADD_CMD     provision an agent into a repo
#   AGENTS_MD_REMOVE_CMD  remove an agent from a repo
# Unset, section E reports INCONCLUSIVE rows. Per §20 an inconclusive row does
# not count toward the scored total — a harness reports a row inconclusive
# precisely when it could not determine the answer, and counting it as evidence
# gathered would turn "I could not tell" into "I checked".
#
# agents-md-conformance-version: 0.1.0
set -uo pipefail

# ── target screening (capability: conformance-harness-reporting) ─────────────
# SINGLE-TARGET shape per §20: exactly one target, ABORT on one it cannot use
# rather than counting a failure row and continuing. Precedence is fixed —
# not-found, not-a-regular-file, empty, unreadable — so the report is
# reproducible across platforms whose `test` builtins short-circuit differently.
harness_screen_target() { # $1 = path; sets REASON, returns 1 if unscoreable
  REASON=""
  if [ -L "$1" ] && [ ! -e "$1" ]; then REASON="not a regular file (dangling symlink)"; return 1; fi
  if [ ! -e "$1" ]; then REASON="not found"; return 1; fi
  if [ ! -f "$1" ]; then REASON="not a regular file"; return 1; fi
  if [ ! -s "$1" ]; then REASON="empty"; return 1; fi
  if [ ! -r "$1" ]; then REASON="unreadable"; return 1; fi
  return 0
}

# A path is attacker-influenceable in the general case; output that can be
# forged with an embedded newline can be made to print a line reading like PASS.
harness_safe_label() { # $1 = path
  printf '%s' "$1" | LC_ALL=C tr -c '[:print:]' '?'
}

TARGET="${1:-}"
[ -n "$TARGET" ] || { echo "usage: $0 <path-to-AGENTS.md>" >&2; exit 2; }

# §12: CLAUDE.md is out of scope — ONLY where it is the sole instruction file in
# the repository. Refusing the target is how "never scored by any row" is made
# observable: a harness that merely happened not to look could start looking by
# accident.
#
# THE CONDITION IS WHETHER THE BYTES ARE SHARED, NEVER WHETHER THE PATH IS A
# LINK. The carve-out's reason was that "Claude is its only reader, so there is
# nothing to deduplicate", and a repository carrying both names inverts that
# premise: the file Claude reads holds the same bytes codex, opencode, pi and
# omp read. It was true of the symlink arrangement and it is equally true of the
# two identical regular files that replaced it — which is why this asks for a
# sibling AGENTS.md rather than asking `-L`.
case "$(basename "$TARGET")" in
  CLAUDE.md)
    if [ -e "$(dirname "$TARGET")/AGENTS.md" ]; then
      : # in scope: it is one of two copies of the shared instruction file
    else
      echo "  OUT-OF-SCOPE  $(harness_safe_label "$TARGET") — CLAUDE.md is excluded by spec §12" >&2
      echo "                where it is the only instruction file: Claude is its only reader," >&2
      echo "                so there is nothing to deduplicate. No AGENTS.md sits beside it." >&2
      exit 2
    fi
    ;;
esac

harness_screen_target "$TARGET" || {
  echo "  UNSCOREABLE  $(harness_safe_label "$TARGET") — $REASON" >&2
  exit 2
}

pass=0; fail=0; warn=0; inconclusive=0
LABEL="$(harness_safe_label "$TARGET")"
FX="$(mktemp -d "${TMPDIR:-/tmp}/amc-fx.XXXXXX")"
trap 'rm -rf "$FX"' EXIT

ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
no()   { echo "  FAIL  $1"; fail=$((fail+1)); }
warnr(){ echo "  WARN  $1"; warn=$((warn+1)); }
inc()  { echo "  INCONCLUSIVE  $1"; inconclusive=$((inconclusive+1)); }

# ── markers ──────────────────────────────────────────────────────────────────
# The canonical section marker. It is NOT new and it is NOT a rename: all three
# live host templates (codex, opencode, pi) already write exactly this, which is
# why two hosts collide in one file. The requirement is behavioural — check
# before appending — not onomastic.
SECTION_MARKER='agentic-apps-workflow sections'

# Recognised but foreign: these belong in a host's GLOBAL agents file
# ($CODEX_HOME/AGENTS.md, $OPENCODE_CONFIG_DIR/AGENTS.md), a different file.
# They are listed so a global block pasted into a project file is reported as
# what it is, rather than silently missed for differing by one word.
FOREIGN_MARKERS='codex-workflow global section
opencode-workflow global section'

# Denylist for the host-neutrality check. It has no authoritative source; these
# are the hosts observed in the fleet. A host not on this list cannot be
# detected, which is exactly the case where the warning would be most useful —
# a stated limit, not a solved problem, and the reason this check warns.
#
# Bare `pi` is deliberately absent: two letters match "pipeline", "pick",
# "typing" and most prose containing them, so including it would fire on
# ordinary text far more often than on a host reference. The binding repo name
# is used instead. That is a real gap — a section saying "on the Pi host" is
# not caught — and it is the concrete form of this check's stated partiality.
# This list is the spec's enumerated minimum. It MAY be extended and MUST NOT
# be shrunk — an implementation that shrinks it can claim conformance while
# detecting less, which is the drift this check exists to catch appearing inside
# the check.
HOST_NAMES='codex
opencode
claude
codex-workflow
opencode-workflow
claude-workflow
pi-agentic-apps-workflow'

# Host directories are STRUCTURAL, unlike host names. A bare name may appear in
# neutral prose by coincidence; a path cannot. So names warn and paths fail.
HOST_DIRS='.codex/
.opencode/
.pi/'

begin_lines() { grep -n -- "BEGIN: $SECTION_MARKER" "$TARGET" 2>/dev/null | cut -d: -f1; }
end_lines()   { grep -n -- "END: $SECTION_MARKER"   "$TARGET" 2>/dev/null | cut -d: -f1; }

n_begin=$(begin_lines | grep -c . || true)
n_end=$(end_lines | grep -c . || true)

echo "═══ $LABEL"
echo "  ── A. One section, whatever the agent count ──"

# Does the file list any agents? "At most one" and "exactly one" bind different
# states: a repo with no agents may legitimately carry no section, but one that
# lists an agent and carries none points its agents at a workflow the file does
# not describe. Scoring zero sections as a flat failure would fail every
# never-provisioned repo.
has_agents=0
grep -q '^agents:' "$TARGET" 2>/dev/null && has_agents=1

# 4.2
if [ "$n_begin" -eq 1 ] && [ "$n_end" -eq 1 ]; then
  ok "exactly one workflow section"
elif [ "$n_begin" -eq 0 ] && [ "$n_end" -eq 0 ]; then
  if [ "$has_agents" -eq 1 ]; then
    no "no workflow section, but agents are listed — they point at a workflow this file does not describe"
  else
    ok "no workflow section and no agents listed — 'at most one' is satisfied"
  fi
else
  no "expected one begin/end marker pair, found $n_begin begin and $n_end end"
fi

# 4.3 — report every block with its line range, and never collapse them. The
# copies have drifted, and with both blocks carrying an IDENTICAL marker the
# file records no provenance to choose between them. Reporting and stopping is
# the honest failure; picking silently would ship one drifted copy with the
# authority of having been fixed.
if [ "$n_begin" -gt 1 ]; then
  no "duplicate workflow sections — $n_begin blocks, none collapsed:"
  bl="$(begin_lines)"; el="$(end_lines)"
  i=1
  for b in $bl; do
    e="$(echo "$el" | sed -n "${i}p")"
    echo "          block $i: lines ${b}-${e:-?}"
    i=$((i+1))
  done
  echo "          resolve by hand; nothing in the file says which copy is right"
else
  ok "no duplicate workflow sections to report"
fi

# A global-file marker in a project file is a distinct finding from a duplicate.
# Iterated as a for-loop over newline tokens rather than `... | while read`:
# under bash 3.2 the pipe runs the loop in a subshell and foreign_found would
# never escape it.
foreign_found=0
for m in $(echo "$FOREIGN_MARKERS" | tr ' ' '~'); do
  mm="$(echo "$m" | tr '~' ' ')"
  if grep -q -- "BEGIN: $mm" "$TARGET" 2>/dev/null; then
    no "global-file marker '$mm' present in a project file — wrong file, not a duplicate"
    foreign_found=1
  fi
done
[ "$foreign_found" -eq 0 ] && ok "no global-file markers misplaced into this file"

echo "  ── B. Locatable and removable by markers alone ──"

if [ "$n_begin" -eq 1 ] && [ "$n_end" -eq 1 ]; then
  B="$(begin_lines)"; E="$(end_lines)"

  # 4.4 — the section is found without reading any heading text. Asserted by
  # locating it again in a copy with every ATX heading blanked: if the located
  # range is unchanged, no heading text could have contributed to finding it.
  sed 's/^#.*$//' "$TARGET" > "$FX/noheadings.md"
  B2="$(grep -n -- "BEGIN: $SECTION_MARKER" "$FX/noheadings.md" | cut -d: -f1)"
  E2="$(grep -n -- "END: $SECTION_MARKER" "$FX/noheadings.md" | cut -d: -f1)"
  if [ "$B" = "$B2" ] && [ "$E" = "$E2" ]; then
    ok "section located by markers alone, independent of heading text"
  else
    no "locating the section depended on heading text (${B}-${E} vs ${B2}-${E2})"
  fi

  # 4.5 — removing the section leaves every byte outside the markers unchanged.
  # Built two independent ways and compared. awk throughout: no in-place edit,
  # so no `sed -i` portability trap (see migration lint rule L11).
  awk -v b="$B" -v e="$E" 'NR<b || NR>e' "$TARGET" > "$FX/removed.md"
  awk -v b="$B" 'NR<b' "$TARGET" >  "$FX/expect.md"
  awk -v e="$E" 'NR>e' "$TARGET" >> "$FX/expect.md"
  if cmp -s "$FX/removed.md" "$FX/expect.md"; then
    ok "removal leaves every byte outside the markers unchanged"
  else
    no "removal altered bytes outside the markers"
  fi
else
  inc "marker-only locatability — needs exactly one well-formed marker pair"
  inc "removal purity — needs exactly one well-formed marker pair"
fi

echo "  ── C. Host neutrality (warnings, never failures) ──"

# Frontmatter: the agent links live here, and the section lives in the body, so
# the two are structurally disjoint. The link exemption of 4.7 therefore holds
# by construction rather than by special case — a consequence of carrying the
# links in frontmatter rather than in a marker block inside the section.
FM_END=0
if [ "$(sed -n '1p' "$TARGET")" = "---" ]; then
  FM_END="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$TARGET")"
  FM_END="${FM_END:-0}"
fi
awk -v e="$FM_END" 'NR<=e' "$TARGET" > "$FX/frontmatter.md"

fail_before_neutrality=$fail
dirhits=0

if [ "$n_begin" -eq 1 ] && [ "$n_end" -eq 1 ]; then
  B="$(begin_lines)"; E="$(end_lines)"
  awk -v b="$B" -v e="$E" 'NR>b && NR<e' "$TARGET" > "$FX/body.md"

  # 4.6 — a known host identifier inside the section body WARNS. The check is a
  # denylist: it cannot recognise novel phrasing, so it will both miss cases and
  # occasionally fire on prose that merely mentions a host. Making a partial
  # heuristic blocking is the wrong trade.
  hits=0
  for h in $HOST_NAMES; do
    if grep -qi -- "$h" "$FX/body.md" 2>/dev/null; then
      ln="$(grep -ni -- "$h" "$FX/body.md" | head -1 | cut -d: -f1)"
      warnr "host identifier '$h' in section body (body line ${ln}) — section should describe the workflow, not the agent"
      hits=$((hits+1))
    fi
  done
  [ "$hits" -eq 0 ] && ok "no known host identifier in the section body"

  # 4.8 — a host DIRECTORY outside the frontmatter is structural, not a
  # coincidence of prose, so it fails where a bare name warns.
  for d in $HOST_DIRS; do
    if grep -qF -- "$d" "$FX/body.md" 2>/dev/null; then
      no "host path '$d' in section body — host-specific detail belongs in the host's own directory"
      dirhits=$((dirhits+1))
    fi
  done
  [ "$dirhits" -eq 0 ] && ok "no host-specific paths in the section body"
else
  inc "host-identifier check — needs exactly one well-formed marker pair"
  inc "host-path check — needs exactly one well-formed marker pair"
fi

# 4.6, second half — assert the warnings did not fail the run. Stated as its own
# row because "warns rather than fails" is the requirement, and a requirement
# nothing scores is a requirement nothing holds.
#
# The comparison must isolate the warnings' contribution. Every failure raised
# in this section so far is a host-PATH failure, which is legitimate and
# unrelated; comparing the raw fail count instead reported "a warning was
# counted as a failure" on any file that also had a host path — the check
# firing on the very case it exists to exonerate.
neutrality_fails=$((fail - fail_before_neutrality))
if [ "$neutrality_fails" -eq "$dirhits" ]; then
  ok "host-identifier warnings did not contribute to the failure count ($warn warning(s), $dirhits path failure(s))"
else
  no "a host-identifier warning was counted as a failure ($neutrality_fails failures, only $dirhits from paths)"
fi

echo "  ── D. Agent links ──"

# 4.7 — a host identifier inside a link produces NO warning. Not a refinement
# but a correctness condition: the links are host-specific by design, and a
# check that flagged them would fire on the one thing §12 explicitly permits.
warn_before_links=$warn
link_host_names=0
for h in $HOST_NAMES; do
  grep -qi -- "$h" "$FX/frontmatter.md" 2>/dev/null && link_host_names=$((link_host_names+1))
done
if [ "$warn" -eq "$warn_before_links" ]; then
  if [ "$link_host_names" -gt 0 ]; then
    ok "$link_host_names known host identifier(s) present in the links, none warned on"
  else
    ok "no host identifier in the links to exempt (vacuous, but scored)"
  fi
else
  no "a per-agent link produced a host-identifier warning"
fi

# Each entry's value must be a PATH. A bare identifier records what is installed
# but not where its instructions are, leaving an agent reading the shared file
# with no route to its own — an inventory, not a link.
if grep -q '^agents:' "$FX/frontmatter.md" 2>/dev/null; then
  awk '/^agents:/{f=1;next} f&&/^[^ \t]/{f=0} f&&NF' "$FX/frontmatter.md" > "$FX/entries.txt"
  n_entries="$(grep -c . "$FX/entries.txt" || true)"
  bare=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    val="$(echo "$line" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//')"
    case "$val" in
      */*|*.md) : ;;
      "") bare=$((bare+1)); echo "          entry has no value: $(echo "$line" | tr -d '\n')" ;;
      *)  bare=$((bare+1)); echo "          bare identifier, not a path: $(echo "$line" | tr -d '\n')" ;;
    esac
  done < "$FX/entries.txt"
  if [ "${n_entries:-0}" -eq 0 ]; then
    no "'agents:' present but lists no entries"
  elif [ "$bare" -eq 0 ]; then
    ok "all $n_entries agent entr(y/ies) carry a path, not a bare identifier"
  else
    no "$bare of $n_entries agent entries are inventory, not links — nothing reaches those agents' instructions"
  fi

  # Path safety. These values are consumed by tooling that DELETES and by agents
  # that read. A path escaping the repo turns removal into deletion of something
  # never provisioned; an absolute path additionally bakes the machine's layout
  # — a home directory carries a username — into a committed file.
  unsafe=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    val="$(echo "$line" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//')"
    case "$val" in
      /*)        no "absolute path in agent entry: $val"; unsafe=$((unsafe+1)) ;;
      ~*)        no "home-relative path in agent entry: $val"; unsafe=$((unsafe+1)) ;;
      *://*)     no "URL in agent entry: $val"; unsafe=$((unsafe+1)) ;;
      ../*|*/../*|*/..) no "upward traversal in agent entry: $val"; unsafe=$((unsafe+1)) ;;
    esac
  done < "$FX/entries.txt"
  [ "$unsafe" -eq 0 ] && ok "every agent entry path is repository-relative and does not escape the repo"

  # A duplicate identifier is reported, never deduplicated — the two entries may
  # name different paths, and choosing between them is exactly as unmechanical
  # as choosing between two drifted sections.
  dupes="$(sed 's/^[[:space:]]*//; s/[[:space:]]*:.*//' "$FX/entries.txt" | grep -v '^$' | LC_ALL=C sort | uniq -d)"
  if [ -z "$dupes" ]; then
    ok "no duplicate agent identifiers"
  else
    no "duplicate agent identifier(s): $(echo "$dupes" | tr '\n' ' ')— not deduplicated, they may name different paths"
  fi
else
  inc "agent link entries — no 'agents:' frontmatter key present"
  inc "agent entry path safety — no 'agents:' frontmatter key present"
  inc "duplicate agent identifiers — no 'agents:' frontmatter key present"
fi

# The section content version. Without it, first-writer-wins makes the section's
# prose permanent: adding an agent is a no-op once present and the
# byte-identical rule forbids a later host rewriting it, so a repo provisioned
# from a template citing a since-deleted system cites it forever.
if [ "$n_begin" -eq 1 ] && [ "$n_end" -eq 1 ]; then
  if grep -qE 'section-version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$FX/body.md" 2>/dev/null; then
    ok "the section carries a content version, so staleness is detectable"
  else
    no "the section carries no content version — stale prose has no supported repair path"
  fi
else
  inc "section content version — needs exactly one well-formed marker pair"
fi

echo "  ── E. Agent lifecycle ──"

# Preflight the hashing tool rather than letting an empty snapshot compare equal
# to another empty snapshot. Without this every byte-identical assertion below
# passes vacuously on a box with neither shasum nor sha256sum, and the run
# reports conformance it never established.
HASHER=""
if command -v shasum >/dev/null 2>&1; then HASHER="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then HASHER="sha256sum"
fi

sha_of() { $HASHER "$1" 2>/dev/null | awk '{print $1}'; }

# "path<TAB>hash" for every file, sorted. Content AND layout, so a row asserting
# a tree is unchanged catches a file that moved as well as one that was edited.
tree_snapshot() { # $1 = dir
  ( cd "$1" 2>/dev/null || return 1
    find . -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s\t%s\n' "$f" "$(sha_of "$f")"
    done )
}

# The marker block only. Distinct from the whole file, because the section is
# where the byte-identical claim is made — the frontmatter is expected to change.
section_bytes() { # $1 = repo dir
  local f="$1/AGENTS.md" b e
  [ -f "$f" ] || return 1
  b="$(grep -n -- "BEGIN: $SECTION_MARKER" "$f" 2>/dev/null | head -1 | cut -d: -f1)"
  e="$(grep -n -- "END: $SECTION_MARKER" "$f" 2>/dev/null | head -1 | cut -d: -f1)"
  [ -n "$b" ] && [ -n "$e" ] || return 1
  awk -v b="$b" -v e="$e" 'NR>=b && NR<=e' "$f"
}

# How many sections the file carries. Required alongside section_bytes(), not
# implied by it: section_bytes() reads the FIRST begin to the FIRST end, so a
# host that appends a duplicate block leaves the first one byte-identical and
# every "section unchanged" assertion passes. That is precisely the defect this
# capability exists to prevent, so it needs its own row rather than riding on a
# comparison that cannot see it.
section_count() { # $1 = repo dir
  grep -c -- "BEGIN: $SECTION_MARKER" "$1/AGENTS.md" 2>/dev/null || echo 0
}

entry_of() { # $1 = repo dir, $2 = agent id
  [ -f "$1/AGENTS.md" ] || return 1
  awk '/^agents:/{f=1;next} f&&/^[^ \t]/{f=0} f' "$1/AGENTS.md" 2>/dev/null |
    grep -E "^[[:space:]]*$2[[:space:]]*:" || return 1
}

# Unquoted on purpose: the caller's command may carry arguments
# ("bash /path/install.sh --quiet"), which a quoted expansion would pass as one
# filename. The repo dir and agent id stay quoted.
# shellcheck disable=SC2086
run_add()    { $AGENTS_MD_ADD_CMD    "$1" "$2" >"$FX/out.log" 2>&1; }
# shellcheck disable=SC2086
run_remove() { $AGENTS_MD_REMOVE_CMD "$1" "$2" >"$FX/out.log" 2>&1; }

if [ -z "${AGENTS_MD_ADD_CMD:-}" ] || [ -z "${AGENTS_MD_REMOVE_CMD:-}" ]; then
  # Named, counted and reported rather than skipped silently. §20: an
  # inconclusive row MUST NOT count toward the scored total.
  echo "          AGENTS_MD_ADD_CMD / AGENTS_MD_REMOVE_CMD unset — core cannot"
  echo "          provision an agent into a repo it does not own, and the"
  echo "          installers live in the host repos. Set both to score these."
  inc "5.1 add is idempotent"
  inc "5.2 a second agent adds only its link"
  inc "5.3 removing one agent touches only that agent"
  inc "5.4 removing an absent agent reports and changes nothing"
  inc "5.5 partial presence is removed and reported, not failed"
  inc "5.6 tool-owned state is reported and left in place"
  inc "5.7 first agent adds section and link"
  inc "5.8 last agent leaves, section survives"
  inc "5.9 re-add to a sectioned repo adds only the link"
elif [ -z "$HASHER" ]; then
  echo "          neither shasum nor sha256sum found — every byte-identical" >&2
  echo "          assertion below would pass vacuously." >&2
  inc "5.1-5.9 agent lifecycle — no hashing tool available"
else
  A1="${AGENTS_MD_AGENT_A:-codex}"
  A2="${AGENTS_MD_AGENT_B:-pi}"
  n=0
  newrepo() { n=$((n+1)); R="$FX/repo$n"; mkdir -p "$R"; printf '# Project\n\nUnrelated prose.\n' > "$R/AGENTS.md"; }

  # 5.7 — the first-agent boundary writes BOTH the section and the link.
  newrepo
  run_add "$R" "$A1"
  if section_bytes "$R" >/dev/null 2>&1 && entry_of "$R" "$A1" >/dev/null 2>&1; then
    ok "5.7 first agent adds the section and its link"
  else
    no "5.7 first agent did not add both the section and its link"
  fi

  # 5.1 — adding twice produces one provision and one no-op.
  SNAP_A="$(tree_snapshot "$R")"
  run_add "$R" "$A1"; add2_rc=$?
  SNAP_B="$(tree_snapshot "$R")"
  if [ "$SNAP_A" = "$SNAP_B" ]; then
    ok "5.1 re-adding an agent left every file byte-identical"
  else
    no "5.1 re-adding an agent changed files"
  fi
  if [ "$add2_rc" -eq 0 ] && grep -qi -e 'already' -e 'present' -e 'no-op' "$FX/out.log" 2>/dev/null; then
    ok "5.1 re-add reported the agent as already present"
  else
    no "5.1 re-add did not report the agent as already present (exit $add2_rc)"
  fi

  # 5.2 — a second agent adds ONLY its link. This is the behaviour whose
  # absence produced the duplicate state in the first place.
  SEC_BEFORE="$(section_bytes "$R")"
  E1_BEFORE="$(entry_of "$R" "$A1")"
  run_add "$R" "$A2"
  SEC_AFTER="$(section_bytes "$R")"
  E1_AFTER="$(entry_of "$R" "$A1")"
  if [ "$SEC_BEFORE" = "$SEC_AFTER" ]; then
    ok "5.2 second agent left the host-neutral section byte-identical"
  else
    no "5.2 second agent rewrote the host-neutral section"
  fi
  # The cparx bug in its original form. A host that appends rather than checks
  # leaves the first block untouched, so the row above cannot see it.
  n_sec="$(section_count "$R")"
  if [ "$n_sec" -eq 1 ]; then
    ok "5.2 second agent added no second section"
  else
    no "5.2 second agent appended a duplicate section ($n_sec now present)"
  fi
  if [ "$E1_BEFORE" = "$E1_AFTER" ] && entry_of "$R" "$A2" >/dev/null 2>&1; then
    ok "5.2 second agent added its own link and left the first's unchanged"
  else
    no "5.2 second agent disturbed the first agent's link, or added none of its own"
  fi

  # 5.3 — removing one of several touches only that agent.
  OTHER_BEFORE="$(tree_snapshot "$R/.$A2" 2>/dev/null)"
  SEC_BEFORE="$(section_bytes "$R")"
  run_remove "$R" "$A1"
  OTHER_AFTER="$(tree_snapshot "$R/.$A2" 2>/dev/null)"
  if [ ! -d "$R/.$A1" ] && ! entry_of "$R" "$A1" >/dev/null 2>&1; then
    ok "5.3 removal deleted the departing agent's directory and link"
  else
    no "5.3 removal left the departing agent's directory or link behind"
  fi
  if [ "$OTHER_BEFORE" = "$OTHER_AFTER" ] && entry_of "$R" "$A2" >/dev/null 2>&1 &&
     [ "$SEC_BEFORE" = "$(section_bytes "$R")" ]; then
    ok "5.3 removal left the other agent and the section untouched"
  else
    no "5.3 removal disturbed another agent or the host-neutral section"
  fi

  # 5.4 — removing an agent that is not there reports, and changes nothing.
  SNAP_A="$(tree_snapshot "$R")"
  run_remove "$R" "$A1"; rm_rc=$?
  if [ "$SNAP_A" = "$(tree_snapshot "$R")" ]; then
    ok "5.4 removing an absent agent changed nothing"
  else
    no "5.4 removing an absent agent changed files"
  fi
  if [ "$rm_rc" -eq 0 ] && grep -qi -e 'not present' -e 'not found' -e 'absent' "$FX/out.log" 2>/dev/null; then
    ok "5.4 removing an absent agent reported it as not present"
  else
    no "5.4 removing an absent agent did not report it as not present (exit $rm_rc)"
  fi

  # 5.8 — the last agent leaves and the section SURVIVES. Symmetry is the wrong
  # goal: a repo briefly without an agent would lose documentation it is about
  # to want back.
  run_remove "$R" "$A2"
  if section_bytes "$R" >/dev/null 2>&1; then
    ok "5.8 the host-neutral section survived the last agent leaving"
  else
    no "5.8 the host-neutral section was removed with the last agent"
  fi
  if ! entry_of "$R" "$A2" >/dev/null 2>&1 && grep -q 'Unrelated prose' "$R/AGENTS.md" 2>/dev/null; then
    ok "5.8 the departing link went and unrelated content was preserved"
  else
    no "5.8 the departing link survived, or unrelated content was lost"
  fi

  # 5.9 — re-adding to a repo that has the section but no agents adds only the
  # link. The section must not be rewritten just because nothing is installed.
  SEC_BEFORE="$(section_bytes "$R")"
  run_add "$R" "$A1"
  if [ "$SEC_BEFORE" = "$(section_bytes "$R")" ] && entry_of "$R" "$A1" >/dev/null 2>&1 &&
     [ "$(section_count "$R")" -eq 1 ]; then
    ok "5.9 re-add to a sectioned repo added only the link"
  else
    no "5.9 re-add to a sectioned repo rewrote or duplicated the section, or added no link"
  fi

  # 5.5 — partial presence is a first-class state, not a failure. Both vestigial
  # hosts in the observed repo were half-installed: a config with no skills, and
  # a directory never committed at all.
  newrepo
  mkdir -p "$R/.$A1"
  printf 'stub config\n' > "$R/.$A1/workflow-config.md"
  run_remove "$R" "$A1"; rm_rc=$?
  if [ "$rm_rc" -eq 0 ] && [ ! -d "$R/.$A1" ]; then
    ok "5.5 partial presence removed what was there without failing"
  else
    no "5.5 partial presence failed or left the directory behind (exit $rm_rc)"
  fi
  if grep -qi -e 'missing' -e 'absent' -e 'not found' -e 'expected' "$FX/out.log" 2>/dev/null; then
    ok "5.5 partial presence reported which expected artifacts were absent"
  else
    no "5.5 partial presence removed silently, reporting nothing about what was missing"
  fi

  # 5.10 — convergence from a partial provision. The directory exists but the
  # entry does not; provisioning must ADD the entry, not report "already
  # present". Treating the directory as sufficient makes this state permanent —
  # no number of re-runs ever adds the missing entry.
  newrepo
  mkdir -p "$R/.$A1"
  printf '# %s\n' "$A1" > "$R/.$A1/AGENTS.md"
  run_add "$R" "$A1"; conv_rc=$?
  if entry_of "$R" "$A1" >/dev/null 2>&1; then
    ok "5.10 provisioning converged a directory-without-entry state"
  else
    no "5.10 provisioning left a directory-without-entry state unconverged (exit $conv_rc)"
  fi
  if grep -qi -e 'already present' "$FX/out.log" 2>/dev/null; then
    no "5.10 a partial provision was reported as already present"
  else
    ok "5.10 a partial provision was not reported as already present"
  fi

  # 5.11 — the entry exists but the directory does not: the mirror state.
  newrepo
  run_add "$R" "$A1"
  rm -rf "$R/.$A1"
  run_add "$R" "$A1"
  if [ -d "$R/.$A1" ]; then
    ok "5.11 provisioning converged an entry-without-directory state"
  else
    no "5.11 provisioning left an entry-without-directory state unconverged"
  fi

  # 5.6 — tool-owned state is reported, not deleted. The workflow did not
  # install it and does not know what depends on it.
  newrepo
  mkdir -p "$R/.$A1/node_modules/leftpad"
  printf 'stub config\n' > "$R/.$A1/workflow-config.md"
  printf '{"name":"x"}\n' > "$R/.$A1/package.json"
  printf 'module.exports=1\n' > "$R/.$A1/node_modules/leftpad/index.js"
  run_remove "$R" "$A1"
  if [ -f "$R/.$A1/package.json" ] && [ -f "$R/.$A1/node_modules/leftpad/index.js" ]; then
    ok "5.6 tool-owned state was left in place"
  else
    no "5.6 tool-owned state was deleted — the workflow did not install it"
  fi
  if grep -qi -e 'package.json' -e 'node_modules' -e 'not installed' -e 'left in place' "$FX/out.log" 2>/dev/null; then
    ok "5.6 tool-owned state was reported"
  else
    no "5.6 tool-owned state was left silently, with nothing reported"
  fi
  # The directory must SURVIVE here — it is not empty. This is the other half of
  # the reconciliation: "removal is one directory" holds only when nothing else
  # is in it, and asserting the directory is gone would contradict 5.6 above.
  if [ -d "$R/.$A1" ]; then
    ok "5.6 the directory survived because tool-owned state remained in it"
  else
    no "5.6 the directory was removed despite still holding tool-owned state"
  fi
fi

echo ""
echo "═══ TOTAL: $pass passed, $fail failed, $warn warning(s), $inconclusive inconclusive"
if [ "$inconclusive" -gt 0 ]; then
  echo "    $inconclusive row(s) reached no verdict and are excluded from the scored total."
fi

# Backstop, folded into the one place the exit code is computed. This harness
# aborts before any row on an unscoreable target, so it is normally unreachable
# — it exists because a scored total of zero is the observable every route to
# certifying nothing shares.
if [ $((pass + fail)) -eq 0 ]; then
  echo "openspec-conformance: certified NOTHING — no row reached a verdict" >&2
  exit 1
fi
[ "$fail" -eq 0 ]
