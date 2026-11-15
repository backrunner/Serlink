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
/// are never returned by credential APIs. Remote content can contain secrets.
const serlinkMcpInstructions =
    "Serlink MCP server. All SSH access to the user's hosts goes through "
    'these tools — there is no other sanctioned path.\n'
    'Workflow: discover hosts with serlink_list_hosts, open a terminal '
    'inside the Serlink app with serlink_open_session, drive it with '
    'serlink_exec, serlink_send_input, and serlink_read_screen, then '
    'always finish with serlink_close_session. For file transfers open a '
    'session with kind=sftp, use serlink_sftp_list, serlink_sftp_download or serlink_sftp_upload, '
    'and poll serlink_transfer_status until completed before closing. '
    'Downloads stay on the user\'s computer; do not read downloaded credentials.\n'
    'Uploads require fresh in-app approval of the local source and remote destination, '
    'including replacement of existing destination files. upload_denied means the user '
    'refused the transfer; do not retry automatically. Never upload credentials or vault files.\n'
    'To reuse an existing connection, call serlink_list_connections then '
    'serlink_attach_session. Closing a borrowed session only releases MCP '
    'control and leaves the user\'s connection open.\n'
    'Client access is approved once and remembered on this device across app restarts. '
    'It covers discovery and opening or borrowing terminal/SFTP connections on all hosts, '
    'under the current privacy setting. The user can revoke it in Serlink settings. '
    'This never unlocks the vault or waives command/upload approval.\n'
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
    '- authorization_unavailable means local client consent could not be loaded or saved. '
    'Report it and stop; do not assume remembered access or retry automatically.\n'
    '- approval_timeout / request_cancelled means the pending request expired '
    'or was cancelled; never assume approval or retry automatically.\n'
    '- command_blocked / command_denied means the risk policy rejected '
    'the command — do not rephrase, split, encode, or otherwise disguise '
    'it to get it through.\n'
    '- Standard mode requires approval unless the user allowed the displayed '
    'command scope for this session. User-enabled bypass runs ordinary commands '
    'automatically; risky commands still need fresh approval and hard blocks remain. Bypass never grants host access '
    'or disables model protection. Only the user can change this in Serlink.\n'
    '- In either mode, submit complete commands with '
    'serlink_exec. serlink_send_input accepts complete submitted commands or '
    'Ctrl-C only; partial input, editing/history controls and bare Enter are '
    'blocked. If command_input_reset_required is reported, send Ctrl-C before '
    'a new complete command. Never bypass a rejected risk judgment.\n'
    '- For long scripts or slow operations use serlink_exec mode=job with an explicit cwd. '
    'The complete script (up to 4 MiB UTF-8) is streamed to a fresh sh process on the existing SSH connection, '
    'not typed into a terminal; it does not inherit interactive cwd, shell variables or aliases. '
    'Use serlink_command_status with commandId and nextCursor to read every output page; '
    'hasMore means unread output, finished indicates channel completion after both streams drain, and exitCode may be null. '
    'Quiet output or a polling timeout never proves completion. Continue polling while unfinished, including silent periods. '
    'Recover lost job IDs with serlink_list_commands before considering any rerun. Use serlink_command_cancel to request interrupt, and release completed output with serlink_command_release. '
    'A cancelled poll does not cancel its job. Never retry a submitted script automatically. '
    'command_requires_job_mode permits resubmitting the identical source with mode=job; it is not a risk denial.\n'
    '- Terminal mode returns paginated output and a screen snapshot. Always drain hasMore via serlink_read_output using nextCursor; the last screen lines alone may omit errors or long echo.\n'
    '- The user watches every session in a visible Serlink tab and can '
    'take back control at any time; act accordingly.';

final serlinkMcpTools = <String, SerlinkMcpTool>{
  'serlink_list_hosts': SerlinkMcpTool(
    name: 'serlink_list_hosts',
    description:
        'With remembered client access consent, list SSH host configuration, including hostname/IP, '
        'username, port and connection settings. Credentials and credential '
        'references and startup commands are never returned. With strict host privacy enabled, '
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
        'are returned by host discovery. Remote terminal output and files may contain secrets; do not seek them.',
    inputSchema: JsonSchema.object(),
  ),
  'serlink_open_session': SerlinkMcpTool(
    name: 'serlink_open_session',
    description:
        'Open an SSH session to a Serlink host as a visible terminal or SFTP tab '
        'in the Serlink app. Unrecognized clients must approve remembered access in a Serlink '
        'dialog (notifications open its full disclosure). Approved clients reuse that access '
        'on future connections; unlock the vault in the app if it is locked. '
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
        'unlocked vault and remembered client access consent. Listing does not take control; use '
        'serlink_attach_session for a connected, attachable session.',
    inputSchema: JsonSchema.object(),
  ),
  'serlink_attach_session': SerlinkMcpTool(
    name: 'serlink_attach_session',
    description:
        'Borrow an existing connected remote terminal pane or SFTP '
        'connection from serlink_list_connections. Reuses remembered client access '
        'covering existing buffers and connection control, without reconnecting or signing '
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
        'Saves into a fresh private directory: app-container storage on the App Store edition '
        '(use Export in Transfers for a native Save panel), or Downloads in the direct edition, '
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
  'serlink_sftp_upload': SerlinkMcpTool(
    name: 'serlink_sftp_upload',
    description:
        'Queue a single local file upload through app-owned SFTP. Requires '
        'fresh in-app approval of the source, destination and replacement warning '
        'for every upload, including in bypass mode. Existing remote files are replaced. '
        'localPath must be an absolute path readable by the Serlink app; App Store '
        'sandbox restrictions still apply. Directories are not supported. '
        'File bytes are streamed by the app and never returned through MCP. '
        'Returns taskId; poll serlink_transfer_status until completed and keep '
        'the SFTP session open. Queued does not mean completed. '
        'Never select credentials, private keys or vault files for upload.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'localPath': JsonSchema.string(
          description:
              'Absolute local file path on the computer running Serlink.',
        ),
        'remotePath': JsonSchema.string(
          description:
              'Absolute remote destination file path, including filename.',
        ),
      },
      required: ['sessionId', 'localPath', 'remotePath'],
    ),
  ),
  'serlink_transfer_status': SerlinkMcpTool(
    name: 'serlink_transfer_status',
    description:
        'Read state and byte counts for an upload or download queued by this '
        'client and SFTP session. A completed state confirms the transfer finished; '
        'verify backup checksums separately before migrating.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'taskId': JsonSchema.string(
          description:
              'Task id from serlink_sftp_download or serlink_sftp_upload.',
        ),
      },
      required: ['sessionId', 'taskId'],
    ),
  ),
  'serlink_transfer_cancel': SerlinkMcpTool(
    name: 'serlink_transfer_cancel',
    description:
        'Cancel an upload or download queued by this client and SFTP session. '
        'Partial destination files may remain. Closing the session also cancels its transfers.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(description: 'SFTP session id.'),
        'taskId': JsonSchema.string(
          description:
              'Task id from serlink_sftp_download or serlink_sftp_upload.',
        ),
      },
      required: ['sessionId', 'taskId'],
    ),
  ),
  'serlink_exec': SerlinkMcpTool(
    name: 'serlink_exec',
    description:
        'Execute a complete command under the same local, model and user approval gates. '
        'Use mode=job for long scripts (up to 4 MiB UTF-8), large output or slow operations. '
        'Job mode streams the script to a fresh POSIX sh on the existing SSH connection, '
        'without PTY/argv line limits; specify cwd because it does not inherit terminal cwd, '
        'variables or aliases. Returns commandId, state, exitCode, output page and nextCursor. '
        'Jobs continue after this call returns; poll serlink_command_status until finished and '
        'drain all hasMore pages. Output is retained encrypted locally (256 MiB per job) until '
        'release/session close; outputTruncated explicitly reports a capture limit. '
        'Default mode=terminal preserves interactive context and returns a retained output page plus a settled screen '
        '(not proof of completion); over 8 KiB requires job mode. Never retry an accepted command.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Open terminal session id.',
        ),
        'command': JsonSchema.string(
          description: 'Complete command or script, up to 4 MiB UTF-8. Never truncated for risk assessment.',
        ),
        'mode': JsonSchema.string(
          description: 'terminal (default) or job. Job is recommended for long scripts and output.',
          enumValues: ['terminal', 'job'],
        ),
        'cwd': JsonSchema.string(
          description: 'Job working directory; default is the SSH server login directory. Terminal mode cannot change cwd via this parameter.',
        ),
        'timeoutMs': JsonSchema.integer(
          description: 'Response wait budget, not runtime limit. Job: default 1000, range 0..30000; terminal: default 10000, range 500..120000.',
        ),
        'maxChars': JsonSchema.integer(
          description: 'Maximum job output characters per response, default/max 65536. Follow nextCursor for more.',
        ),
      },
      required: ['sessionId', 'command'],
    ),
  ),
  'serlink_list_commands': SerlinkMcpTool(
    name: 'serlink_list_commands',
    description:
        'List retained managed jobs in your terminal session, including commandId, '
        'state, exitCode, cwd, source size and available output. Recover job IDs after a lost '
        'response or context compaction; inspect status/source before deciding anything. Never blindly rerun an accepted script.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Owning terminal session id.',
        ),
      },
      required: ['sessionId'],
    ),
  ),
  'serlink_command_status': SerlinkMcpTool(
    name: 'serlink_command_status',
    description:
        'Read retained output and true lifecycle of a managed job. Pass the previous nextCursor; '
        'drain hasMore pages and keep polling until finished. waitMs bounds this poll, not execution. '
        'finished may have exitCode=null when the server reports no status. stdout and stderr are merged '
        'in received order. Use view=command to page the original complete script after context compaction. '
        'Only exitCode=0 proves success. Cancelling this poll leaves the job running.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Owning terminal session id.',
        ),
        'commandId': JsonSchema.string(
          description: 'commandId returned by serlink_exec mode=job.',
        ),
        'view': JsonSchema.string(
          description: 'output (default) or command (original source); maintain separate nextCursor values.',
          enumValues: ['output', 'command'],
        ),
        'cursor': JsonSchema.integer(
          description: 'Opaque character cursor; start at 0 and use returned nextCursor.',
        ),
        'maxChars': JsonSchema.integer(
          description: 'Page size, default/max 65536.',
        ),
        'waitMs': JsonSchema.integer(
          description:
              'Wait for new output or exit, default 1000, maximum 30000.',
        ),
      },
      required: ['sessionId', 'commandId'],
    ),
  ),
  'serlink_command_cancel': SerlinkMcpTool(
    name: 'serlink_command_cancel',
    description:
        'Request SSH SIGINT for a managed job. cancel_requested is not proof it stopped; '
        'poll status until finished. Output remains readable. Already executed effects cannot be undone.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Owning terminal session id.',
        ),
        'commandId': JsonSchema.string(description: 'Managed command id.'),
      },
      required: ['sessionId', 'commandId'],
    ),
  ),
  'serlink_command_release': SerlinkMcpTool(
    name: 'serlink_command_release',
    description:
        'Delete retained encrypted output for a finished managed job after reading it. '
        'At most 16 jobs are retained across sessions; release finished jobs to free slots. Running jobs cannot be released.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Owning terminal session id.',
        ),
        'commandId': JsonSchema.string(description: 'Finished command id.'),
      },
      required: ['sessionId', 'commandId'],
    ),
  ),
  'serlink_read_output': SerlinkMcpTool(
    name: 'serlink_read_output',
    description:
        'Read retained raw terminal output beyond the terminal scrollback. '
        'Capture starts before serlink_exec sends input; use its nextCursor to drain all hasMore pages, '
        'then poll for later output. Cursors include command echo and ANSI sequences. '
        'Quiet output does not establish completion; use job mode for true exit status. '
        'Output is encrypted locally, capped at 256 MiB per session; outputTruncated reports any loss.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Owning terminal session id.',
        ),
        'cursor': JsonSchema.integer(
          description: 'Opaque cursor, start at 0 or the previous nextCursor.',
        ),
        'maxChars': JsonSchema.integer(
          description: 'Page size, default/max 65536.',
        ),
        'waitMs': JsonSchema.integer(
          description: 'Wait for new output, default 1000, maximum 30000.',
        ),
      },
      required: ['sessionId'],
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
        'Send complete submitted commands or Ctrl-C to an open Serlink session. '
        'Both standard and bypass modes enforce the same input and risk checks '
        'as serlink_exec; partial input, '
        'editing/history controls and bare Enter are blocked.',
    inputSchema: JsonSchema.object(
      properties: {
        'sessionId': JsonSchema.string(
          description: 'Session id from serlink_open_session.',
        ),
        'text': JsonSchema.string(
          description:
              'A complete command ending in a newline, or Ctrl-C (U+0003).',
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
