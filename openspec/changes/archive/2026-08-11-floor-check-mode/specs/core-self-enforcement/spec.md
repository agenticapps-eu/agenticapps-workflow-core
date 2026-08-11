## MODIFIED Requirements

### Requirement: Core's local hooks binding is declared, and the fleet sweep does not remove it

The installer's sweep of redundant local `core.hooksPath` settings SHALL NOT
unset core's.

The sweep's rule is that a local binding naming the directory git would resolve
anyway grants no behaviour and is safe to remove. **Core is the one repository
where that reasoning is false.** Its binding names its own default hooks
directory and is therefore syntactically redundant, but removing it hands core
to the machine-level floor and breaks the resolution inversion this capability
exists to protect. A rule that reads only the *value* of the setting cannot tell
the two cases apart.

Core's binding SHALL therefore be **declared** rather than inferred, so that the
sweep excludes it by name and not by accident, and so that a reader can see it
is intentional. A binding that is load-bearing and looks redundant is exactly
the thing a future cleanup removes with a good conscience.

**The binder establishes it, in the same act that creates the hazard.** Setting
the global binding is the moment core's own hook stops being preferred; the
binder is the only thing that knows both facts at once, and it runs from inside
core's checkout by construction. So it SHALL set core's local binding and its
declaration **before** setting the global one, and SHALL NOT set the global
binding if establishing core's fails.

Every other candidate owner disclaims this in its own contract, which is why the
gap existed rather than being an oversight in one place:

| Candidate | Why not |
|---|---|
| `install.sh` | writing hooks into whatever repository the shell is standing in is the category error Decision 4 removed |
| `init-project.sh` | "no skills, no hooks, no host configuration — those are the machine's business" |
| `fresh-clone-needs-nothing` | a repository carries `openspec/` and one instruction file, "nothing else. No hooks, no shims" |
| core's CI | detects the absence; a detector is not an establisher |

This is **not** Decision 4's category error returning. That error was a machine
installer reaching into an arbitrary repository it happened to be standing in.
This is the binder repairing the single, known, deterministic casualty of its
own act, in the one repository it is by definition running from. The
displacement and the repair are one act, for the same reason "publish, then
bind" is one act: the orders are not symmetric and the safe one costs nothing.

#### Scenario: The binder runs before any global binding exists

- **WHEN** the binder is about to set the global `core.hooksPath`
- **THEN** it SHALL first set core's local `core.hooksPath` to core's resolved
  default hooks directory, together with `agenticapps.hooksbinding=declared`
- **AND** it SHALL NOT set the global binding if either write fails
- **AND** a commit in core afterwards SHALL run core's working-tree gate

#### Scenario: Core's binding is already established

- **WHEN** core already carries a declared local binding naming its default
  hooks directory
- **THEN** the binder SHALL report it satisfied and rewrite nothing
- **AND** SHALL proceed to the global binding

#### Scenario: The sweep encounters core

- **WHEN** the sweep evaluates core's local `core.hooksPath`
- **THEN** it SHALL leave the binding in place
- **AND** SHALL report it as declared rather than as redundant


**Where the declaration is absent the binding is at risk**, and that condition
SHALL be reportable rather than discovered by its consequences. The sweep's rule
reads the *value* of the setting, so an undeclared binding on core is
indistinguishable from the five redundant ones it exists to remove, and the next
installer run unsets it. Nothing on disk says so before it happens, and after it
happens the symptom is that core's commits are scored by the published gate
rather than by the working tree it is editing — which is the one thing ADR-0028
exists to prevent, arriving silently.

The binder's check mode is where that is reported, because it is the artifact
that establishes the declaration and therefore the one that knows what a correct
one looks like.

**Core SHALL be classified by where its binding points, not by whether one
exists.** Reading only presence gets every case but one wrong, and each wrong
answer sends a reader somewhere useless:

| State | What presence-reading says | What is true |
|---|---|---|
| unset, machine unbound | governed by the floor | nothing governs it; git resolves core's own hooks directory |
| declared, pointing elsewhere | correctly bound | core is **not** scored by its working tree, and a declaration cannot launder an arbitrary path |
| undeclared, pointing elsewhere | at risk of being swept | not sweepable at all — the sweep removes only a binding naming the directory git would resolve anyway, and the migration refuses a foreign one by name |

#### Scenario: The declaration is missing

- **WHEN** core carries a local `core.hooksPath` that names core's own hooks
  directory and is not declared
- **THEN** `--check` SHALL report the binding as undeclared and at risk of being
  swept
- **AND** SHALL NOT report core as correctly bound

#### Scenario: The binding points somewhere other than core's own hooks

- **WHEN** core carries a local `core.hooksPath` naming a directory that is not
  core's own hooks directory, declared or not
- **THEN** `--check` SHALL report it as foreign, naming both paths
- **AND** SHALL NOT report it as at risk of being swept, because the sweep does
  not remove it

#### Scenario: Core has no local binding and no floor governs it

- **WHEN** core carries no local `core.hooksPath` and no global binding is set
- **THEN** `--check` SHALL report that nothing binds core and name the directory
  git resolves
- **AND** SHALL NOT report core as governed by the floor

#### Scenario: The declaration is present

- **WHEN** core carries a local `core.hooksPath` naming core's own hooks
  directory, with `agenticapps.hooksbinding=declared`
- **THEN** `--check` SHALL report it as declared
- **AND** SHALL NOT report it as redundant, which is what its value alone would
  suggest
