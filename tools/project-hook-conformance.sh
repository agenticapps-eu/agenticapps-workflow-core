#!/usr/bin/env bash
# project-hook-conformance.sh — report every project's shim state, by name.
#
# A version marker with no check makes nothing detectable. This is the tool that
# turns `# shim-contract:` from a comment into a property someone can observe
# (change task 2.9c), and the tool that surfaces override vectors for review
# (2.7c, 2.7c-i).
#
# Usage:
#   tools/project-hook-conformance.sh [--strict] [--overrides-only]
#                                     [--fleet <root>] <project-dir>...
#
#   --strict          exit 1 if any finding was reported (for CI)
#   --overrides-only  skip the marker report; scan override vectors only
#   --fleet <root>    resolve every repository DECLARED in FLEET beneath <root>
#                     and scan it; a declared repository that resolves nowhere
#                     is reported as a finding, never as silence. This is what
#                     makes a contract propagation reproducible from the
#                     repository instead of from a list someone typed once.
#
# WHAT --fleet MEASURES, stated because it is easy to over-read: it scores the
# WORKING TREE of each repository — whatever branch happens to be checked out on
# this machine right now. Observed during the 1.1.0 rollout: a concurrent session
# switched one repo's checkout to an unrelated branch between two runs, and the
# second run reported it stale while the propagated shims sat safely on the
# pushed branch. That is the tool being right about the disk, not wrong about the
# rollout. To score what a branch actually carries, compare
# `git show <ref>:.claude/hooks/<hook>.sh` against the authority instead.
#
# Default exit is 0 even with findings: like the §18 gate since 2.0.0, this
# tool REPORTS. Blocking is reserved for what is an error rather than an
# absence.
#
# It never modifies anything, and it never suppresses an override at runtime.
# The value takes effect — that is exactly why it has to surface in review.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="${SHIM_TEMPLATE:-$ROOT/reference-implementations/project-hooks/shim-template.sh}"

# The hooks bound through a shim, DECLARED rather than hardcoded here.
#
# This array used to be a literal while install-project-hooks.sh and
# provisioning-check.sh both read a declaration file — one fleet, two expected
# sets, maintained in two places (Stage-2 finding 7). SHIMMED-HOOKS explains in
# its own header why it is a different set from ARTIFACTS.
#
# The override variable name is derived the same way the shim derives it, so the
# two cannot drift apart.
DECL="${SHIMMED_HOOKS_DECL:-$ROOT/reference-implementations/project-hooks/SHIMMED-HOOKS}"
SHIMMED_HOOKS=()
if [ -f "$DECL" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && SHIMMED_HOOKS+=("$line")
  done < "$DECL"
fi
if [ "${#SHIMMED_HOOKS[@]}" -eq 0 ]; then
  echo "project-hook-conformance: no shimmed-hook declaration at $DECL" >&2
  echo "  Without it this tool would scan an empty set and report every project" >&2
  echo "  green. Refusing to report." >&2
  exit 65
fi

# Declared non-bindings. A repository may deliberately not bind a shimmed hook,
# and once an absent shim is REPORTED rather than skipped, that opt-out is
# indistinguishable from a deletion unless it is declared. Absent file = no
# declared opt-outs, which is a stricter reading, not a looser one.
OPT_OUTS_DECL="${OPT_OUTS_DECL:-$ROOT/reference-implementations/project-hooks/OPT-OUTS}"

# $1=repo name, $2=hook. Echoes the reason and returns 0 when declared.
opt_out_reason() {
  local want_repo="$1" want_hook="$2" line repo hook reason
  [ -f "$OPT_OUTS_DECL" ] || return 1
  while IFS= read -r line; do
    line="${line%%#*}"
    [ -n "${line// /}" ] || continue
    read -r repo hook reason <<<"$line"
    if [ "$repo" = "$want_repo" ] && [ "$hook" = "$want_hook" ]; then
      printf '%s' "$reason"
      return 0
    fi
  done < "$OPT_OUTS_DECL"
  return 1
}

# Declared tool coverage per hook, read the same way as every other declaration.
MATCHERS_DECL="${MATCHERS_DECL:-$ROOT/reference-implementations/project-hooks/MATCHERS}"

STRICT=0
OVERRIDES_ONLY=0
FLEET_ROOT=""
PROJECTS=()
want_root=0
for a in "$@"; do
  if [ "$want_root" -eq 1 ]; then FLEET_ROOT="$a"; want_root=0; continue; fi
  case "$a" in
    --strict)         STRICT=1 ;;
    --overrides-only) OVERRIDES_ONLY=1 ;;
    --fleet)          want_root=1 ;;
    -*) echo "project-hook-conformance: unknown option '$a'" >&2; exit 64 ;;
    *)  PROJECTS+=("$a") ;;
  esac
done
# Guarded like its sibling (Stage-2 finding 8): a value-taking option with no
# value exits 64 rather than proceeding with an empty root, which would resolve
# every declared repository to nothing and report the whole fleet absent.
if [ "$want_root" -eq 1 ]; then
  echo "project-hook-conformance: --fleet requires a root directory" >&2
  exit 64
fi

findings=0

# --- the declared fleet -----------------------------------------------------
# Repositories are DECLARED, not discovered, for the reason ARTIFACTS and
# SHIMMED-HOOKS are: a set derived from what you found cannot detect a missing
# member, so a repository that never got the contract bump would look exactly
# like one that passed. FLEET's own header carries the argument.
#
# Names, not paths — a path is a fact about one machine. Each name is resolved
# beneath the given root, and one that resolves nowhere is a FINDING.
if [ -n "$FLEET_ROOT" ]; then
  FDECL="${FLEET_DECL:-$ROOT/reference-implementations/project-hooks/FLEET}"
  if [ ! -f "$FDECL" ]; then
    echo "project-hook-conformance: no fleet declaration at $FDECL" >&2
    echo "  Without it --fleet would scan an empty set and report nothing," >&2
    echo "  which is indistinguishable from a fleet that is fully conformant." >&2
    echo "  Refusing to report." >&2
    exit 65
  fi
  if [ ! -d "$FLEET_ROOT" ]; then
    echo "project-hook-conformance: --fleet root '$FLEET_ROOT' is not a directory" >&2
    exit 66
  fi
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] || continue
    # Depth 2, because the fleet is checked out one family directory below the
    # root on this machine and directly below it elsewhere. Bounded so the
    # lookup cannot wander into unrelated trees.
    found=$(find "$FLEET_ROOT" -maxdepth 2 -type d -name "$line" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
      echo "FLEET   $line  found at ${found#"$FLEET_ROOT"/}"
      PROJECTS+=("$found")
    else
      echo "FLEET   $line  not found under $FLEET_ROOT — declared but unreachable, so its binders were NOT checked"
      findings=$((findings + 1))
    fi
  done < "$FDECL"
fi

if [ "${#PROJECTS[@]}" -eq 0 ]; then
  echo "usage: project-hook-conformance.sh [--strict] [--overrides-only] [--fleet <root>] <project-dir>..." >&2
  exit 64
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "project-hook-conformance: template not found at $TEMPLATE" >&2
  echo "  The template — not any project copy — is the authority for conformance," >&2
  echo "  so without it nothing here can be judged. Refusing to report." >&2
  exit 65
fi

TEMPLATE_VERSION=$(grep -m1 '^# shim-contract:' "$TEMPLATE" | awk '{print $3}')
if ! printf '%s' "$TEMPLATE_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "project-hook-conformance: template carries no well-formed '# shim-contract:' marker" >&2
  exit 65
fi

# semver compare, shared with provisioning-check.sh. It moved out of this file
# when a second caller appeared: two copies would have been free to drift, and a
# divergent ordering fails silently — a lexical compare puts 1.10.0 below 1.9.0
# and hands the operator the opposite remedy.
if [ ! -f "$SCRIPT_DIR/lib/semver.sh" ]; then
  echo "project-hook-conformance: $SCRIPT_DIR/lib/semver.sh is missing." >&2
  echo "  Marker direction cannot be computed without it. Refusing to report." >&2
  exit 65
fi
# shellcheck source=lib/semver.sh
. "$SCRIPT_DIR/lib/semver.sh"

# The variable the shim template derives for a hook. The shim derives it the
# same way, so the two cannot drift apart.
override_var() { printf '%s_OVERRIDE' "$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"; }

# Variables that override a hook but do NOT follow the derivation rule.
#
# openspec-change-gate predates this contract and resolves $OPENSPEC_GATE. A
# scan that only knew the derived name would report the seven projects green on
# that hook while a one-variable bypass of the §18 gate sat unexamined — the
# scan would be measuring a variable nothing reads. Once task 4b migrates that
# shim onto this contract the derived name applies too, so both are searched
# and neither is dropped in the meantime.
legacy_override_vars() {
  case "$1" in
    openspec-change-gate) printf 'OPENSPEC_GATE\nOPENSPEC_CHANGE_GATE\n' ;;
    *) : ;;
  esac
}

# ---------------------------------------------------------------------------
# Marker state, per bound hook, per project.
#
# Four states, and the fourth is the one that is easy to get wrong. A marker
# HIGHER than the template's is unrecognised, not "newer and fine": the
# template in core is the authority, so a project ahead of it is carrying
# something core cannot account for.
# ---------------------------------------------------------------------------
report_markers() {
  local proj="$1" name hook shim marker cmp
  name=$(basename "$proj")

  for hook in "${SHIMMED_HOOKS[@]}"; do
    shim="$proj/.claude/hooks/$hook.sh"

    # ABSENCE IS A STATE, NOT THE LACK OF ONE. Both this axis and the identity
    # axis below used to `continue` here, so a project with no shim at all
    # contributed nothing and the total read clean — the strongest false
    # clearance the instrument could emit, and the same `|| continue` shape as
    # the currency-table defect repaired on 2026-08-04 in provisioning-check.sh.
    if [ ! -f "$shim" ]; then
      local reason
      if reason=$(opt_out_reason "$name" "$hook"); then
        echo "MARKER  $name  $hook  declared opt-out — $reason"
        # An opt-out excuses the missing file. It does not excuse a live
        # registration for it: settings.json would then point the host at a
        # path that does not exist, and every matched call would error.
        if [ -f "$proj/.claude/settings.json" ] \
           && grep -q "/$hook\.sh" "$proj/.claude/settings.json"; then
          echo "REGISTRATION  $name  $hook  declared opt-out, but settings.json still registers it — it points at a file that is not there"
          findings=$((findings + 1))
        fi
      else
        echo "MARKER  $name  $hook  ABSENT — this hook is declared shimmed and no shim file is present"
        findings=$((findings + 1))
      fi
      continue
    fi

    marker=$(head -10 "$shim" | grep -m1 '^# shim-contract:' | awk '{print $3}')

    if [ -z "$marker" ]; then
      echo "MARKER  $name  $hook  unrecognised — no '# shim-contract:' marker in the first 10 lines"
      findings=$((findings + 1))
      continue
    fi
    if ! printf '%s' "$marker" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "MARKER  $name  $hook  unrecognised — malformed marker '$marker'"
      findings=$((findings + 1))
      continue
    fi

    cmp=$(semver_cmp "$marker" "$TEMPLATE_VERSION")
    case "$cmp" in
      0)  echo "MARKER  $name  $hook  current ($marker)" ;;
      -1) echo "MARKER  $name  $hook  stale — carries $marker, template is $TEMPLATE_VERSION"
          findings=$((findings + 1)) ;;
      1)  echo "MARKER  $name  $hook  unrecognised — carries $marker, ahead of the template's $TEMPLATE_VERSION; core cannot account for it"
          findings=$((findings + 1)) ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Shim identity — the file, not just the marker.
#
# Stage-2 finding 5. The template in core is "the authority", but until this
# existed the only thing compared was a version string. A project could add
# behaviour to its shim, reorder resolution, or drop the fail-open path and
# still report `current`, because nothing read the rest of the file. The marker
# attested a string about the file rather than the file.
#
# The render is deterministic — a project shim is the template with @@HOOK@@
# substituted — so byte-identity within a profile is mechanically checkable.
#
# THE GATE SHIM IS ITS OWN AUTHORITY. It is a hand-maintained sibling of the
# template rather than a render of it (the two must be edited together), so it
# is compared against the reference copy core ships.
#
# THE SELF-HOSTING BINDER IS EXEMPT, AND EXEMPT IS NOT THE SAME AS PASSING.
# Byte-identity is required WITHIN a profile, never across profiles. Core's own
# gate hook resolves its working tree by design (ADR-0028), so scoring it
# against the project render would report a deliberate inversion as drift. It is
# recorded as out of profile — the marker and fail-open clauses still bind it,
# and those are checked above like any other binder's.
expected_shim_for() { # $1 = hook -> path of a file holding the expected bytes, or empty
  local hook="$1"
  case "$hook" in
    openspec-change-gate)
      printf '%s' "$ROOT/reference-implementations/project-hooks/openspec-change-gate.shim.sh" ;;
    *)
      local rendered="$TMPDIR_IDENT/$hook.expected"
      [ -f "$rendered" ] || sed "s/@@HOOK@@/$hook/g" "$TEMPLATE" > "$rendered"
      printf '%s' "$rendered" ;;
  esac
}

TMPDIR_IDENT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_IDENT"' EXIT

report_identity() {
  local proj="$1" name hook shim expected
  name=$(basename "$proj")
  local resolved; resolved="$(cd "$proj" 2>/dev/null && pwd)" || return 0

  for hook in "${SHIMMED_HOOKS[@]}"; do
    shim="$proj/.claude/hooks/$hook.sh"
    # Reported once, on the marker axis, which is the axis that reads the file
    # first. Counting the same absence twice would inflate the total and make
    # two findings out of one fact — but it is not skipped in silence either:
    # the line below says what was not compared and why.
    if [ ! -f "$shim" ]; then
      echo "IDENTITY  $name  $hook  not compared — no shim file (see MARKER above)"
      continue
    fi

    if [ "$resolved" = "$ROOT" ]; then
      echo "IDENTITY  $name  $hook  self-hosting — out of profile, byte-identity does not bind across profiles (ADR-0028)"
      continue
    fi

    expected="$(expected_shim_for "$hook")"
    if [ ! -f "$expected" ]; then
      echo "IDENTITY  $name  $hook  cannot judge — no authority file at $expected"
      findings=$((findings + 1))
      continue
    fi
    if cmp -s "$shim" "$expected"; then
      echo "IDENTITY  $name  $hook  matches the template"
    else
      echo "IDENTITY  $name  $hook  DIFFERS from the authority in core — a shim carries no behaviour of its own, so any difference is drift or an edit"
      findings=$((findings + 1))
    fi
  done
}

# ---------------------------------------------------------------------------
# Registration coverage — the matcher, not the file.
#
# A shim can be current, byte-identical and never fire. Five repositories
# registered database-sentinel on `Bash|Edit|Write` while the implementation
# declared `Bash|Edit|Write|MultiEdit`, so a MultiEdit to .env invoked nothing —
# protection absent rather than degraded, and every existing axis reported those
# repositories clean, because none of them read a matcher.
#
# NARROWER is a finding: the hook does not fire where it is meant to. WIDER is
# reported and not counted: a project may guard more than the fleet requires, and
# calling that non-conformant would push projects toward removing coverage.
#
# NOT REGISTERED AT ALL is a finding, and it is the case this axis missed on its
# first revision. `seen.get(hook, [])` yields an empty list for a hook no entry
# names, the loop body never runs, and nothing is printed — so a shim that is
# current, byte-identical and wired to nothing scored clean on every axis. That
# is the same absence-reads-as-clean shape the marker axis was repaired for in
# this change, surviving in the axis added to repair it, and it is the worse of
# the two directions this header already distinguishes: protection ABSENT rather
# than degraded. It matters most where this instrument is about to be relied on
# — the propagation rewrites settings.json in five repositories, and a dropped
# registration is the plausible mistake there.
#
# A DECLARED OPT-OUT is exempt, on the same terms as the marker axis: for a hook
# a project deliberately does not bind, no registration is the correct state, and
# reporting it would make the declaration mean nothing here.
#
# JSON is parsed with python3 where it exists. Where it does not, the axis says
# it did not run — a check that quietly skips is the failure this whole change is
# about, and "not checked" is a different sentence from "checked and clean".
# ---------------------------------------------------------------------------
report_matchers() {
  local proj="$1" name settings
  name=$(basename "$proj")
  settings="$proj/.claude/settings.json"

  [ -f "$MATCHERS_DECL" ] || { echo "MATCHER  $name  not checked — no declaration at $MATCHERS_DECL"; return 0; }
  [ -f "$settings" ]      || { echo "MATCHER  $name  not checked — no .claude/settings.json"; return 0; }
  if ! command -v python3 >/dev/null 2>&1; then
    echo "MATCHER  $name  not checked — python3 unavailable, so settings.json was not parsed"
    return 0
  fi

  # The opt-out set for this project, resolved by the same reader the marker
  # axis uses so the two axes cannot disagree about what is declared.
  local opted="" hook
  for hook in "${SHIMMED_HOOKS[@]}"; do
    if opt_out_reason "$name" "$hook" >/dev/null; then
      opted="$opted,$hook"
    fi
  done

  local out
  out=$(python3 - "$settings" "$MATCHERS_DECL" "$name" "$opted" <<'PY'
import json, sys

settings, decl, name = sys.argv[1], sys.argv[2], sys.argv[3]
opted = set(h for h in sys.argv[4].split(",") if h)

expected = {}
for line in open(decl):
    line = line.split("#", 1)[0].strip()
    if not line:
        continue
    hook, event, matcher = line.split(None, 2)
    expected[hook] = (event, set(matcher.split("|")))

try:
    cfg = json.load(open(settings))
except Exception as e:
    print("MATCHER  %s  not checked — settings.json did not parse (%s)" % (name, e))
    sys.exit(0)

seen = {}
for event, entries in (cfg.get("hooks") or {}).items():
    for entry in entries or []:
        matcher = entry.get("matcher") or ""
        for h in entry.get("hooks") or []:
            cmd = h.get("command") or ""
            for hook in expected:
                if "/%s.sh" % hook in cmd:
                    seen.setdefault(hook, []).append((event, matcher))

for hook, (want_event, want_tools) in sorted(expected.items()):
    registrations = seen.get(hook, [])
    if not registrations:
        if hook in opted:
            print("MATCHER  %s  %s  not registered — declared opt-out, which is the "
                  "correct state for it" % (name, hook))
        else:
            print("MATCHER  %s  %s  not registered — settings.json names no entry for "
                  "it, so the hook never fires for any tool  FINDING" % (name, hook))
        continue
    for event, matcher in registrations:
        tools = set(t for t in matcher.split("|") if t)
        missing = want_tools - tools
        extra = tools - want_tools
        if event != want_event:
            print("MATCHER  %s  %s  registered on %s, declared %s  FINDING"
                  % (name, hook, event, want_event))
        if missing:
            print("MATCHER  %s  %s  does not cover %s — registered '%s', declared '%s'  FINDING"
                  % (name, hook, "|".join(sorted(missing)), matcher, "|".join(sorted(want_tools))))
        elif extra:
            print("MATCHER  %s  %s  wider than declared (also %s) — reported, not a finding"
                  % (name, hook, "|".join(sorted(extra))))
        else:
            print("MATCHER  %s  %s  covers the declared set (%s)" % (name, hook, matcher))
PY
)
  [ -n "$out" ] || return 0
  printf '%s\n' "$out" | sed 's/  FINDING$//'
  local n
  n=$(printf '%s\n' "$out" | grep -c 'FINDING$' || true)
  findings=$((findings + n))
}

# ---------------------------------------------------------------------------
# Override vectors.
#
# Five vectors, because settings.json is not the only way a repository can put
# an override into the operator's environment. At runtime none of these is
# distinguishable from the operator's own export — a behaviour-free shim reads
# $VAR and has no provenance to inspect — so the answer is to surface them for
# review, not to suppress them.
# ---------------------------------------------------------------------------
report_override_vectors() {
  local proj="$1" name hook var hit vars
  name=$(basename "$proj")

  for hook in "${SHIMMED_HOOKS[@]}"; do
   vars=$(printf '%s\n' "$(override_var "$hook")"; legacy_override_vars "$hook")
   while IFS= read -r var; do
    [ -n "$var" ] || continue

    # Vector 1 — settings files the host merges.
    for f in "$proj/.claude/settings.json" "$proj/.claude/settings.local.json"; do
      [ -f "$f" ] || continue
      if grep -q "\"$var\"" "$f"; then
        echo "OVERRIDE-VECTOR  $name  $var  settings.json (env block) — $(basename "$f")"
        findings=$((findings + 1))
      fi
    done

    # Vectors 2–5 — direnv, bootstrap/setup scripts, task runners, and docs
    # that tell a human to export it.
    # Bounded deliberately. Vendored trees are not repository-supplied config —
    # nobody sets a workflow override in node_modules — and scanning them turns
    # a sub-second check into one nobody runs. Excluded dirs are listed rather
    # than pruned by heuristic so what is NOT searched stays visible.
    # Whole variable name, never a substring. OPENSPEC_GATE is a prefix of
    # OPENSPEC_GATE_STRICT and OPENSPEC_GATE_SELF, which are different
    # variables entirely; a substring match reported three sites across two
    # repos that set no override at all. `_` is a word character, so this
    # bracket form (rather than \b) is what actually excludes them.
    #
    # It matches a NAME, not an assignment. Prose that names the variable
    # without setting it is reported too. That bias is deliberate: this scan
    # exists to surface candidates for a human to read, and over-reporting
    # costs a glance whereas under-reporting is what makes the check useless.
    hit=$(grep -rlE "(^|[^A-Za-z0-9_])${var}([^A-Za-z0-9_]|\$)" \
            --include='.envrc' --include='*.sh' --include='*.bash' --include='*.zsh' \
            --include='Makefile' --include='*.mk' --include='justfile' --include='Justfile' \
            --include='Taskfile.yml' --include='Taskfile.yaml' --include='package.json' \
            --include='*.md' \
            --exclude-dir='.git' --exclude-dir='node_modules' --exclude-dir='.venv' \
            --exclude-dir='venv' --exclude-dir='vendor' --exclude-dir='dist' \
            --exclude-dir='build' --exclude-dir='target' --exclude-dir='.next' \
            --exclude-dir='.turbo' --exclude-dir='coverage' --exclude-dir='.planning' \
            "$proj" 2>/dev/null \
          | grep -v "/\.claude/hooks/$hook\.sh$" \
          | sort)
    if [ -n "$hit" ]; then
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        echo "OVERRIDE-VECTOR  $name  $var  ${f#"$proj"/}"
        findings=$((findings + 1))
      done <<<"$hit"
    fi
   done <<<"$vars"
  done
}

# ---------------------------------------------------------------------------

for proj in "${PROJECTS[@]}"; do
  if [ ! -d "$proj" ]; then
    echo "SKIP    $(basename "$proj")  — not a directory"
    continue
  fi
  if [ "$OVERRIDES_ONLY" -eq 0 ]; then
    report_markers "$proj"
    report_identity "$proj"
    report_matchers "$proj"
  fi
  report_override_vectors "$proj"
done

echo
if [ "$findings" -eq 0 ]; then
  # The wording is load-bearing. This scan reads the repository; it cannot see
  # the operator's shell, a global shell profile, or a wrapper that sets the
  # variable before launching the host. A green result is a statement about
  # what was searched, not about the machine.
  echo "OK — no known vector found, and every marker read is current."
  echo "   'No known vector found' is a statement about what was searched, NOT about"
  echo "   the machine: the operator's own shell, a global profile, and any wrapper"
  echo "   that exports the variable before launching the host are all outside this"
  echo "   scan, and always will be. Vendored and build trees (node_modules, vendor,"
  echo "   dist, build, .next, .venv, coverage, .planning) were not searched either."
else
  echo "$findings finding(s) reported above. This tool reports; it does not block."
  echo "   Override vectors take effect at runtime and are NOT suppressed here —"
  echo "   surfacing them for review is the whole mechanism."
fi

[ "$STRICT" -eq 1 ] && [ "$findings" -gt 0 ] && exit 1
exit 0
