# MCP Agent Access

Serlink provides a standalone [Model Context Protocol](https://modelcontextprotocol.io) (MCP) stdio server that lets an external AI agent (for example Claude Code) drive **app-owned** SSH terminal sessions. The `serlink-mcp` process handles client initialization and capability checks independently of the desktop app, connecting to its authenticated loopback backend only for tool calls. The embedded HTTP MCP endpoint also remains available for clients configured to connect directly.

Design principles:

- **Credentials never leave the app.** The agent never receives passwords or private keys. Serlink opens the SSH session itself, as a normal workspace terminal tab.
- **Configurable host privacy.** Host and connection discovery require explicit sharing consent. Host discovery returns configuration including hostname/IP, username, tags, routing and connection settings; startup commands are excluded. Settings > MCP / Agent access > Manage > Strict host privacy defaults off. When enabled, discovery returns only opaque host IDs and display names. Credentials and credential references are always excluded. This controls metadata; remote terminal output may still contain addresses.
- **Explicit user authorization.** The first time an agent requests a session on a host, Serlink shows an approval dialog and, when permitted, an actionable macOS notification. If the vault is locked, tool calls fail with `vault_locked` until the user unlocks it in the app.
- **Dangerous command interception.** Commands sent by the agent are screened by a risk policy (`lib/features/mcp/data/command_risk_policy.dart`). Standard mode confirms every command. User-enabled Bypass skips ordinary command approval, but deletion and other risky commands require fresh approval for every execution. A small set of destructive commands (disk overwrites, `mkfs`, fork bombs) remains blocked. Optional decision-model protection adds semantic screening before execution.
- **Take back control anytime.** An agent session is a regular terminal tab — type in it to retake control. A badge marks agent-controlled panes; closing the tab or revoking the grant in Settings immediately ends agent access.
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
command approval allows **one execution** only. Host approval creates an
app-lifetime, revocable grant after in-app consent. Borrowing an existing
connection requires a separate grant for that specific connection. Command approvals allow one execution only; there is no session-wide approval for risky commands. Notification previews follow
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

## Exposed tools

All tools are prefixed `serlink_`:

- `serlink_list_hosts` — hosts from the vault after explicit discovery consent (requires unlocked vault).
- `serlink_open_session` — opens a terminal tab on a host, or an SFTP tab with `kind: "sftp"`; triggers the in-app approval dialog on first use per client+host.
- `serlink_list_connections` — lists workspace remote panes and SFTP connections, including manually opened sessions. Returns ids, host display names and connection states without terminal contents or endpoint metadata; local terminals are excluded.
- `serlink_attach_session` — borrows a connected session returned by `serlink_list_connections`, subject to separate per-client, per-connection consent covering existing terminal history and file access. It does not reconnect, sign again or take a session controlled by another MCP client.
- `serlink_sftp_list` — lists directory metadata in an authorized SFTP session.
- `serlink_sftp_download` — queues a single-file download into a new private directory: app-container Application Support on the App Store edition, or Downloads on the direct edition. In the App Store edition, use Export in Transfers to save the completed file through a native Save panel. Returns `taskId` and `localPath`, never file contents, and does not overwrite existing files.
- `serlink_transfer_status` — reports state and byte counts for this client's SFTP download. Poll until `completed` and verify backup checksums before proceeding with an upgrade.
- `serlink_transfer_cancel` — cancels this client's download. Partial files may remain; closing the SFTP session also cancels its transfers. Keep the session open until downloads finish.
- `serlink_exec` — sends a command and returns the settled screen text (heuristic: output quiet for ~400 ms).
- `serlink_read_screen` — last N buffer lines.
- `serlink_send_input` — complete submitted commands or Ctrl-C only, in both approval modes. Partial keystrokes and bare Enter are rejected.
- `serlink_close_session` — closes an MCP-created session, or releases a borrowed session while preserving the user's connection. Set `keepConnection: true` to hand an MCP-created connection back to the user without closing it.
- `serlink_list_sessions` — lists only sessions controlled by the calling MCP client, including a `borrowed` flag.

## Authorization lifecycle

- Discovery grants are separate from control grants, scoped to the client and strict/full privacy level, and appear in Settings for revocation. Changing from limited to full discovery requires that scope's consent. Startup commands are never included.
- Existing-connection grants are separate from new-session host grants and cover only the selected session ID.
- Grants are **in-memory only**: they expire when the app quits. Revoke individual grants in **Settings → Agent access → Active grants**; agent sessions are listed there too and can be closed.
- After the separate 60-second access approval, opening waits up to 120 seconds for the SSH channel. MCP progress distinguishes access approval from connection/authentication; SSH Agent signing may require approval in 1Password or another agent. Cancellation, expired authorization and connection failure clean up the new MCP tab, including late authentication results. Existing user tabs are not reused by MCP opens.
- Offline diagnostics record `ssh.auth.sign.start`, `ssh.auth.sign.success` or `ssh.auth.sign.failure`, elapsed time and a safe error code. Together with `ssh.auth.summary`, these distinguish a requested signature from a completed signature. They do not prove that a password manager displayed its UI, and contain no key, signature or password material.
- Error codes surfaced to the agent: `vault_locked`, `authorization_denied`, `authorization_required`, `command_blocked`, `command_denied`, `approval_timeout`, `request_cancelled`, `session_not_found`, `connect_timeout`. The stdio helper also returns `app_unavailable` for discovery/launch failures and `app_connection_lost` for failed in-flight calls.

## Command approval modes

Open **Settings → MCP / Agent access → Manage → Bypass command approval**.
The switch defaults off: **Standard** mode requires a fresh approval for every
command. Enable **Bypass** to automatically run ordinary commands after host
access is authorized. The switch is device-local, survives app restarts, and
is excluded from vault sync and backups. MCP clients cannot change it.

Both modes keep mandatory confirmation for deletion (`rm`, `rmdir`, `unlink`,
`find -delete`), destructive Git/container/database cleanup, file overwrites,
system shutdown, and opaque shell/script evaluation. Session allowlists cannot
waive these confirmations. Existing disk-destruction and fork-bomb hard blocks
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

## Decision-model command protection

Open **Settings → MCP / Agent access → Manage → Command protection → Configure**.
Enter your own TypeSafe API key, choose a System One model (default `jev-1.13.0`),
explicitly agree to complete-command sharing, and enable model protection. It is disabled until you configure and enable it. Legacy enabled configurations without the current consent cannot contact the provider until consent is renewed.
The API key, model and enablement are stored together in device-local secure
storage, separately from vault records, sync and backups. Removing the saved key
also disables model protection and clears consent. You can disable the feature and withdraw consent from the same dialog. Editing protection does not close agent sessions.

The first adapter implements [TypeSafe's System One API](https://docs.typesafe.ai/api),
`POST https://api.typesafe.ai/v1/systemone`. The application owns the execution
gate; `CommandDecisionModel` is the adapter interface for another decision provider.
Requests contain the command text and a typed Choice question. They do not attach
host records, credentials from the vault, terminal screens or command output.
Secrets embedded in a command are part of its text and would be sent too.
The API key is transmitted to TypeSafe in the authorization header, while its
storage remains device-local. TypeSafe may retain command content, account
identification and usage/telemetry under its terms; zero retention is not assumed.
See [TypeSafe privacy](https://typesafe.ai/legal/privacy-policy) and
[retention guidance](https://help.typesafe.ai/articles/5974925716-how-is-submitted-data-used-or-retained).

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
