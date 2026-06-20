# Codex Fusion Rescue Rules

This platform overlay is source content for the generated Codex-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Lens Ownership

Codex remains responsible for the `adversarial` lens when Codex is available.
From Codex, when the Claude consult preflight succeeds, assign exactly one
non-adversarial panel slot to collect the Claude response. That slot may be
owned by a Codex `fusion-rescue-analyst` panel subagent, and it may call Claude
Code exactly once to collect the Claude response for that panel. Claude Code
does not need to spawn another nested subagent for the panel to count. If the
preflight fails, use the documented default fallback or require-cross-host block
instead of pretending an opposite-host response was collected.

## Claude Consult Path

From Codex, ask Claude Code through `${CLAUDE_BIN:-claude} -p` when available.
Before assigning a Claude consult panel, the Codex main agent must inspect the
active Codex permission/sandbox context. Claude consult is allowed only when the
current Codex permission state is exactly `danger-full-access`. If the state is
missing, unknown, `read-only`, `workspace-write`, or anything other than
`danger-full-access`, do not call Claude. State that Claude is unavailable
because the Codex permission state is not `danger-full-access`, then use three
current-host Codex panel agents in default mode. In `require-cross-host` mode,
block instead of pretending an opposite-host response was collected, and name
the current-host three-panel fallback as the next local option the user can
approve.

When the Codex permission preflight confirms `danger-full-access`, build the
Claude command as an argument vector, not through shell string interpolation.
The argument vector must enforce a read-only, non-persistent consult boundary:
`${CLAUDE_BIN:-claude}`, `--print`, `--model`, `opus`, `--permission-mode`,
`dontAsk`, `--tools`, `""`, `--no-session-persistence`, then the prompt packet,
unless the user explicitly supplied a different Claude model for this rescue.
The empty `--tools` value is the mechanical read-only boundary: Claude Opus must
answer from the redacted prompt packet and must not receive file, shell, network,
write, Task, Agent, Workflow, or plugin tools for this consult. If the active
Claude binary rejects `--tools ""`, cannot enforce a no-tools consult, or needs
write-capable permissions to run, treat the cross-host consult as unavailable.
The Claude prompt and active host permissions must still forbid file edits,
writes, installs, mutating commands, Codex calls, nested rescue, and any
host-to-host ping-pong.

From Codex, this is direct Opus panel review, not a request for Claude Code to
run its public Fusion Rescue workflow. Claude Opus must answer the assigned
panel directly. The Claude prompt must not ask Claude Code to invoke
`/oh-no-harness:fusion-rescue`, `oh-no-harness:fusion-rescue`,
`/codex:rescue`, `codex:codex-rescue`, Task, Agent, Workflow, subagents, or any
Claude-side skill or slash command. It must request only the assigned lens
analysis fields from Claude Opus.

For Codex-hosted Fusion Rescue, the cross-host slot may be a Codex panel
subagent whose only special responsibility is to run that Claude command and
return Claude's response as its panel output. If the active Claude binary rejects
those controls, cannot enforce them, or cannot return a panel response, treat
the cross-host consult as unavailable. The Claude prompt must include one
assigned lens, a redacted and minimized problem packet, the shared recursion
guard, and the instruction to avoid nested rescue, Codex calls, or host-to-host
ping-pong.

## Fallback Notes

Default mode degrades instead of blocking:

- If Claude is unavailable from Codex, record the command/path/auth failure
  class or missing response proof and continue.
- If the Codex permission state is not exactly `danger-full-access`, record
  `Claude unavailable: Codex permission state is not danger-full-access` and run
  all three panel slots on the current Codex host in default mode.

Require-cross-host mode blocks when the Claude consult path cannot return the
assigned panel output. The blocking output must include the attempted command,
permission state class, response-proof status, and current-host three-panel
fallback.
