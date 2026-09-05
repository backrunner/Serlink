# MCP Agent Access

Serlink provides a standalone [Model Context Protocol](https://modelcontextprotocol.io) (MCP) stdio server that lets an external AI agent (for example Claude Code) drive **app-owned** SSH terminal sessions. The `serlink-mcp` process handles client initialization and capability checks independently of the desktop app, connecting to its authenticated loopback backend only for tool calls. The embedded HTTP MCP endpoint also remains available for clients configured to connect directly.

Design principles:

- **Credentials never leave the app.** The agent never receives passwords or private keys. Serlink opens the SSH session itself, as a normal workspace terminal tab.
- **Explicit user authorization.** The first time an agent requests a session on a host, Serlink shows an approval dialog. If the vault is locked, tool calls fail with `vault_locked` until the user unlocks it in the app.
- **Dangerous command interception.** Commands sent by the agent are screened by a risk policy (`lib/features/mcp/data/command_risk_policy.dart`). Risky commands require an in-app confirmation (Allow once / Allow for session); a small set of destructive commands (disk overwrites, `mkfs`, fork bombs) is always blocked.
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

Open **Settings → Agent access** and start the server, then either:

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

## Exposed tools

All tools are prefixed `serlink_`:

- `serlink_list_hosts` — hosts from the vault (requires unlocked vault).
- `serlink_open_session` — opens a terminal tab on a host; triggers the in-app approval dialog on first use per client+host.
- `serlink_exec` — sends a command and returns the settled screen text (heuristic: output quiet for ~400 ms).
- `serlink_read_screen` — last N buffer lines.
- `serlink_send_input` — raw input for interactive programs (risk-checked when it contains newlines).
- `serlink_close_session`, `serlink_list_sessions`.

## Authorization lifecycle

- Grants are **in-memory only**: they expire when the app quits. Revoke individual grants in **Settings → Agent access → Active grants**; agent sessions are listed there too and can be closed.
- Error codes surfaced to the agent: `vault_locked`, `authorization_denied`, `authorization_required`, `command_blocked`, `command_denied`, `session_not_found`, `connect_timeout`. The stdio helper also returns `app_unavailable` for discovery/launch failures and `app_connection_lost` for failed in-flight calls.

## App Store review notes

The feature stays inside the sandbox (loopback server, user-selected authorization, no helper in the App Store variant). If review ever challenges it, flip `PlatformCapabilities.mcpServer` to direct-only to cut the feature from the App Store build without code surgery.

## Limitations

- `serlink_exec` detects "command finished" by output quiescence, not by shell exit status; long-running or streaming commands need an explicit `timeoutMs`. Shell-integration markers (OSC 133) are a possible future upgrade.
- The exec result is screen text (last N lines), not a byte-exact stream capture.
- Agent sessions do not use tmux/screen remote persistence; a dropped connection ends the session.
- `notifications/cancelled` from the MCP client is not propagated through the stdio relay in v1.
- Direct HTTP configurations require the desktop app to be running. Independent startup and on-demand app launch are provided by the stdio configuration in direct macOS builds.
