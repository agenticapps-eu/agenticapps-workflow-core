# RED predictions — recorded BEFORE the first run

Task 1.25 requires the expected verdict per harness per row group to be written
down first, so the RED run confirms a prediction rather than being interpreted
after the fact. A reviewer caught the first draft of this plan asserting that
*every* row must fail at RED; three of the five harnesses are already correct
on the named-absence rows and MUST pass.

Shapes: **M** = multi-target, **S** = single-target.

| Harness | Shape |
|---|---|
| `change-gate-conformance.sh` | M |
| `run-plan-review-conformance.sh` | M |
| `reviewer-cli-conformance.sh` | M |
| `resolve-core-artifact-conformance.sh` | S |
| `shared-install-conformance.sh` | S |

## Group A — named target missing

| Harness | Predicted | Why |
|---|---|---|
| change-gate | **FAIL** | `SKIP`, `continue`, exit 0 — the reported bug |
| run-plan-review | **FAIL** | identical code at `:766` |
| reviewer-cli | **PASS** | `:169` counts it as a failure row, exit 1 |
| resolve-core-artifact | **PASS** | `exit 2` at `:10` |
| shared-install | **PASS** | `exit 2` at `:28` |

## Group B — named target is zero-byte

Predicted **FAIL for all five**. `[ -f ]` is true for an empty file, so every
harness proceeds. The row asserts both a non-zero exit *and* that the output
names emptiness as the reason.

The exit code alone is NOT discriminating here and the row must not rely on it:
an empty gate exits 0, which passes every `expect 0` row and fails every
`expect 2` row, so the tally is non-zero for the wrong reason. Asserting only
the exit code would score this row green against unfixed code.

## Group C — named target is a directory

Predicted **FAIL for all five**. `[ -f ]` is false for a directory, so
change-gate and run-plan-review take the same silent-skip path as Group A.
reviewer-cli and the two single-target tools exit non-zero but report "not
found", which is the wrong reason — the row asserts the reason names
not-a-regular-file.

## Group D — named target is non-empty but unreadable

Predicted **FAIL for all five**. `[ -f ]` is true, so all five proceed and the
shell refuses the file with 126. The rows fail loudly, which is non-zero but
illegible: the operator is shown row failures when the fault is a file mode.

Environment note: this group is a no-op under root (`test -r` is true for root
and the shell reads the file anyway). The RED run below is a non-root
workstation. A root CI container will show these rows differently, which is
itself specified.

## Group E — roster coverage

Applies to the **two** harnesses with a roster mode: `change-gate-conformance.sh:868`
and `reviewer-cli-conformance.sh:224`. Predicted **FAIL** for both on every
coverage row — neither prints any coverage line today.

## Group F — roster flag combined with an explicit path

Predicted **FAIL** for both roster harnesses. `set --` discards every other
argument, so the explicit path vanishes and the roster is scored instead of a
usage error being raised.

## Group G — whole roster absent

Predicted **FAIL** for both roster harnesses. The absence filter runs *before*
the argument-count check, so a fully-absent roster collapses to zero arguments
and reports a usage error. The exit is non-zero, so an exit-code-only assertion
would pass here for the wrong reason; the row asserts the coverage line is
printed and that the usage error is NOT what the operator is told.

## Group H — pin-and-resolve reporting (`--resolve`)

Predicted **FAIL** for both roster harnesses — no such mode exists yet.
