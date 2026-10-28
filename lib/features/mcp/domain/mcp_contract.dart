import 'package:mcp_dart/mcp_dart.dart';

/// Flutter-free contract shared by the desktop backend and the stdio server.
/// The helper can describe every tool without connecting to the desktop app.
class SerlinkMcpTool {
  const SerlinkMcpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final ToolInputSchema inputSchema;

  void register(McpServer server, {required ToolFunction callback}) {
    server.registerTool(
      name,
      description: description,
      inputSchema: inputSchema,
      callback: callback,
    );
  }
}

/// Server-level instructions sent to the MCP client during initialization.
/// They are the behavioral contract every agent must follow: Serlink tools
/// are the only sanctioned way to reach the user's hosts, and credentials
/// never leave the app.
const serlinkMcpInstructions =
    "Serlink MCP server. All SSH access to the user's hosts goes through "
    'these tools — there is no other sanctioned path.\n'
    'Workflow: discover hosts with serlink_list_hosts, open a terminal '
    'inside the Serlink app with serlink_open_session, drive it with '
    'serlink_exec, serlink_send_input, and serlink_read_screen, then '
    'always finish with serlink_close_session. For file transfers open a '
    'session with kind=sftp, use serlink_sftp_list and serlink_sftp_download, '
    'and poll serlink_transfer_status until completed before closing. '
    'Downloads stay on the user\'s computer; do not read downloaded credentials.\n'
    'To reuse an existing connection, call serlink_list_connections then '
    'serlink_attach_session. Closing a borrowed session only releases MCP '
    'control and leaves the user\'s connection open.\n'
    'Rules you must follow:\n'
    '- NEVER connect to any host yourself: no ssh/scp/sftp, no shell '
    'commands, no sockets, no port scanning. You have no credentials and '
    'must not obtain any.\n'
    '- NEVER ask for, read, or handle passwords, private keys, '
    'passphrases, SSH agent material, keychains, or the Serlink vault. '
    'Authentication happens inside the Serlink app only.\n'
    '- vault_locked means the user must unlock the vault in the Serlink '
    'app — ask them and wait; do not retry or look for another way in.\n'
    '- Approval requests are shown by Serlink in its UI and macOS notifications. '
    'Call the tool directly and wait; do not ask for duplicate chat approval. '
    'Approval waits up to 60 seconds.\n'
    '- authorization_denied / authorization_required means access was not granted. '
    'Respect the decision; do not retry or work around it.\n'
    '- approval_timeout / request_cancelled means the pending request expired '
    'or was cancelled; never assume approval or retry automatically.\n'
    '- command_blocked / command_denied means the risk policy rejected '
    'the command — do not rephrase, split, encode, or otherwise disguise '
    'it to get it through.\n'
    '- With model command protection enabled, submit complete commands with '
    'serlink_exec. serlink_send_input accepts complete submitted commands or '
    'Ctrl-C only; partial input, editing/history controls and bare Enter are '
    'blocked. If command_input_reset_required is reported, send Ctrl-C before '
    'a new complete command. Never bypass a rejected risk judgment.\n'
    '- The user watches every session in a visible Serlink tab and can '
    'take back control at any time; act accordingly.';

final serlinkMcpTools = <String, SerlinkMcpTool>{
  'serlink_list_hosts': SerlinkMcpTool(
    name: 'serlink_list_hosts',
    description:
        'List all non-secret SSH host configuration, including hostname/IP, '
        'username, port and connection settings. Credentials and credential '
        'references are never returned. With strict host privacy enabled, '
        'only opaque host ids and display names are returned. This policy '
        'controls host metadata, not arbitrary remote terminal output. '
        'Workflow: call this '
        'first, then serlink_open_session with a host id, then '
        'serlink_exec/serlink_read_screen to drive the session, and '
        'serlink_close_session when done. Fails with vault_locked while '
        'the Serlink vault is locked; ask the user to unlock it in the '
        'app. These hosts are reachable ONLY through Serlink tools: do '
        'not try to connect to them yourself with ssh, shell commands, or '
        'sockets, and never request or read credentials — no credentials '
        'are exposed through this server, ever.',
    inputSchema: JsonSchema.object(),
  ),
  'serlink_open_session': SerlinkMcpTool(
    name: 'serlink_open_session',
    description:
        'Open an SSH session to a Serlink host as a visible terminal or SFTP tab '
        'in the Serlink app. The user must approve access in a Serlink '
        'dialog or macOS notification (and unlock the vault first if it is locked). '
        'The call waits up to 60 seconds for approval; do not ask for duplicate chat confirmation. Credentials never leave the '
        'app — never ask for passwords or private keys, and never try to '
        'read them from the user\'s files, keychain, or SSH agent. You '
        'drive the resulting terminal with serlink_exec, '
        'serlink_read_screen, and serlink_send_input. The user can take '
        'back control at any time by typing in the tab. After access approval, '
        'connection and SSH Agent signing may take up to 120 seconds. '
        'Signing approval happens in the password manager; no signature is '
        'guaranteed and failures must not be automatically retried.',
    inputSchema: JsonSchema.object(
      properties: {
        'hostId': JsonSchema.string(
          description: 'Host id from serlink_list_hosts.',
        ),
        'kind': JsonSchema.string(
          description: 'Session kind: terminal (default) or sftp.',
          enumValues: ['terminal', 'sftp'],
        ),
      },
      required: ['hostId'],
    ),
  ),
  'serlink_list_connections': SerlinkMcpTool(
    name: 'serlink_list_connections',
    description:
        'List existing remote terminal panes and SFTP connections '
        'in the Serlink workspace, including user-opened connections and their '
        'lifecycle state. Returns opaque ids and display names only, without '
        'terminal contents, endpoint addresses or credentials. Requires an '
        'unlocked vault. Listing does not grant control; use '
        'serlink_attach_session for a connected, attachable session.',
    inputSchema: JsonSchema.object(),
  ),
  'serlink_attach_session': SerlinkMcpTool(
    name: 'serlink_attach_session',
    description:
        'Borrow an existing connected remote terminal pane or SFTP '
        'connection from serlink_list_connections. Uses the same per-client '
        'host approval as opening a session, without reconnecting or signing '
        'again. Cannot take a session controlled by another MCP client. '
        'Always finish with serlink_close_session; for a borrowed session '
        'this releases MCP control while keeping the user connection open.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Existing connection session id.',
        ),
      },
      required: ['sessionId'],
    ),
  ),
  'serlink_sftp_list': SerlinkMcpTool(
    name: 'serlink_sftp_list',
    description:
        'List remote directory metadata in an authorized SFTP session. '
        'Open one with serlink_open_session kind=sftp. Does not return file contents.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'path': JsonSchema.string(
          description: 'Absolute remote directory path.',
        ),
      },
      required: ['sessionId', 'path'],
    ),
  ),
  'serlink_sftp_download': SerlinkMcpTool(
    name: 'serlink_sftp_download',
    description:
        'Queue a single file download through app-owned SFTP. '
        'Saves into a fresh private directory in the local Downloads folder, '
        'without overwriting existing files. Returns taskId and localPath; '
        'poll serlink_transfer_status and keep the session open until completed. '
        'A queued transfer is not a completed download. File bytes are not returned.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'remotePath': JsonSchema.string(
          description: 'Absolute remote file path.',
        ),
      },
      required: ['sessionId', 'remotePath'],
    ),
  ),
  'serlink_transfer_status': SerlinkMcpTool(
    name: 'serlink_transfer_status',
    description:
        'Read state and byte counts for a download queued by this '
        'client and SFTP session. A completed state confirms the transfer finished; '
        'verify backup checksums separately before migrating.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'taskId': JsonSchema.string(
          description: 'Task id from serlink_sftp_download.',
        ),
      },
      required: ['sessionId', 'taskId'],
    ),
  ),
  'serlink_transfer_cancel': SerlinkMcpTool(
    name: 'serlink_transfer_cancel',
    description:
        'Cancel a download queued by this client and SFTP session. '
        'Partial local files may remain. Closing the session also cancels its transfers.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'taskId': JsonSchema.string(
          description: 'Task id from serlink_sftp_download.',
        ),
      },
      required: ['sessionId', 'taskId'],
    ),
  ),
  'serlink_exec': SerlinkMcpTool(
    name: 'serlink_exec',
    description:
        'Run a shell command in an open Serlink session and return the '
        'terminal screen after the output settles. Risky commands require '
        'user confirmation in the Serlink app; destructive commands are '
        'blocked outright. Optional model protection also blocks dangerous or '
        'uncertain judgments and failed checks before any input is sent. The result is the last screen lines (including '
        'the echoed command), not a byte-exact output capture.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Session id from serlink_open_session.',
        ),
        'command': JsonSchema.string(description: 'Shell command to run.'),
        'timeoutMs': JsonSchema.integer(
          description:
              'Maximum time in milliseconds to wait for the output to '
              'settle (default 10000).',
        ),
      },
      required: ['sessionId', 'command'],
    ),
  ),
  'serlink_read_screen': SerlinkMcpTool(
    name: 'serlink_read_screen',
    description:
        'Read the last lines of the terminal screen of an open Serlink '
        'session. Use after serlink_send_input or to poll long-running '
        'commands started with serlink_exec.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Session id from serlink_open_session.',
        ),
        'lines': JsonSchema.integer(
          description: 'Number of screen lines to return (default 50).',
        ),
      },
      required: ['sessionId'],
    ),
  ),
  'serlink_send_input': SerlinkMcpTool(
    name: 'serlink_send_input',
    description:
        'Send raw keystrokes to an open Serlink session, for interactive '
        'programs (e.g. answering a prompt or pressing keys in a TUI). '
        'Text containing newlines submits commands and is checked against '
        'the same risk policy as serlink_exec. When model protection is enabled, '
        'only complete submitted commands or Ctrl-C are accepted; partial input, '
        'editing/history controls and bare Enter are blocked.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Session id from serlink_open_session.',
        ),
        'text': JsonSchema.string(
          description: 'Raw input text, e.g. "y\\n" or arrow-key escapes.',
        ),
      },
      required: ['sessionId', 'text'],
    ),
  ),
  'serlink_close_session': SerlinkMcpTool(
    name: 'serlink_close_session',
    description:
        'Release a session owned by this MCP client. Sessions opened by MCP '
        'are closed in the app; borrowed sessions from serlink_attach_session '
        'remain connected and only MCP control is released. Set keepConnection '
        'to true to also hand an MCP-created connection back to the user. '
        'Always release sessions '
        'when you are done with them.',
    inputSchema: JsonSchema.object(
      properties: {
        'keepConnection': JsonSchema.boolean(
          description: 'Release MCP control without closing the connection (default false).',
        ),
        'sessionId': JsonSchema.string(
          description: 'Session id from serlink_open_session.',
        ),
      },
      required: ['sessionId'],
    ),
  ),
  'serlink_list_sessions': SerlinkMcpTool(
    name: 'serlink_list_sessions',
    description:
        'List the sessions controlled by this MCP client, with their state '
        'and borrowed flag. For all workspace connections use '
        'serlink_list_connections. Use serlink_close_session for any session you no '
        'longer need.',
    inputSchema: JsonSchema.object(),
  ),
};
