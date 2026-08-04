# semver.sh — component-wise numeric version comparison. SOURCED, never run.
#
# ONE implementation, extracted when there were two callers.
#
#   provisioning-check.sh        compares `# <hook>-version:` against the authority
#
# The second caller, project-hook-conformance.sh, was retired on 2026-08-04 with
# the rest of the conformance instrument. This file is kept as its own unit
# rather than folded back into its one remaining caller: the argument below is
# about what a divergent copy costs, and it applies again the moment a second
# caller appears.
#
# The second caller is why this file exists. Writing a second copy would have
# been shorter, and the failure a divergent copy produces is silent: a lexical
# compare places 1.10.0 BELOW 1.9.0, so the check would report a machine that is
# ahead as behind and hand the operator the opposite remedy. A wrong remedy is
# worse than no remedy, and nothing in either tool's output would have shown it.
#
# Both callers already refuse to report rather than degrade, so both refuse if
# this file is missing.

# Echoes -1, 0 or 1 for $1 <, =, > $2. Missing components read as 0, so "1.2"
# and "1.2.0" compare equal.
semver_cmp() {
  local a="$1" b="$2" i x y
  local -a A B
  IFS=. read -r -a A <<<"$a"
  IFS=. read -r -a B <<<"$b"
  for i in 0 1 2; do
    x=${A[$i]:-0}; y=${B[$i]:-0}
    if [ "$x" -lt "$y" ]; then echo -1; return; fi
    if [ "$x" -gt "$y" ]; then echo 1; return; fi
  done
  echo 0
}
