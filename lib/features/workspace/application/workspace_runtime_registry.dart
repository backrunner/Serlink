import 'dart:async';

import 'package:xterm/xterm.dart';

import '../../../core/ids/entity_id.dart';
import '../../sftp/application/sftp_connection.dart';
import '../../ssh/application/ssh_session_service.dart';
import '../../terminal/application/terminal_adapter.dart';
import '../../terminal/application/terminal_paste_guard.dart';

class WorkspaceRuntimeRegistry {
  WorkspaceRuntimeRegistry({this.confirmMultilinePaste});

  final MultilinePasteConfirmation? confirmMultilinePaste;
  final Map<SessionId, Terminal> _terminals = {};
  final Map<SessionId, TerminalAdapter> _terminalAdapters = {};
  final Map<SessionId, SftpConnection> _sftpConnections = {};

  Terminal createTerminal({
    required SessionId sessionId,
    required String title,
    String preparingMessage = 'Connection runtime is preparing this tab.',
    bool echoInput = false,
    int maxLines = 10000,
  }) {
    final terminal = Terminal(maxLines: maxLines);
    terminal.write('Serlink $title\r\n');
    terminal.write('$preparingMessage\r\n\r\n');
    if (echoInput) {
      terminal.write(r'$ ');
      terminal.onOutput = (data) {
        terminal.write(data.replaceAll('\n', '\r\n'));
      };
    }
    _terminals[sessionId] = terminal;
    return terminal;
  }

  Terminal? terminalFor(SessionId sessionId) {
    return _terminals[sessionId];
  }

  void writeTerminal(SessionId sessionId, String text) {
    _terminals[sessionId]?.write(text);
  }

  bool sendTerminalInput(SessionId sessionId, String text) {
    final adapter = _terminalAdapters[sessionId];
    if (adapter == null) {
      return false;
    }
    adapter.sendInput(text);
    return true;
  }

  void attachTerminal({
    required SessionId sessionId,
    required SshShellSession session,
  }) {
    final terminal = _terminals[sessionId];
    if (terminal == null) {
      throw StateError('No terminal exists for session ${sessionId.value}.');
    }
    final adapter = TerminalAdapter(
      terminal: terminal,
      session: session,
      confirmMultilinePaste: confirmMultilinePaste,
    );
    adapter.attach();
    _terminalAdapters[sessionId] = adapter;
  }

  void attachSftp({
    required SessionId sessionId,
    required SftpConnection connection,
  }) {
    _sftpConnections[sessionId] = connection;
  }

  SftpConnection? sftpFor(SessionId sessionId) {
    return _sftpConnections[sessionId];
  }

  Future<void> closeSession(SessionId sessionId) async {
    await _terminalAdapters.remove(sessionId)?.close();
    await _sftpConnections.remove(sessionId)?.close();
  }

  Future<void> dispose() async {
    final sessionIds = {..._terminalAdapters.keys, ..._sftpConnections.keys};
    for (final sessionId in sessionIds) {
      await closeSession(sessionId);
    }
    _terminals.clear();
  }
}
