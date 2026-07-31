#!/usr/bin/env bash
# gate-version: 1.6.0
#
# VERSION MARKER — read by every host installer before writing this file to the
# SHARED path ~/.agenticapps/bin/. That path is written by claude / codex /
# opencode / pi installers alike, so without arbitration it is last-writer-wins:
# a host still vendoring an older copy silently republishes it over a newer one
# and reverts the fix for every agent on the machine. Installers MUST refuse to
# overwrite a higher version. Bump this whenever the gate's behaviour changes.
#   1.6.0 — a reviewer section is closed ONLY by the next `## Reviewer:`.
#           1.5.0 closed it at any level-1/2 heading, so `## Summary` above a
#           verdict — the commonest shape an LLM returns — discarded the verdict
#           and the review counted zero, while the producer reported success on
#           the same bytes. NOT a new rule: it is 1.5.0's own `### Findings` fix
#           applied at the level it stopped short of.
#           * this is a BEHAVIOUR change under a version that briefly shipped.
#             1.5.0 was published on 2026-07-30 and rolled back the same day; it
#             is not redefined in place, because a version that ever reached the
#             fleet must keep meaning one thing
#           * proven against the real gate, not against a belief about it: group
#             H of tools/run-plan-review-conformance.sh feeds producer output to
#             this script. The header advertised that group for six rounds while
#             the body had none, which is why the defect shipped green
#           * READS `tasks-digest` and reports drift. The spec has required this
#             since 1.3.0 ("the gate SHALL report that the implementation plan
#             has changed") and no version implemented it: the producer wrote
#             the field, nothing ever consumed it. The harness scored 66/66 over
#             it because its one row pinned the ALLOW half of the scenario,
#             which a gate that never reads the field satisfies by doing
#             nothing. Still advisory — reporting only, never blocking
#   1.5.0 — counts REVIEWS a reviewer actually wrote, and binds it to what was
#           reviewed. Implements spec 1.3.0 §18's new counting terms.
#           * a section counts only with a VERDICT and a BODY. Both failure
#             halves were live: a bare `VERDICT: APPROVE` with no body counted
#             on 2026-07-29T07:52:54Z, and a verdictless preamble counted the
#             same week
#           * reviewer_count() and pending_rejections() now share ONE parse.
#             They previously mirrored each other by hand under a comment
#             warning that divergence would mean the gate counts one set of
#             reviewers and reports on another
#           * sections bound at headings of LEVEL 1 OR 2, so a vendor's own
#             `### Findings` no longer truncates the section above its verdict
#           * the implementing host is read from the artifact's trailer, not
#             from OPENSPEC_GATE_SELF. CI and pre-commit hooks evaluate evidence
#             other hosts produced, so an environment identity names the wrong
#             party. Vocabulary is the UNION of hosts and reviewer vendors —
#             `pi` is a host with no reviewer arm and must still be nameable
#           * a digest binds the review to the reviewed bytes; a stale or
#             unverifiable artifact counts ZERO reviewers, fail-closed
#           BREAKING for evidence: every REVIEWS.md written before producer
#           1.1.0 lacks a trailer and counts zero. Re-review before publishing
#           this, or every active change in the fleet blocks at once.
#   1.4.0 — reviewer FLOOR drops to 1; 2 becomes a reported preference.
#           Implements spec 1.1.0 §18 (MUST >= 1, SHOULD >= 2). A hard floor of
#           two blocked all work whenever the second vendor was slow, rate
#           limited or down — trading a large certain cost for a small
#           uncertain one. Two is still better and is still surfaced, now via
#           PREFERRED_REVIEWERS and a NOTE rather than a refusal. Set
#           MIN_REVIEWERS=2 to restore the previous behaviour.
#   1.3.1 — tolerate markdown emphasis around the verdict label. 1.3.0 anchored
#           on a bare `VERDICT:` and missed `**VERDICT: REQUEST-CHANGES**`,
#           which is what opencode wrote on the first real run after 1.3.0
#           shipped: a genuine rejection, silently absent from the NOTE.
#   1.3.0 — report, but do not act on, outstanding REQUEST-CHANGES verdicts.
#           §18's truth table has no verdict term, so the threshold is a QUORUM:
#           two rejections open the gate exactly as two approvals do, and that
#           stays true here. What changed is the silence — the producer asks
#           every reviewer for a verdict and nothing read the answer, so a
#           change could step over two rejections without a word. Now the gate
#           names the objectors on the allow path. Reporting only; promoting
#           verdicts to blocking is a §18 change, not a gate change.
#   1.2.2 — close two symlink escapes in the openspec/ exemption, both present
#           since 1.2.0. (a) `..` was collapsed textually BEFORE physical
#           resolution, so a symlink inside openspec/ followed by `..` was
#           exempted while the bytes landed outside the repo; resolve
#           physically first, then refuse any `..` that survives. (b) a
#           symlinked artifact path was exempted and the writer followed it
#           into code; resolve the final component when it exists and is a
#           link. The not-yet-existing Write target 1.2.1 fixed is unaffected —
#           `[ -L ]` is false for a path that does not exist.
#   1.2.1 — exempt absolute artifact paths under a symlinked repo root. $ROOT
#           is physical (git resolves it) and hosts pass logical paths, so the
#           prefix test blocked the write of proposal.md itself — an
#           un-authorable change. Claude Code always sends absolute paths, so
#           this was live fleet-wide.
#   1.2.0 — OPENSPEC_BIN indirection (makes §18's "demonstrable by direct
#           invocation" clause actually true), multi-host payload shapes
#           (pi `.input.path`, opencode `.args.*`), OPENSPEC_GATE_SELF
#           self-review exclusion
#   1.1.0 — anchor the openspec/ exemption to $ROOT (bypass fix), tighten
#           reviewer counting, honour fail-open on parse errors
#   1.0.0 — initial canonical script (agenticapps-workflow-core)
#
# openspec-change-gate.sh — the AgenticApps enforcement gate (host-agnostic).
#
# THE REFERENCE IMPLEMENTATION of spec/18-retargeted-change-gate.md. Hosts vendor
# this file rather than maintaining their own copy; divergence between host
# copies is what issue #32 documented and this file exists to end. Conformance is
# executable: tools/change-gate-conformance.sh scores any copy against §18's
# truth table. Change behaviour here only with a matching row.
#
# Rule: you may not edit code while an OpenSpec change is active unless
#   (1) `openspec validate --all` is GREEN, and
#   (2) every active change carries REVIEWS.md with >= MIN_REVIEWERS reviewers
#       (floor 1; 2 preferred and reported, not enforced).
# This is the OpenSpec-era retarget of the ADR-0018 multi-AI plan-review gate.
#
# Three modes:
#   (default)      HOOK mode — reads a PreToolUse JSON payload on stdin, decides for ONE edit.
#                  Exit 0 = allow, Exit 2 = block. FAIL-OPEN (never bricks a session on error).
#   --pre-commit   Staged-aware — blocks a commit only if it stages non-openspec files while
#                  the gate is unsatisfied. Exit 0 = allow commit, Exit 1 = block. FAIL-CLOSED.
#   --ci           Whole-repo — every active change must validate + have reviews. Exit 0/1.
#
# Env:
#   GSD_SKIP_REVIEWS=1     bypass the review requirement (emergency escape; still needs validate).
#   OPENSPEC_GATE_STRICT=1 also block edits when there is NO active change ("no code without a change").
#   MIN_REVIEWERS=1        blocking floor (spec 1.1.0 MUST). Set 2 for the old behaviour.
#   PREFERRED_REVIEWERS=2  reported-but-not-enforced target (spec 1.1.0 SHOULD).
#   OPENSPEC_BIN=openspec  override the openspec CLI name/path.
#   OPENSPEC_GATE_SELF     IGNORED since 1.5.0 — retained only so an operator
#                          who exported it is not misled by silence. The
#                          implementing host is read from the trailer, because
#                          CI and pre-commit evaluate evidence OTHER hosts
#                          produced and an environment identity names the wrong
#                          party. Documenting it as live was itself the hazard:
#                          the gate harness set it in every self-exclusion row
#                          and those rows passed on an unrelated mechanism.
#
# Exit codes follow the Claude Code PreToolUse convention (2 = block) in hook mode.
#
# Documented deviation from §18's truth table: the GSD_SKIP_REVIEWS escape hatch
# is applied AFTER the validate check, so `validate` red + the hatch set still
# blocks. §18's row reads unconditionally. This narrowing is deliberate — the
# hatch exists to bypass the *review* clause in an emergency, not to ship a
# change whose spec delta does not parse — and it is pinned by a harness row.

set -uo pipefail
# FLOOR (blocks) and PREFERENCE (reports). Spec 1.1.0 §18: MUST >= 1,
# SHOULD >= 2. Raising MIN_REVIEWERS back to 2 restores the old hard behaviour
# for a repo that wants it; both are env-overridable.
MIN_REVIEWERS="${MIN_REVIEWERS:-1}"
PREFERRED_REVIEWERS="${PREFERRED_REVIEWERS:-2}"
# Indirect the CLI so the conformance harness can stub `validate` and assert THIS
# script's logic hermetically, rather than testing OpenSpec. §18 requires the gate
# be "demonstrable by direct script invocation with simulated payloads"; a
# hardcoded binary makes the block/allow rows untestable without a real, populated
# OpenSpec repo — i.e. makes the contract unverifiable as written, which is why
# the fleet-wide drift went unmeasured for as long as it did.
OPENSPEC_BIN="${OPENSPEC_BIN:-openspec}"
MODE="hook"
case "${1:-}" in
  --ci)         MODE="ci" ;;
  --pre-commit) MODE="pre-commit" ;;
esac

log(){ printf 'openspec-gate: %s\n' "$*" >&2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CHANGES_DIR="$ROOT/openspec/changes"

# --- helpers ---------------------------------------------------------------

active_changes(){                      # print each active (non-archived) change dir, one per line
  [ -d "$CHANGES_DIR" ] || return 0
  find "$CHANGES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name archive 2>/dev/null | sort
}

# ── the digest ───────────────────────────────────────────────────────────────
# BYTE-IDENTICAL to the producer's `shared-digest v1`. The producer attests;
# this reproduces. If the two ever diverge the attestation is unverifiable and
# every review in the fleet reads stale — so change both together or neither.
digest_set() { # $1 = change dir
  local d="$1"
  {
    [ -e "$d/proposal.md" ] && printf 'proposal.md\0'
    [ -e "$d/design.md" ]   && printf 'design.md\0'
    if [ -d "$d/specs" ]; then
      find "$d/specs" -name '*.md' -print0 2>/dev/null |
        while IFS= read -r -d '' p; do printf '%s\0' "${p#"$d"/}"; done
    fi
  } | LC_ALL=C sort -z
}

compute_digest() { # $1 = change dir ; prints sha256:<hex>, or returns 3
  local d="$1" p ser
  ser="$(mktemp "${TMPDIR:-/tmp}/gdigest.XXXXXX")" || return 3
  while IFS= read -r -d '' p; do
    [ -n "$p" ] || continue
    if [ -L "$d/$p" ] || [ ! -f "$d/$p" ]; then rm -f "$ser"; return 3; fi
    local canon clen plen
    canon="$(mktemp "${TMPDIR:-/tmp}/gcanon.XXXXXX")" || { rm -f "$ser"; return 3; }
    LC_ALL=C tr -d '\r' < "$d/$p" > "$canon"
    [ -s "$canon" ] && [ "$(LC_ALL=C tail -c1 "$canon" | od -An -tu1 | tr -d ' \n')" != "10" ] && printf '\n' >> "$canon"
    plen=$(printf '%s' "$p" | LC_ALL=C wc -c | tr -d ' ')
    clen=$(LC_ALL=C wc -c < "$canon" | tr -d ' ')
    { printf '%s\n%s\n%s\n' "$plen" "$p" "$clen"; cat "$canon"; } >> "$ser"
    rm -f "$canon"
  done < <(digest_set "$d")
  local hex
  hex="$(LC_ALL=C shasum -a 256 "$ser" 2>/dev/null | awk '{print $1}')"
  [ -n "$hex" ] || hex="$(LC_ALL=C sha256sum "$ser" 2>/dev/null | awk '{print $1}')"
  rm -f "$ser"
  [ -n "$hex" ] || return 3
  printf 'sha256:%s' "$hex"
}

# Digest of `tasks.md` alone, under the same framing compute_digest applies to
# each member: path length, path, content length, content. The producer records
# it as `tasks-digest`; this recomputes it so drift can be REPORTED.
#
# `tasks.md` is deliberately outside the reviewed set — a ticked checkbox must
# not stale a review — which leaves a hole a reviewer named: a task added after
# review ("add a debug endpoint") expands scope without contradicting a word of
# the reviewed artifacts. The spec answers that with an advisory report, and
# until now the gate never read the field. The producer wrote it, nothing
# consumed it, and the requirement below it was normative. Write-only evidence
# is worse than none: it reads as a control that exists.
compute_tasks_digest() { # $1 = change dir ; prints sha256:<hex>, or returns 3
  local d="$1" f="$1/tasks.md" canon ser hex plen clen p="tasks.md"
  [ -f "$f" ] && [ ! -L "$f" ] || return 3
  canon="$(mktemp "${TMPDIR:-/tmp}/gtasks.XXXXXX")" || return 3
  ser="$(mktemp "${TMPDIR:-/tmp}/gtser.XXXXXX")" || { rm -f "$canon"; return 3; }
  LC_ALL=C tr -d '\r' < "$f" > "$canon"
  [ -s "$canon" ] && [ "$(LC_ALL=C tail -c1 "$canon" | od -An -tu1 | tr -d ' \n')" != "10" ] && printf '\n' >> "$canon"
  plen=$(printf '%s' "$p" | LC_ALL=C wc -c | tr -d ' ')
  clen=$(LC_ALL=C wc -c < "$canon" | tr -d ' ')
  { printf '%s\n%s\n%s\n' "$plen" "$p" "$clen"; cat "$canon"; } >> "$ser"
  hex="$(LC_ALL=C shasum -a 256 "$ser" 2>/dev/null | awk '{print $1}')"
  [ -n "$hex" ] || hex="$(LC_ALL=C sha256sum "$ser" 2>/dev/null | awk '{print $1}')"
  rm -f "$canon" "$ser"
  [ -n "$hex" ] || return 3
  printf 'sha256:%s' "$hex"
}

# ── one parse, consumed by both counting and reporting ───────────────────────
# reviewer_count() and pending_rejections() previously mirrored each other's
# parsing by hand, with a comment explaining that divergence would mean the
# gate counts one set of reviewers and reports on another. It is now one pass
# feeding both, so that cannot happen by editing only one.
#
# Emits a small record language on stdout:
#   TRAILERS <n>            how many trailer blocks the file carries
#   FIELD <key> <value>     each trailer field, in order, duplicates included
#   FINAL <0|1>             whether the trailer is the file's final content
#   SECTION <name> <verdict|none|conflict> <0|1 substance>
#
# The section rule and the verdict grammar are the producer's `shared-predicate
# v1`. A section runs from its `## Reviewer:` heading to the NEXT `## Reviewer:`
# heading, or EOF. No other heading closes it: everything between two reviewer
# headings is vendor content, and vendor content is interior.
#
# This bound was tightened twice, both times after it discarded a real review.
# "Any heading" killed `### Findings` above a verdict; "level 1 or 2" killed
# `## Summary` above a verdict, which is the commonest shape an LLM returns.
# Headings are still excluded from SUBSTANCE below — what widened is what keeps
# a verdict, not what counts as one.
parse_reviews() { # $1 = REVIEWS.md
  LC_ALL=C awk '
    # shared-predicate v1
    function norm(s) {
      gsub(/[*_]/, "", s)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      gsub(/[[:space:]]+/, " ", s)
      return s
    }
    function flush(   v) {
      if (cur == "") return
      v = conflict ? "conflict" : (verdict == "" ? "none" : verdict)
      print "SECTION " cur " " v " " (substance ? 1 : 0)
      cur = ""; verdict = ""; conflict = 0; substance = 0
    }
    BEGIN { fence = 0; cur = ""; trailers = 0; intrailer = 0; lastcontent = 0 }

    { raw = $0 }

    # Trailer first: its delimiters must not be read as content or headings.
    !fence && raw ~ /^[[:space:]]*<!--[[:space:]]*openspec-review-trailer/ {
      trailers++; intrailer = 1; trailer_end = 0; next
    }
    intrailer {
      if (raw ~ /-->/) { intrailer = 0; trailer_end = NR; next }
      line = raw
      sub(/^[[:space:]]+/, "", line)
      if (line ~ /^[a-z][a-z-]*:[[:space:]]/) {
        key = line; sub(/:.*$/, "", key)
        val = line; sub(/^[a-z][a-z-]*:[[:space:]]*/, "", val)
        sub(/[[:space:]]+$/, "", val)
        print "FIELD " key " " val
      }
      next
    }

    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }

    # A reviewer heading opens a section. ONLY a reviewer heading closes one.
    #
    # Bounding at "any level-1/2 heading" was wrong, and wrong in the direction
    # that silently discards good reviews: `## Summary` above a verdict — the
    # single most common shape an LLM returns — flushed the section, so the
    # verdict below it landed nowhere and the review counted as zero. Widening
    # from "any level" to "level 1 or 2" fixed `### Findings` and left this.
    #
    # Nothing else needs to close a section. The producer owns the file layout:
    # notice, then record, then sections, then trailer. Every level-1/2 heading
    # between two `## Reviewer:` lines is vendor content, and vendor content is
    # interior by definition. Headings are still excluded from substance below,
    # so this widens what keeps a verdict without weakening what counts as one.
    /^##[[:space:]]*[Rr]eviewer[[:space:]]*:[[:space:]]*[^[:space:]]/ {
      flush()
      name = raw
      sub(/^##[[:space:]]*[Rr]eviewer[[:space:]]*:[[:space:]]*/, "", name)
      sub(/[[:space:]]+$/, "", name)
      cur = tolower(name)
      lastcontent = NR
      next
    }

    {
      n = norm(raw)
      if (n != "") lastcontent = NR
      if (cur == "") next
      if (n == "") next
      if (raw ~ /^[[:space:]]*_generated .* timeout [0-9]+s_[[:space:]]*$/) next
      if (raw ~ /^[[:space:]]*#{1,6}[[:space:]]/) next
      lower = tolower(n)
      if (lower ~ /^verdict[[:space:]]*:[[:space:]]*(approve|request-changes)$/) {
        v = (lower ~ /approve/) ? "APPROVE" : "REQUEST-CHANGES"
        if (verdict != "" && verdict != v) conflict = 1
        verdict = v
        next
      }
      # Structure is not substance, and the enumeration of structure was
      # incomplete: headings, fences, comments and blanks were excluded, but a
      # thematic break (`---`) or a bare blockquote marker (`>`) sailed through
      # and satisfied the rule. A section of `VERDICT: APPROVE` plus `---` is a
      # bare verdict wearing a costume, which is the failure this rule exists
      # to catch. Requiring one alphanumeric character is the whole test: it
      # needs no list of markers to stay in sync with, and no reviewer writes a
      # finding without a letter or a digit in it.
      if (n !~ /[[:alnum:]]/) next
      substance = 1
    }
    END {
      flush()
      print "TRAILERS " trailers
      # Final content: nothing but whitespace after the closing `-->`.
      print "FINAL " ((trailers == 1 && trailer_end > 0 && lastcontent <= trailer_end) ? 1 : 0)
    }
  ' "$1" 2>/dev/null
}

# Reads the trailer and reports why the evidence cannot be trusted, or `ok`.
# Fails CLOSED: a malformed trailer is indistinguishable from an absent one for
# the purpose it serves.
trailer_status() { # $1 = change dir ; prints ok|<reason>
  local d="$1" f="$1/REVIEWS.md" parsed
  [ -f "$f" ] || { echo "no-reviews-file"; return; }
  parsed="$(parse_reviews "$f")"
  local n; n="$(printf '%s\n' "$parsed" | awk '/^TRAILERS /{print $2}')"
  [ "${n:-0}" = "0" ] && { echo "trailer-absent"; return; }
  [ "${n:-0}" = "1" ] || { echo "trailer-duplicated"; return; }
  [ "$(printf '%s\n' "$parsed" | awk '/^FINAL /{print $2}')" = "1" ] || { echo "trailer-not-final"; return; }

  local host digest pver dup
  for k in implementing-host digest producer-version; do
    dup="$(printf '%s\n' "$parsed" | awk -v k="$k" '$1=="FIELD" && $2==k' | wc -l | tr -d ' ')"
    [ "$dup" = "1" ] || { echo "trailer-field-$([ "$dup" = "0" ] && echo missing || echo duplicated):$k"; return; }
  done
  host="$(printf '%s\n' "$parsed"   | awk '$1=="FIELD" && $2=="implementing-host"{print $3}')"
  digest="$(printf '%s\n' "$parsed" | awk '$1=="FIELD" && $2=="digest"{print $3}')"
  pver="$(printf '%s\n' "$parsed"   | awk '$1=="FIELD" && $2=="producer-version"{print $3}')"

  # A field present but MALFORMED is treated exactly as absent. Specifying only
  # missing fields left a parser free to accept a garbage value, which fails
  # open in the one place this fails closed everywhere else.
  printf '%s' "$digest" | LC_ALL=C grep -qE '^sha256:[0-9a-f]{64}$' || { echo "trailer-bad-digest"; return; }
  printf '%s' "$pver"   | LC_ALL=C grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "trailer-bad-version"; return; }
  # List grammar: bare commas, no whitespace, closed vocabulary.
  #
  # The vocabulary is the UNION of hosts and reviewer vendors, not the reviewer
  # set alone: `pi` is a host with no reviewer arm, and validating against the
  # reviewer set would read every pi-authored artifact as malformed — zero
  # reviewers, permanently blocked, for one of the four hosts.
  printf '%s' "$host" | LC_ALL=C grep -qE '^(claude|codex|gemini|opencode|pi)(,(claude|codex|gemini|opencode|pi))*$' \
    || { echo "trailer-bad-host"; return; }

  local now
  now="$(compute_digest "$d")" || { echo "digest-uncomputable"; return; }
  [ "$now" = "$digest" ] || { echo "digest-mismatch"; return; }
  echo "ok"
}

reviewer_count(){                      # $1 = change dir ; echo number of DISTINCT reviewers
  local d="$1" f="$1/REVIEWS.md"
  [ -f "$f" ] || { echo 0; return; }

  # The evidence must be verifiable before any of it is counted. An unbound,
  # stale or malformed artifact contributes ZERO reviewers rather than the
  # number of headings it happens to contain.
  [ "$(trailer_status "$d")" = "ok" ] || { echo 0; return; }

  local parsed self
  parsed="$(parse_reviews "$f")"
  self="$(printf '%s\n' "$parsed" | awk '$1=="FIELD" && $2=="implementing-host"{print $3}')"

  # Counts a section only when it carries a verdict AND a body, and only when
  # its heading names a vendor from the closed vocabulary.
  #
  # The closed name list is what stops `## Reviewer: codex-2` counting on a
  # codex-authored change: exclusion is by name, so an arbitrary lookalike
  # would otherwise read as an independent reviewer while being the
  # implementing host's own output.
  printf '%s\n' "$parsed" | LC_ALL=C awk -v self="$self" '
    BEGIN { n = split(self, a, ","); for (i = 1; i <= n; i++) excl[a[i]] = 1 }
    $1 == "SECTION" {
      name = $2; verdict = $3; substance = $4
      if (name != "claude" && name != "codex" && name != "gemini" && name != "opencode") next
      if (name in excl) next
      if (verdict == "none" || verdict == "conflict") next
      if (substance != "1") next
      seen[name] = 1
    }
    END { n = 0; for (k in seen) n++; print n }
  ' 2>/dev/null || echo 0
}

# Names the reviewers whose section carries a REQUEST-CHANGES verdict, comma
# separated; empty when none do. REPORTING ONLY — nothing here can block, and
# nothing here may ever change an exit code. §18's truth table has no verdict
# term, so a gate that blocked on this would be non-conformant.
#
# Shares reviewer_count's parse rather than mirroring it. The previous pair
# hand-mirrored each other with a comment warning that divergence would mean
# the gate counts one set of reviewers and reports on another; one pass feeding
# both makes that unrepresentable.
#
# A section with no verdict line at all is NOT a rejection. Reviewers that
# ignore the producer's format, or vendors whose output was truncated, must not
# be reported as objecting when they said nothing.
pending_rejections(){
  local d="$1" f="$1/REVIEWS.md"
  [ -f "$f" ] || { echo ""; return; }
  local parsed self
  parsed="$(parse_reviews "$f")"
  self="$(printf '%s\n' "$parsed" | awk '$1=="FIELD" && $2=="implementing-host"{print $3}')"
  printf '%s\n' "$parsed" | LC_ALL=C awk -v self="$self" '
    BEGIN { n = split(self, a, ","); for (i = 1; i <= n; i++) excl[a[i]] = 1 }
    $1 == "SECTION" {
      name = $2; verdict = $3; substance = $4
      if (name != "claude" && name != "codex" && name != "gemini" && name != "opencode") next
      if (name in excl) next
      if (substance != "1") next
      if (verdict != "REQUEST-CHANGES") next
      if (!(name in flagged)) { flagged[name] = 1; order[++k] = name }
    }
    END {
      out = ""
      for (i = 1; i <= k; i++) out = (out == "" ? order[i] : out ", " order[i])
      print out
    }
  ' 2>/dev/null || echo ""
}

validate_ok(){ ( cd "$ROOT" && "$OPENSPEC_BIN" validate --all >/dev/null 2>&1 ); }

# Core check. Returns: 0 = satisfied, 2 = blocked. Never errors out.
gate_check(){
  local changes; changes="$(active_changes)"
  if [ -z "$changes" ]; then
    if [ "${OPENSPEC_GATE_STRICT:-0}" = "1" ]; then log "no active change (strict mode) — blocked"; return 2; fi
    return 0                                   # permissive default: incidental edits are fine
  fi
  if ! command -v "$OPENSPEC_BIN" >/dev/null 2>&1; then
    log "openspec CLI not found — cannot verify; run 'npm i -g @fission-ai/openspec'"; return 2
  fi
  if ! validate_ok; then log "openspec validate --all FAILED — fix the spec delta first"; return 2; fi
  if [ "${GSD_SKIP_REVIEWS:-0}" = "1" ]; then log "GSD_SKIP_REVIEWS=1 — review requirement bypassed"; return 0; fi
  local blocked=0 d n v
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    n="$(reviewer_count "$d")"
    if [ "$n" -lt "$MIN_REVIEWERS" ]; then
      log "change '${d#"$ROOT"/}' has $n/$MIN_REVIEWERS reviewers — run plan-review to write REVIEWS.md"
      blocked=1
      continue
    fi
    # Spec 1.1.0 moved the FLOOR to one reviewer and made two a SHOULD. The gap
    # between them is reported, never enforced: a single reviewer is a
    # reportable condition, not a failure.
    #
    # The evidence says two really is better — across three changes reviewed in
    # the 2026-07-28 migration the decisive finding was unique to one vendor
    # every time — but that argues one reviewer is worse than two, not that it
    # is worse than none. A hard floor of two blocked all work whenever the
    # second vendor was slow, rate-limited or down, which is what this split
    # fixes. Silence would throw away the distinction entirely, so the shortfall
    # is surfaced at the moment it is being relied on.
    if [ "$n" -lt "$PREFERRED_REVIEWERS" ]; then
      log "NOTE change '${d#"$ROOT"/}' has $n reviewer(s); $PREFERRED_REVIEWERS preferred — allowed on the floor, a second opinion would be stronger"
    fi
    # The threshold is a QUORUM, not an approval: §18's truth table keys `allow`
    # on the reviewer COUNT and carries no verdict term, so two REQUEST-CHANGES
    # verdicts open the gate exactly as two APPROVEs would. That is deliberate —
    # promoting verdicts to blocking needs a re-review trigger, a staleness rule
    # for an edited proposal, and an override path, none of which §18 defines.
    #
    # But silently stepping over a rejection is its own failure. The producer
    # ASKS every reviewer for "VERDICT: APPROVE" or "VERDICT: REQUEST-CHANGES",
    # so the answer is always there; before this the gate simply never read it.
    # On the run that surfaced this, both reviewers said REQUEST-CHANGES — one
    # of them having found a 77-record identity-migration hazard the plan missed
    # entirely — and the gate allowed the edit without a word.
    #
    # So: still allow, but say so. Reporting only, never blocking; a change to
    # that is a §18 change, not a gate change.
    v="$(pending_rejections "$d")"
    [ -n "$v" ] && log "NOTE change '${d#"$ROOT"/}' has $n reviewer(s) but $v requested changes — allowed on quorum; address or record why not"

    # Advisory tasks-drift report. Same shape as the line above: say it, never
    # block on it. Absent or unreadable is silence, not a warning — the field is
    # optional, and a change with no tasks.md has nothing to drift.
    td="$(printf '%s\n' "$(parse_reviews "$d/REVIEWS.md")" | awk '$1=="FIELD" && $2=="tasks-digest"{print $3; exit}')"
    if [ -n "$td" ]; then
      now_td="$(compute_tasks_digest "$d")" || now_td=""
      [ -n "$now_td" ] && [ "$now_td" != "$td" ] && \
        log "NOTE change '${d#"$ROOT"/}' — tasks.md has changed since review; the reviewed artifacts are current but the implementation plan is not"
    fi
  done <<< "$changes"
  [ "$blocked" -eq 0 ] && return 0 || return 2
}

# --- edit-path extraction (hook mode) --------------------------------------

# Every host runtime wraps the same two facts (tool name, target path) in its own
# envelope. A key this function does not know about yields an empty path, which
# fails OPEN below — i.e. the gate silently stops enforcing on that host. Adding a
# host means adding its key here AND a payload-shape row to the conformance
# harness; the harness drives a *code* edit precisely because an artifact write
# passes under fail-open whether or not the parser ran.
#
#   .tool_input.*                    — Claude Code PreToolUse
#   .params.file_path                — generic JSON-RPC shape
#   .input.file_path / .input.path   — pi `tool_call` ({toolName, input:{path}};
#                                      verified against pi-coding-agent 0.80.10)
#   .args.filePath / .args.path / .args.file
#                                    — opencode `tool.execute.before`
#   .file_path / .path               — bare fallback
edited_path_from_stdin(){              # best-effort parse of a tool-call payload
  local payload; payload="$(cat 2>/dev/null || true)"
  [ -n "$payload" ] || { echo ""; return; }
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r '
      (.tool_input.file_path // .tool_input.path // .tool_input.notebook_path //
       .params.file_path //
       .input.file_path // .input.path //
       .args.filePath // .args.path // .args.file //
       .file_path // .path // empty)' 2>/dev/null | head -n1
  else
    printf '%s' "$payload" | grep -oE '"(file_?[pP]ath|path|file)"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | head -n1 | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/'
  fi
}

physical_prefix(){       # print $1 with its deepest existing ANCESTOR DIRECTORY resolved physically
  # Only directories can be resolved with cd/pwd -P, so the final component is
  # split off first and the walk goes up to the deepest existing directory.
  #
  # The final component IS resolved when it exists and is a symlink. An earlier
  # version declined to, reasoning that resolving it "would follow a symlinked
  # file out of the tree" — that is backwards. The *writer* follows it either
  # way; declining to resolve is what let a symlinked artifact path be exempted
  # and the write land on its target (`openspec/changes/x/design.md -> src/app.go`
  # truncated app.go under an unsatisfied change). The exemption has to be
  # decided about the bytes' destination, not about the name used to reach it.
  #
  # The other half of that reasoning was sound and is preserved: a Write target
  # often does not exist yet, and `[ -L ]` is false for a non-existent path, so
  # the chase below simply does not run and the not-yet-created case behaves
  # exactly as before.
  local head="$1" rest depth=0 target parent
  case "$head" in /*) ;; *) printf '%s' "$head"; return ;; esac
  # Bounded: a symlink cycle would otherwise spin here. On hitting the bound we
  # fall through with `head` partly resolved, which cannot match the openspec
  # prefix spuriously — an unresolvable path is not exempt, which is the safe
  # direction.
  while [ -L "$head" ] && [ "$depth" -lt 40 ]; do
    depth=$((depth + 1))
    target="$(readlink "$head" 2>/dev/null)" || break
    [ -n "$target" ] || break
    parent="${head%/*}"
    [ -z "$parent" ] && parent=/
    case "$target" in
      /*) head="$target" ;;
      *)  head="$parent/$target" ;;
    esac
  done
  rest="${head##*/}"
  head="${head%/*}"
  [ -z "$head" ] && head=/
  while [ ! -d "$head" ]; do
    case "$head" in /|"") break ;; esac
    rest="${head##*/}/$rest"
    head="${head%/*}"
    [ -z "$head" ] && head=/
  done
  [ -d "$head" ] && head="$(cd -P "$head" 2>/dev/null && pwd -P)"
  printf '%s' "${head%/}/$rest"
}

is_openspec_artifact(){                # edits to the change itself must always be allowed
  # Must be THIS repo's spec slot, not any path that happens to contain a
  # directory called `openspec`. The old glob (`*/openspec/*`) exempted
  # `src/openspec/app.ts` and even `/tmp/openspec/x.ts` — a real bypass: a repo
  # with a source directory of that name could edit code freely while the gate
  # was unsatisfied. Resolve the path against $ROOT and require the
  # $ROOT/openspec/ prefix.
  local p="$1" resolved
  [ -n "$p" ] || return 1
  case "$p" in
    /*) resolved="$p" ;;
    *)  resolved="$ROOT/$p" ;;
  esac
  # Compare physical-to-physical. $ROOT comes from `git rev-parse
  # --show-toplevel`, which resolves symlinks; hosts pass the logical path they
  # were given. Where the repo is reached through a symlink a plain string
  # prefix test fails and the gate blocks the write of proposal.md itself,
  # leaving a change that can never be authored.
  #
  # Resolve PHYSICALLY FIRST, then reject leftover `..`. An earlier version
  # collapsed `..` textually up front and resolved afterwards, with a comment
  # claiming that order "is what keeps the escape rows blocked". It keeps the
  # BARE escapes blocked (`openspec/../src/app.ts` — still blocked, pinned
  # below); it is not sufficient on its own. Where a symlink inside openspec/
  # precedes the `..`, the textual pass and the kernel disagree and the kernel
  # wins:
  #
  #   $ROOT/openspec/out -> /tmp/outdir
  #   openspec/out/../victim
  #     textual first -> $ROOT/openspec/victim  => EXEMPT  (wrong)
  #     kernel        -> /tmp/outdir/../victim  => /tmp/victim, outside the repo
  #
  # `cd -P` asks the kernel, so resolving first gets this right. The reason the
  # textual pass existed — a Write target that does not exist yet cannot be
  # realpath'd — is handled by physical_prefix walking up to the deepest
  # existing ancestor instead.
  local root_phys
  root_phys="$(cd -P "$ROOT" 2>/dev/null && pwd -P)" || root_phys="$ROOT"
  resolved="$(physical_prefix "$resolved")"
  # A `..` that survived physical resolution sits in the unresolved tail, i.e.
  # below a directory that does not exist yet, so where it lands is unknowable
  # (`openspec/nope/../../src/app.ts` string-matches the openspec prefix while
  # resolving outside it). Refuse the exemption rather than guess: the write is
  # then judged on policy like any other, which is the safe direction.
  case "/$resolved/" in
    */../*) return 1 ;;
  esac
  case "$resolved" in
    "${root_phys%/}"/openspec/*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- modes -----------------------------------------------------------------

case "$MODE" in
  hook)
    # FAIL-OPEN: any unexpected error allows the edit (never brick a live session).
    path="$(edited_path_from_stdin || true)"
    # §18: "malformed / unparseable stdin -> allow (fail-open)". We could not
    # extract a target path, so we cannot reason about this call at all —
    # deciding policy on it would be guessing. Previously an unparseable payload
    # fell through to gate_check and could BLOCK (visible under
    # OPENSPEC_GATE_STRICT=1, or with an unsatisfied active change), which
    # inverts the contract: fail open on a PARSE error, never on policy.
    if [ -z "$path" ]; then exit 0; fi
    if is_openspec_artifact "$path"; then exit 0; fi
    if gate_check; then exit 0; else
      # gate_check returned 2 => block
      log "BLOCKED — no code edits until validate is GREEN and every active change has >= $MIN_REVIEWERS reviewers."
      exit 2
    fi
    ;;

  pre-commit)
    # Only block if the commit stages non-openspec files while the gate is unsatisfied.
    # Anchored at ^: staged paths are repo-relative, and `(^|/)openspec/` also
    # exempted `src/openspec/...` — the same bypass is_openspec_artifact had.
    staged="$(git diff --cached --name-only 2>/dev/null || true)"
    non_spec="$(printf '%s\n' "$staged" | grep -vE '^"?openspec/' | grep -v '^$' || true)"
    if [ -z "$non_spec" ]; then exit 0; fi          # only spec artifacts staged -> fine
    if gate_check; then exit 0; else
      log "commit BLOCKED — you are committing code while the change gate is unsatisfied."
      exit 1
    fi
    ;;

  ci)
    if gate_check; then log "OK — all active changes validate and are reviewed."; exit 0; else exit 1; fi
    ;;
esac
