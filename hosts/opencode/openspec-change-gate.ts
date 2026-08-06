// openspec-change-gate.ts — opencode wiring for the OpenSpec change-gate.
//
// opencode has no PreToolUse setting. Its equivalent interposition point is a
// plugin `tool.execute.before` hook, which can DENY because throwing from a
// before-hook aborts the tool call. This plugin is thin on purpose: it hands
// the tool call to the host-agnostic enforcement script
// (~/.agenticapps/bin/openspec-change-gate.sh) and blocks only when that script
// says to. The truth table lives in the script so every host enforces the same
// thing.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT THE GATE ACTUALLY BLOCKS ON, AND WHY THIS COMMENT EXISTS
// ─────────────────────────────────────────────────────────────────────────────
// ONE condition: `openspec validate --all` is not green. That is the whole of
// it. A blocked edit means a spec delta that does not parse, so the fix is to
// fix the delta.
//
// The version of this plugin installed on this machine says otherwise. At its
// line 8 it claims the gate enforces "validate + REVIEWS.md >=2", and its block
// message tells the operator the change "must pass 'openspec validate --all'
// AND carry REVIEWS.md with >=2 '## Reviewer:' sections before code".
//
// That stopped being true at gate 2.0.0. Review evidence is computed and
// REPORTED, never enforced: reviewer count, verdicts and independence all
// produce NOTE lines, and none of them fails any surface. Two rejections open
// the gate exactly as two approvals do.
//
// So this file is DERIVED from the installed copy, not lifted from it. An
// operator told the gate requires reviews will go and get reviews to unblock an
// edit that was never blocked for that reason, and will discount every later
// message from the same source. Wiring never asserts a rule the gate does not
// enforce — if the gate's behaviour changes, this text changes with it.
//
// A hook cannot gate the session that installed it: opencode loads plugins at
// session start, so this enforces from the NEXT session. The git pre-commit
// hook and CI are the floor that covers the installing session.
//
// Kill switch:   OPENSPEC_GATE_DISABLED=1  (fail open, no gating)
// Escape hatch:  GSD_SKIP_REVIEWS=1        (handled in the .sh, and logged)
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { homedir } from "node:os";
import { existsSync } from "node:fs";

// File-mutating opencode tools this gate inspects.
const MUTATORS = new Set(["edit", "write", "patch", "multiedit"]);

function gateScript(): string | null {
  const candidates = [
    process.env.OPENSPEC_CHANGE_GATE,
    join(homedir(), ".agenticapps", "bin", "openspec-change-gate.sh"),
  ].filter(Boolean) as string[];
  for (const c of candidates) if (existsSync(c)) return c;
  return null;
}

function pathFromArgs(args: any): string | undefined {
  if (!args || typeof args !== "object") return undefined;
  return args.filePath ?? args.file_path ?? args.path ?? args.file ?? undefined;
}

export const OpenspecChangeGate = async ({ directory, worktree }: any = {}) => ({
  "tool.execute.before": async (input: any, output: any) => {
    if (process.env.OPENSPEC_GATE_DISABLED === "1") return;

    const tool = String(input?.tool ?? "").toLowerCase();
    if (!MUTATORS.has(tool)) return;

    const filePath = pathFromArgs(output?.args);
    if (!filePath) return; // no derivable path — fail open, as the gate does

    const script = gateScript();
    // Not installed is not a block. The pre-commit hook and CI are the floor;
    // this hook is faster feedback on top of them, and bricking every edit on a
    // machine that never installed the workflow is not feedback.
    if (!script) return;

    let rc = 0;
    try {
      const res = spawnSync("bash", [script], {
        input: JSON.stringify({ tool, tool_input: { file_path: filePath } }),
        cwd: worktree ?? directory ?? process.cwd(),
        env: { ...process.env, OPENSPEC_GATE_SOURCE: "opencode-plugin", OPENSPEC_GATE_SELF: "opencode" },
        encoding: "utf8",
      });
      rc = res.status ?? 0;
      if (rc === 2) {
        const reason = String(res.stderr ?? "").trim();
        throw new Error(
          `[openspec-change-gate] Edit to '${filePath}' blocked.\n` +
            (reason ||
              "openspec validate --all is not green. Fix the spec delta that does not parse.") +
            `\n\nThis gate blocks on exactly one condition: validation is not green. ` +
            `It does not require review evidence. For a deliberate, logged override: GSD_SKIP_REVIEWS=1`,
        );
      }
    } catch (e) {
      // A thrown block must propagate; a wiring failure must not become one.
      if (e instanceof Error && e.message.startsWith("[openspec-change-gate]")) throw e;
      return;
    }
  },
});
