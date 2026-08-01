# Evidence

## `gate-run-plan-review-ancestor-66-lines.sh`

The 66-line ancestor deleted from `gate/` by task 9.2, preserved verbatim
before deletion. `gate/` is **untracked**, so this file existed in no git
history anywhere — deleting it without a copy would have destroyed the only
record of what the producer looked like before it diverged.

- sha256 `cb6e75f91ba6fa34…` (full digest in the deletion commit)
- 66 lines, no version marker → installers treat it as `0.0.0`
- 161 lines behind the 227-line 1.0.0 that actually ran

It is kept because the divergence is load-bearing evidence for this change's
central claim: an artifact maintained only as an installed copy drifts from
its in-repo namesake, and nothing reports the drift. Being able to show both
halves is the point.
