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
    'always finish with serlink_close_session.\n'
    'Rules you must follow:\n'
    '- NEVER connect to any host yourself: no ssh/scp/sftp, no shell '
    'commands, no sockets, no port scanning. You have no credentials and '
    'must not obtain any.\n'
    '- NEVER ask for, read, or handle passwords, private keys, '
    'passphrases, SSH agent material, keychains, or the Serlink vault. '
    'Authentication happens inside the Serlink app only.\n'
    '- vault_locked means the user must unlock the vault in the Serlink '
    'app — ask them and wait; do not retry or look for another way in.\n'
    '- authorization_denied / authorization_required means the user has '
    'not granted you access to that host in Serlink — ask them to grant '
    'it; do not retry or work around it.\n'
    '- command_blocked / command_denied means the risk policy rejected '
    'the command — do not rephrase, split, encode, or otherwise disguise '
    'it to get it through.\n'
    '- The user watches every session in a visible Serlink tab and can '
    'take back control at any time; act accordingly.';

final serlinkMcpTools = <String, SerlinkMcpTool>{
  'serlink_list_hosts': SerlinkMcpTool(
    name: 'serlink_list_hosts',
    description:
        'List the SSH hosts configured in Serlink. Workflow: call this '
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
        'Open an SSH session to a Serlink host as a visible terminal tab '
        'in the Serlink app. The user must approve access in a Serlink '
        'dialog (and unlock the vault first if it is locked), so this call '
        'may block until the user responds. Credentials never leave the '
        'app — never ask for passwords or private keys, and never try to '
        'read them from the user\'s files, keychain, or SSH agent. You '
        'drive the resulting terminal with serlink_exec, '
        'serlink_read_screen, and serlink_send_input. The user can take '
        'back control at any time by typing in the tab.',
    inputSchema: JsonSchema.object(
      properties: {
        'hostId': JsonSchema.string(
          description: 'Host id from serlink_list_hosts.',
        ),
      },
      required: ['hostId'],
    ),
  ),
  'serlink_exec': SerlinkMcpTool(
    name: 'serlink_exec',
    description:
        'Run a shell command in an open Serlink session and return the '
        'terminal screen after the output settles. Risky commands require '
        'user confirmation in the Serlink app; destructive commands are '
        'blocked outright. The result is the last screen lines (including '
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
        'the same risk policy as serlink_exec.',
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
        'Close a Serlink session opened with serlink_open_session. This '
        'closes the terminal tab in the Serlink app. Always close sessions '
        'when you are done with them.',
    inputSchema: JsonSchema.object(
      properties: {
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
        'List the Serlink sessions currently open for MCP clients, with '
        'their state. Use serlink_close_session for any session you no '
        'longer need.',
    inputSchema: JsonSchema.object(),
  ),
};
