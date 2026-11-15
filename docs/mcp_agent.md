# MCP Agent Access

Serlink provides a standalone [Model Context Protocol](https://modelcontextprotocol.io) (MCP) stdio server that lets an external AI agent (for example Claude Code) drive **app-owned** SSH terminal sessions. The `serlink-mcp` process handles client initialization and capability checks independently of the desktop app, connecting to its authenticated loopback backend only for tool calls. The embedded HTTP MCP endpoint also remains available for clients configured to connect directly.

Design principles:

- **Credentials never leave the app.** The agent never receives passwords or private keys. Serlink opens the SSH session itself, as a normal workspace terminal tab.
- **Configurable host privacy.** Host and connection discovery require remembered client access consent. Host discovery returns configuration including hostname/IP, username, tags, routing and connection settings; startup commands are excluded. Settings > MCP / Agent access > Manage > Strict host privacy defaults off. When enabled, discovery returns only opaque host IDs and display names. Credentials and credential references are always excluded. This controls metadata; remote terminal output may still contain addresses.
- **Explicit user authorization.** The first time a client requests discovery or a connection, Serlink shows an approval dialog covering all hosts and connections, and remembers allowed access on this device across restarts. Later connections reuse it until revoked. If the vault is locked, tool calls fail with `vault_locked` until the user unlocks it in the app.
- **Dangerous command interception.** Commands sent by the agent are screened by a risk policy (`lib/features/mcp/data/command_risk_policy.dart`). Standard mode confirms ordinary commands unless the user has allowed their displayed command scope for that session. User-enabled Bypass skips ordinary command approval, but deletion and other risky commands require fresh approval for every execution. A small set of destructive commands (disk overwrites, `mkfs`, fork bombs) remains blocked. Optional decision-model protection adds semantic screening before execution.
- **Take back control anytime.** An agent session is a regular terminal tab — type in it to retake control. A badge marks agent-controlled terminal and SFTP panes. SFTP badges identify the client and let the user release control while keeping the connection open. Closing the tab or revoking access in Settings ends agent control.
- **Quiet capability checks.** Starting the stdio server, initializing MCP, sending heartbeats, and listing tools do not connect to or launch the desktop app. A valid Serlink tool call connects to the running app or launches it on demand. The standalone process does not access the vault or SSH credentials itself.

## Availability by channel

| Channel | HTTP MCP endpoint | `serlink-mcp` stdio helper |
| --- | --- | --- |
| macOS direct (Developer ID) | yes | yes (bundled at `Contents/MacOS/serlink-mcp`) |
| macOS App Store | yes | no |
| other platforms | not yet (`PlatformCapabilities.mcpServer`) | no |

The desktop HTTP backend in both variants binds `127.0.0.1` only, uses a random port, and requires a per-launch bearer token. The standalone helper uses stdio and opens no listening port. The App Store build needs no entitlement changes: `com.apple.security.network.server` is already present in `macos/Runner/Release.entitlements`, and loopback listeners already ship for SSH local port forwarding.

## Setting up an MCP client

The embedded HTTP server starts automatically on macOS. Open **Settings → MCP / Agent access → Manage** to view its loopback URL and access token, or stop it with the **Agent server** switch. If it is stopped, enable the switch before using the HTTP configuration. Then either:

- **Copy HTTP MCP config (JSON)** — works in both channels while Serlink is running:
  ```json
  {
    "mcpServers": {
      "serlink": {
        "type": "http",
        "url": "http://127.0.0.1:<port>/mcp",
        "headers": { "Authorization": "Bearer <token>" }
      }
    }
  }
  ```
- **Copy stdio helper config (JSON)** — direct channel only; the helper runs independently and auto-launches Serlink only when a tool is called and the app is not running:
  ```json
  {
    "mcpServers": {
      "serlink": {
        "type": "stdio",
        "command": "/Applications/serlink.app/Contents/MacOS/serlink-mcp"
      }
    }
  }
  ```

On the first valid tool call, the stdio helper resolves the app's discovery file (`<Application Support>/mcp-server.json`, written on server start, mode `0600`) and connects to the in-app HTTP endpoint. Concurrent calls share one connection attempt and app launch. Tool definitions and agent instructions come from the same Flutter-free contract used by the desktop backend, so listing tools requires neither a discovery file nor a running app.

Overrides: `--discovery <path>`, `--connect-timeout <seconds>`, `SERLINK_MCP_DISCOVERY`, `SERLINK_APP_PATH`. The connection timeout (default 60 seconds) applies when a tool needs the app, including HTTP initialization. A launch or connection failure is returned as a tool error; the helper stays available for capability checks and subsequent calls. Closing the MCP client cancels pending startup waits. A failed in-flight tool call is never replayed automatically because it may already have executed; a subsequent call can establish a new backend connection.

## Approval notifications

In **Settings → Agent access**, enable **Approval notifications**. Enabling the
MCP server from this panel also requests macOS alert permission. Permission is
not requested automatically at app startup. If alerts are denied or unavailable,
the same approval remains available inside Serlink; System settings opens the
macOS notification settings, and the status refreshes when you return.

The original tool call waits for a decision for up to **60 seconds**, including
time queued behind another approval. Short command requests offer Allow / Deny / View
details; long or multiline commands require review in the app. Discovery and
host/connection access requests always open the full in-app data-sharing
disclosure; their notifications offer Deny / View details. Notification
command approval allows **one execution** only. Client access approval creates a revocable, device-local permission covering discovery,
new sessions and existing connections. It survives app restarts and does not
need to be repeated for each host or connection. Command approvals allow one execution only; there is no session-wide approval for risky commands. Notification previews follow
macOS settings and may include host display names and short commands.

Only one approval is presented at a time. The first decision wins across the
notification and dialog. Expiration, request cancellation, MCP session closure,
and server stop withdraw pending approvals. Vault/session validity is checked
while waiting and again before execution. Old notifications cannot authorize a
new request or survive an app restart. Cancelling a command that has already
started does **not** undo its remote effects.

Clients that supply a progress token receive waiting progress notifications.
Their own timeout may still end the request earlier; configure it above the
approval window plus connection/execution time. The stdio relay forwards
cancellation and enforces a four-minute backend request limit. The AI should call
the tool and wait without asking for a duplicate chat approval. A denial or
`approval_timeout` / `request_cancelled` must not trigger an automatic retry.
Vault unlocking and SSH authentication continue inside Serlink.

## Global agent skills

On direct desktop builds, every MCP server start detects supported local agents
and installs or updates the bundled `serlink-mcp` skill in their **user-level
global** directories. Detection checks existing agent configuration directories,
known executables on `PATH`, and supported macOS app bundles. This is local
discovery of supported clients, not proof that every client version can load the
skill or that a remote/cloud agent has received it. App Store builds do not
inspect or write other apps' configuration directories.

| Agent | Global skill root |
| --- | --- |
| Claude Code | `~/.claude/skills` |
| Cursor | `~/.cursor/skills` |
| Windsurf | `~/.codeium/windsurf/skills` |
| Kimi Code | `~/.kimi/skills` |
| OpenCode | `~/.config/opencode/skills` (honors `XDG_CONFIG_HOME`) |
| Codex | `~/.agents/skills` |

These roots follow the [Claude Code](https://code.claude.com/docs/en/skills),
[Cursor](https://cursor.com/docs/skills),
[Kimi Code](https://moonshotai.github.io/kimi-cli/en/customization/skills.html),
[OpenCode](https://opencode.ai/docs/skills/) and
[OpenAI Docs](https://learn.chatgpt.com/docs/build-skills) conventions. Windsurf's
root is also listed in the [skills installer registry](https://github.com/vercel-labs/skills/blob/main/src/agents.ts).

Only the `serlink-mcp/SKILL.md` file and its `.serlink-managed.json` receipt are
managed. Unchanged installed skills are not rewritten. An older managed copy is
updated atomically; a user-edited or unowned copy is kept and shown as customized.
The settings page provides separate global skill status and install/update
actions, even when the stdio helper is unavailable. Explicit replacement backs
up the existing content. A failure for one agent does not stop the other
installations or the MCP server. Symlinked skill files or skill directories are
kept rather than followed.

Writing MCP configuration remains a separate user action. The existing
“Install into agents” action installs both the MCP entry and a missing/managed
skill; it does not silently replace custom instructions. A newly installed agent
is picked up on the next MCP start or when reopening the manager. Restart the
agent if it does not discover the skill in its current session. Updating skills
does not upgrade the installed MCP helper or grant host access.

The skill source is `assets/agent_skills/serlink-mcp/SKILL.md`, bundled as a Flutter
asset so the installed app does not depend on this repository being present.

## Exposed tools

All tools are prefixed `serlink_`:

- `serlink_list_hosts` — hosts from the vault after explicit discovery consent (requires unlocked vault).
- `serlink_open_session` — opens a terminal tab on a host, or an SFTP tab with `kind: "sftp"`; requests remembered client access on first use; later connections reuse it.
- `serlink_list_connections` — lists workspace remote panes and SFTP connections, including manually opened sessions. Returns ids, host display names and connection states without terminal contents or endpoint metadata; local terminals are excluded.
- `serlink_attach_session` — borrows a connected session returned by `serlink_list_connections`, using remembered client access covering existing terminal history and file access. It does not reconnect, sign again or take a session controlled by another MCP client.
- `serlink_sftp_list` — lists directory metadata in an authorized SFTP session.
- `serlink_sftp_download` — queues a single-file download into a new private directory: app-container Application Support on the App Store edition, or Downloads on the direct edition. In the App Store edition, use Export in Transfers to save the completed file through a native Save panel. Returns `taskId` and `localPath`, never file contents, and does not overwrite existing files.
- `serlink_sftp_upload` — queues a single local file with `sessionId`, `localPath` and `remotePath` (both absolute paths, with a destination filename). Every upload requires fresh in-app approval, including in Bypass mode. The dialog shows the resolved local source, size, target host and remote path, and warns that an existing destination file will be replaced. The app streams the bytes; MCP does not return file contents. The source must be readable by Serlink; App Store sandbox restrictions still apply. Directories are not supported. Returns `taskId`, `localPath` and `remotePath`.
- `serlink_transfer_status` — reports state and byte counts for this client's SFTP upload or download. Poll until `completed` and verify backup checksums before proceeding with an upgrade.
- `serlink_transfer_cancel` — cancels this client's upload or download. Partial destination files may remain; closing the SFTP session also cancels its transfers. Keep the session open until transfers finish.
- `serlink_exec` — sends a command and returns the settled screen text (heuristic: output quiet for ~400 ms).
- `serlink_read_screen` — last N buffer lines.
- `serlink_send_input` — complete submitted commands or Ctrl-C only, in both approval modes. Partial keystrokes and bare Enter are rejected.
- `serlink_close_session` — closes an MCP-created session, or releases a borrowed session while preserving the user's connection. Set `keepConnection: true` to hand an MCP-created connection back to the user without closing it.
- `serlink_list_sessions` — lists only sessions controlled by the calling MCP client, including a `borrowed` flag.

## Authorization lifecycle

- Approving a client once covers discovery and opening or borrowing terminal/SFTP connections on all hosts. The initial dialog discloses this scope and persistence. The current strict/full privacy setting still controls metadata, and startup commands remain excluded. Changing privacy does not require a new client approval.
- Client consent is stored in device-local secure storage, excluded from vault synchronization, and survives app restarts. Revoke it in **Settings → Agent access → Allowed agents**. Revocation is saved; the next connection requires consent again. The settings action also releases controlled sessions while keeping their connections open. Session handles and command permissions are not restored.
- Consent is keyed by the negotiated MCP implementation name; clients using the same name and transport access reuse it. This is not a cryptographic process identity. The MCP bearer token still gates transport access, and vault unlocking, SSH authentication, command screening and per-upload approval remain separate.
- When a new client needs approval, it waits up to 60 seconds; opening then waits up to 120 seconds for the SSH channel. MCP progress distinguishes access approval from connection/authentication; SSH Agent signing may require approval in 1Password or another agent. Cancellation, expired authorization and connection failure clean up the new MCP tab, including late authentication results. Existing user tabs are not reused by MCP opens.
- Offline diagnostics record `ssh.auth.sign.start`, `ssh.auth.sign.success` or `ssh.auth.sign.failure`, elapsed time and a safe error code. Together with `ssh.auth.summary`, these distinguish a requested signature from a completed signature. They do not prove that a password manager displayed its UI, and contain no key, signature or password material.
- Error codes surfaced to the agent: `vault_locked`, `authorization_denied`, `authorization_required`, `authorization_unavailable`, `command_blocked`, `command_denied`, `approval_timeout`, `request_cancelled`, `session_not_found`, `connect_timeout`. The stdio helper also returns `app_unavailable` for discovery/launch failures and `app_connection_lost` for failed in-flight calls.

## Long commands, complete output and managed jobs

`serlink_exec` now has two execution modes. Use **`mode: "job"`** for large
scripts, large/unknown output sizes, and long operations:

```json
{
  "sessionId": "<terminal session>",
  "mode": "job",
  "cwd": "/srv/app",
  "command": "<complete script>",
  "timeoutMs": 1000,
  "maxChars": 16384
}
```

The command budget is **4 MiB of UTF-8 source**, up from 8 KiB. The entire source
passes local rules, optional model assessment and user approval before script
bytes are sent. A fresh non-PTY POSIX `sh -s` channel reuses the existing
authenticated SSH connection; source is streamed through stdin, avoiding terminal
line limits and the SSH exec argument-size limit. The script can include literal
Tab indentation. It does **not** inherit the interactive terminal's directory,
variables, aliases or shell state: pass an absolute `cwd` when it matters. The
SSH server's login directory is used when `cwd` is omitted. Commands inside the
script remain subject to the remote OS's own limits. Interactive/TUI programs
belong in terminal mode.

A job response includes `commandId`, `state`, `finished`, `exitCode`, `exitSignal`,
`output`, `nextCursor`, `hasMore`, `totalChars`, and `outputTruncated`. A wait
budget is **not a command runtime limit**. `timeoutMs` bounds only the initial
response wait (default 1 second, maximum 30 seconds); a managed operation keeps
running while the app/session stays open. Poll it with:

```json
{
  "sessionId": "<same session>",
  "commandId": "<returned commandId>",
  "cursor": 16384,
  "waitMs": 1000,
  "maxChars": 16384
}
```

Call **`serlink_command_status`** with the previous `nextCursor`. Drain every
`hasMore` page, then continue polling while `finished` is false, including silent
periods. A completed channel is reported only after stdout, stderr and the input
sender drain; pages use fresh output totals even when exit occurs during a read.
Only `exitCode: 0` establishes successful exit. A null exit code means the server
did not provide a status, not success. Cancellation of a status poll leaves its
job running. The relay's four-minute request deadline does not limit a job's
runtime because each poll is a separate bounded request. Recovery uses these
explicit cursors rather than an unbounded SSE replay cache.

Use `view: "command"` on `serlink_command_status` to page the complete submitted
source after context compaction; keep separate cursors for source and output.
If a response or command ID was lost, **`serlink_list_commands`** recovers the
retained job IDs and lifecycle metadata in that session. Never blindly rerun an
accepted script after a client timeout.

**`serlink_command_cancel`** requests SSH SIGINT; `cancel_requested` does not
claim the process stopped. Poll for channel completion. Ctrl-C in the app's
terminal or through `serlink_send_input` also requests interruption of that
session's managed jobs. Closing the session, revoking the host grant, locking or
changing vaults, stopping MCP, or quitting the app closes managed channels and
withdraws retained output. Already executed effects cannot be undone, and an SSH
server may not support signal delivery or terminate detached descendants.

**`serlink_command_release`** deletes a finished job and its retained output.
Up to 16 jobs are retained across sessions; release completed jobs after reading
them to free slots. Output is not persisted as vault history: UTF-8 text is
captured in private temporary files encrypted with per-capture keys held only in
memory, excluded from vault sync/backups, and deleted on release/session cleanup.
Each capture is bounded at **256 MiB**; hitting the limit or a storage failure is
explicitly reported through `outputTruncated`/`error`. Do not automatically rerun
an operation to recover missing output. For larger planned outputs, have the
script write a remote log and use the existing SFTP workflow. Binary data should
also use SFTP; text decoding replaces malformed UTF-8. Stdout and stderr are
merged in received order. Command source stays in memory until release.

Default **terminal mode** preserves the existing interactive context. Its response
contains the first retained output page plus a `screen` tail for immediate
context, with `completionKnown: false`. Quiet output is not proof the remote
process exited. Continue reading **`serlink_read_output`** with `nextCursor` to
retrieve all captured text, including long echo and output beyond terminal
scrollback; `serlink_read_screen` remains a screen snapshot, not an output log.
Terminal capture starts before `serlink_exec` sends input. Terminal submission
above 8 KiB returns `command_requires_job_mode` before any bytes are sent, so an
agent can submit the same complete source using job mode with a deliberate cwd.
This is a transport choice, not a risk denial. Provider context limits still
apply to model protection: source is never silently truncated or split to obtain
approval. A provider that cannot assess the full source fails closed.

## Command approval modes

Open **Settings → MCP / Agent access → Manage → Bypass command approval**.
The switch defaults off: **Standard** mode confirms each command unless its
displayed scope has been allowed for that session. Enable **Bypass** to automatically run ordinary commands after host
access is authorized. The switch is device-local, survives app restarts, and
is excluded from vault sync and backups. MCP clients cannot change it.

Both modes keep mandatory confirmation for deletion (`rm`, `rmdir`, `unlink`,
`find -delete`), destructive Git/container/database cleanup, system shutdown,
and opaque shell/script evaluation. Command-family allowlists cannot waive
these confirmations or file-overwrite review. A separately disclosed project
task grant can cover recognized file writes as described below.
Existing disk-destruction and fork-bomb hard blocks
remain non-overridable. Enabled model protection still applies and may reject a
command before approval. Bypass does not skip discovery consent, first-host
access approval, vault unlock, or host-key trust.

Use whole commands with `serlink_exec`, or complete newline-terminated commands
with `serlink_send_input`. Partial input, Tab completion, editing/history controls and bare Enter
are rejected in both modes, even when model protection is disabled, so commands
cannot be split across calls to evade screening. Ctrl-C remains available.
Changing modes invalidates pending executions; denial, timeout, cancellation,
grant revocation and disconnected sessions send no command bytes.

Local checks are conservative text rules, not a shell sandbox. They can flag
quoted prose and cannot establish the effects of aliases, remote executables,
or arbitrary terminal state. Keep the visible terminal under user supervision.

The command dialog offers **Allow Once** and, for ordinary literal commands,
**Allow Similar for Session**. The dialog shows the exact argv prefix, for example
`git status …`. Matching uses parsed argument boundaries, not substring matching;
`git reset`, a different executable/repository prefix, shell substitutions,
redirections and appended commands cannot inherit that grant. Unknown programs
receive only an exact argv grant. Compound or opaque input has no prefix grant.
The permission belongs to that agent's terminal session, is never persisted, and
is cleared by approval/model-setting changes or a new vault unlock generation.
Closing the session or revoking access also ends its use. Model protection and
mandatory dangerous-command review still run on every execution. Notification
approval continues to allow only one execution.

Bypass classifies literal read commands by their actual argv. Search terms or
filenames containing `rm`, `delete` or `mkfs` are data, as are quoted `echo`
arguments; ordinary branch creation (`git checkout -b`, `git switch -c`) and
index-only `git restore --staged` no longer trigger destructive cleanup rules.
Pipelines into interpreters or `xargs`, expansions, destructive operations and
program options that execute code retain conservative review.

Print-only `sed -n '1,120p' file`, a bounded set of `find` query predicates and
explicit `cp -n source destination` / `cp --no-clobber` are also recognized by
argv. Extra execution/write options fall back to conservative review. Literal
stdout redirection and file operations distinguish quoted data from executable
words: `printf 'rm -rf /' > note.txt` is a file write, not a deletion command.
Appending to shell startup files still requires confirmation.

### Project task approval

For recognized operations submitted with **`mode: "job"`** and an explicit,
canonical absolute **`cwd`** such as `/srv/app`, the full command dialog also
offers **Allow Project Task**. It discloses that the current connection/session
may query, create and replace ordinary project files. After choosing it once,
supported operations in the same directory no longer prompt, even in Standard
mode. This is separate from Bypass and is never enabled by the agent.

Eligible operations include bounded literal queries, non-recursive `cp`,
`mkdir`, `touch`, `tee`, and literal stdout `>` / `>>` targets. For example,
`cp src/a.txt out/a.txt`, `printf 'hello\n' | tee out/note.txt`, and
`printf 'updated' > out/note.txt` can share the grant. Every command and target
in a compound request must qualify. Unknown options, scripts, substitutions,
environment wrappers, local executables, hidden paths and `..` traversal do not
qualify. Neither deletion nor `mv` can inherit the permission. System
directories, filesystem roots and implicit/relative working directories cannot
be selected as task scopes.

The permission belongs to that client's session on that host. A working-directory
or execution-mode change, approval/model settings change, vault unlock-generation
change, session closure or access revocation ends its use. A cancelled/stale
approval cannot seed a grant. Every request still runs the configured model and
the final authorization/cancellation checks before any bytes are sent.
Notifications can only allow one execution; a project grant requires reviewing
the complete disclosure inside Serlink.

**Use only with trusted projects.** Scope matching checks literal command paths;
it does not resolve remote symbolic links, constrain remote tool implementations,
or provide an OS filesystem sandbox. A remote symlink can point outside the
displayed directory. Interactive terminal commands cannot use project task
permissions because their current working directory cannot be established
reliably.

## Decision-model command protection

Open **Settings → MCP / Agent access → Manage → Command protection → Configure**.
Choose a decision provider, configure its model and connection, explicitly agree
to complete-command sharing, then enable protection. The feature is off by default.

| Provider | Default model | Connection and authentication |
| --- | --- | --- |
| TypeSafe / Jev | `jev-1.13.0` | System One at `https://api.typesafe.ai/v1/systemone`; bearer API key |
| Google / Gemini Decision | `gemini-decision-1` | Decisions API at `https://generativelanguage.googleapis.com/v1beta/decisions`; `x-goog-api-key` |
| Cloudflare / Clef | `clef` | Workers AI `/client/v4/accounts/{accountId}/ai/run/@cf/cloudflare/{model}`; account ID and bearer API token. Model names are editable, including `clef-flash`. |
| Local / self-hosted | `clef` | Full System One inference URL; optional bearer API key |

Self-hosted services must accept the System One `model`, `state` and `questions`
request and return `model` and typed `answers`, including the choice,
probabilities and confidence. This is a decision protocol, not a chat-completions
endpoint. The default example is `http://127.0.0.1:8000/v1/systemone`; Serlink does
not start a model server. LAN hosts and HTTPS deployments are also supported.
HTTP sends command text and any key without encryption; use HTTPS on untrusted networks.

Provider, endpoint, API key, consent, model and enablement stay in device-local
secure storage, separately from vault records, sync and backups. Existing Jev
settings remain compatible without a migration or remote schema change. Legacy
settings without current consent cannot contact a provider. Changing the provider,
Cloudflare account or self-hosted URL requires renewed consent and never reuses
the previous recipient's key. Removing the saved key disables model protection and
clears consent. Editing protection keeps existing agent sessions open and
invalidates pending execution permits.

All adapters send only the complete command text and the same typed Choice
question. They do not attach host records, vault credentials, terminal screens
or command output. Secrets embedded in a command are part of its text and are
sent too. Retention depends on the selected provider or self-hosted operator.
The compact **Data & privacy** entry opens the full disclosure and links the selected provider's data terms:
[TypeSafe](https://typesafe.ai/legal/privacy-policy),
[Gemini](https://ai.google.dev/gemini-api/terms), and
[Cloudflare](https://developers.cloudflare.com/workers-ai/platform/data-usage/).
API contracts: [System One](https://docs.typesafe.ai/api/system-one),
[Gemini Decisions](https://aistudio.google.com/docs/decisions-api),
[Clef](https://developers.cloudflare.com/workers-ai/models/clef/).

The enforcement order is:

1. Local hard blocks reject the command without contacting the model.
2. When enabled, the model evaluates every remaining command, including ordinary commands
   in Bypass mode. Only a validated `safe`
   Choice with safe probability ≥ 0.98, dangerous probability ≤ 0.01 and confidence
   ≥ 0.90 passes. Dangerous, uncertain, malformed, oversized and unavailable
   results fail closed. These thresholds are conservative defaults, not a claim
   of measured shell-command detection accuracy.
3. Standard mode confirms every command; Bypass confirms every locally flagged
   command. A model result cannot waive confirmation. Grant, vault, pane and
   configuration revisions are rechecked
   after every asynchronous model/confirmation wait before sending any input.

HTTP calls have bounded deadlines and response sizes, no automatic retries,
no redirects and no command/result caching. Provider error bodies and commands
are not included in errors or diagnostic logs. Concurrent input in a single
session is serialized so assessed commands cannot be interleaved.

Use `serlink_exec` for complete commands. In both approval modes,
`serlink_send_input` rejects partial input, Tab completion, editing/history control sequences,
standalone Enter and text with an unsubmitted suffix. Complete submitted commands
are checked as a whole. Ctrl-C bypasses the input queue and invalidates pending submissions, so a late
safe judgment cannot execute after an interruption. It can interrupt a program or clear
input left in the terminal. If `command_input_reset_required`
is returned, send Ctrl-C, then submit a new complete command. Interactive TUI/REPL
keystrokes may be refused; do not split or disguise commands to bypass a refusal.

Rejections use the existing `command_blocked` code with a bounded detail such as
`command_model_blocked`, `command_model_uncertain`, `command_guard_unavailable`,
`command_guard_changed`, `command_approval_changed`,
`command_approval_unavailable`, `command_input_requires_exec` or
`command_input_reset_required` or `command_input_interrupted`. The same gate protects both HTTP clients and the
stdio helper. Manual typing in the visible user-owned terminal remains outside
MCP screening. Local rules and model judgments are layered checks, not a shell
sandbox, and cannot establish the effects of arbitrary remote state or scripts.

For a billable, synthetic model evaluation without SSH execution, set
`TYPESAFE_API_KEY` in your local environment and run
`dart run tool/check_mcp_command_model.dart` with the project SDK. It checks benign,
opaque, destructive, credential-reading and prompt-injection examples. No real
model accuracy or latency claim follows from the local fake-provider tests.

## App Store review notes

The feature stays inside the sandbox (loopback server, user-selected authorization, no helper in the App Store variant). If review ever challenges it, flip `PlatformCapabilities.mcpServer` to direct-only to cut the feature from the App Store build without code surgery.

## Limitations

### Connection diagnostics

The app writes private, rotated JSON-lines logs under
`<Application Support>/Serlink/logs/serlink-YYYY-MM-DD.log` (UTC dates). On macOS
the default directory is
`~/Library/Application Support/com.alkinum.serlink/Serlink/logs/`.

Correlate `mcp.session.open.*`, `workspace.ssh.failure`, and `ssh.*` events by
`sessionId` and `hostId`. `ssh.connect.success` means SSH authentication has
completed; `ssh.shell.ready` means the terminal channel and configured forwards
are ready. Failures include the operation stage, exception type, structured
nested causes, and protocol/OS error codes where available. Transport closure
and shell exit are logged separately, including the remote exit status when
provided. A closed transport alone does not identify who initiated the close.

Diagnostic entries omit credentials, terminal contents, commands, and arbitrary
exception messages. If a client only receives `connect_failed: Connection
failed.`, inspect the matching app log entries to distinguish authentication,
transport, channel, forwarding, and workspace failures.

### Runtime constraints

- `serlink_exec` detects "command finished" by output quiescence, not by shell exit status; long-running or streaming commands need an explicit `timeoutMs`. Shell-integration markers (OSC 133) are a possible future upgrade.
- The exec result is screen text (last N lines), not a byte-exact stream capture.
- Agent sessions do not use tmux/screen remote persistence; a dropped connection ends the session.
- `notifications/cancelled` withdraws pending approvals through both transports; cancellation cannot undo commands already sent.
- Direct HTTP configurations require the desktop app to be running. Independent startup and on-demand app launch are provided by the stdio configuration in direct macOS builds.
