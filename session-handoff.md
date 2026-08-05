# Session Handoff — 2026-08-05 (fifth session)

## Donald's verdict on this session — read this first, before anything else

His words, not a summary I'd have chosen:

> Astonished. Similar to the whole shim-hooks thing — once again you make things
> so complicated. We are talking about an installer that installs some files to
> create a workflow that can be used to steer a coding agent better. And we are
> once again in this mess and back and forth. I am fed up with your bad work.
> You overcomplicate things that are so easy.
>
> I just want to be able to use different agents with a nice workflow, exactly
> as stated in the graphics of the core repo: **Linear** for taking
> requirements, **OpenSpec** for making design and then storing capabilities,
> **Superpowers** for structured execution. Yes, doing some reviews of plan and
> code is good. Doing database checks for RLS and some impeccable UI critique is
> cool. But this whole mess you produced is something nobody would like to use
> at all. It is a complicated mess.
>
> We are talking about an installer, and you are talking about changing the host
> repos for some weird shit.

He is right, and the proportion is the evidence. Making an installer ask before
`npm i -g` is about **fifteen lines per host**. Around that this repo now has a
~500-line static analyser and a ~900-line test suite for the analyser, and most
of this session went into fixing defects in that instrument rather than in
anything a user touches. The session ended with a proposal to vendor the
instrument into all four host repos with sha256 pins and a re-verification
protocol. That is the tail wagging the dog.

The shim-hooks episode was the same shape. This is a pattern, not an incident.

## Next session: start here

**Wait for Donald's cleanup instructions. He is clearing context and will give
them precisely.**

Do NOT resume the §21 / conformance-harness thread. Do NOT touch host repos.
Do NOT publish, vendor, or pin anything. The previous version of this file
pointed the next session at "publish the harness" — that steer is withdrawn and
is the exact thing he is fed up with.

Already dropped, and not to be reopened as "open questions": publishing
`installer-prereq-conformance.sh`, adding it to any `core-vendor.manifest`, and
adding any host CI step for it.

## What actually shipped today (facts, for cleanup planning)

Merged to core main:

- `#82` (2827fa1) — spec §21, the harness, its test suite
- `#83` (c71ffe9) — a one-line docs correction
- `#84` (348a878) — two harness fixes
- `#85` (f731288) — handoff

Merged to host repos — **four host repos were changed**:

- `claude-workflow` #113 (bb59fe6) — declares `git`
- `codex-workflow` #35 (5421812) — asks before `npm i -g`; declares `git`
- `opencode-workflow` #24 (9bf6015) — same, plus a real `--skip-upstream`
  parser bug fix
- `pi-agentic-apps-workflow` #20 (1f3af6e) — declares `git`; fixes a wrong
  "not a git repository" diagnosis

The installer behaviour changes themselves are small. The apparatus built to
score them is what he is objecting to, and it lives entirely in this repo:

- `spec/21-installer-prerequisites.md` (293 lines)
- `tools/installer-prereq-conformance.sh` (~500 lines)
- `tools/installer-prereq-conformance.test.sh` (~900 lines)
- two CI steps in `.github/workflows/openspec-gate.yml`
- `openspec/specs/installer-prerequisite-consent/`

He was offered the choice of deleting the harness and its suite outright, or
cutting it to ~20 lines that grep four installers for an unguarded global
install. He did not answer — he is giving instructions after clearing instead.
Do not pre-empt them.

## What he actually wants, in his own framing

Linear → OpenSpec → Superpowers, usable across several agents, matching the
graphics in this repo. Plan and code review are wanted. RLS/database checks and
UI critique are wanted. Everything added around those is suspect until he says
otherwise.

The test for any future proposal in this repo is whether it makes that loop
nicer to use. Nothing done today passes that test.
